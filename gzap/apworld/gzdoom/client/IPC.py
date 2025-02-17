"""
Archipelago-side library for communicating with gzDoom.

This is the mirror of IPC.zs in the pk3; it receives messages by reading JSON
from the gzDoom log file, and sends messages by writing to the gzDoom IPC lump
file. See doc/protocol.md for the full details.
"""

import asyncio
import time
import json
import os.path
import sys
import time
from threading import Thread
from typing import Any, Dict, List

from CommonClient import CommonContext
from .util import ansi_to_gzdoom

class IPCMessage:
  id: int = -1
  data: str

  def __init__(self, id, *args):
    self.id = id
    self.data = "\x1F".join([str(id)] + [str(arg) for arg in args]) + "\x17"

  def __len__(self):
    return len(self.data)


class IPC:
  # Client context manager
  ctx: CommonContext = None
  # Internal details of outgoing IPC
  ipc_id: int = 0
  ipc_size: int = 0
  ipc_path: str = ""
  ipc_queue: List[IPCMessage] = None
  ipc_buf: str = ""
  ipc_dir: str = ""
  should_exit: bool = False
  nick: str = ""  # user's name in gzDoom, used for chat message parsing

  def __init__(self, ctx: CommonContext, ipc_dir: str) -> None:
    self.ctx = ctx
    self.ipc_dir = ipc_dir
    self.ipc_queue = []

  def start_log_reader(self, log_path: str) -> None:
    loop = asyncio.get_running_loop()
    # We never await this, since we don't care about its return value, but we do need
    # to hang on to the thread handle for it to actually run.
    self.thread = asyncio.create_task(asyncio.to_thread(self._log_reading_thread, log_path, loop))
    print("Log reader started. Waiting for XON from gzDoom.")

  # TODO: if there's an existing log file, we (re)process all events from it
  # on startup. This can be annoying if some of them are chat messages or the
  # like. We may in fact need a little dance on connect where we generate a
  # message ID, and until we see our first ACK >= that ID, the only message
  # we process is XON.
  def _log_reading_thread(self, logfile: str, loop) -> None:
    print("Starting gzDoom event loop.")
    try:
      self._log_reading_loop(logfile, loop)
    except Exception as e:
      # HACK HACK HACK
      # Without this it just stays running in the background forever and I don't
      # even get to see the error until I kill it. :(
      # TODO: fix this
      print(e)
      sys.exit(1)

  def _log_reading_loop(self, logfile: str, loop):
    with open(logfile, "r") as fd:
       while True:
          line = self._blocking_readline(fd).strip()
          if line is None:
             # should_exit set, wind down the thread
             return

          # print("[gzdoom]", line)
          # if the line has the format "<username>: <line of text>", this is a chat message
          # this needs special handling because there is no OnSayEvent or similar in gzdoom
          if line.startswith(self.nick + ": "):
            evt = "AP-CHAT"
            payload = { "msg": line.removeprefix(self.nick + ": ").strip() }
          elif line.startswith("AP-"):
            [evt, payload] = line.split(" ", 1)
            payload = json.loads(payload)
          else:
            continue

          future = asyncio.run_coroutine_threadsafe(self._dispatch(evt, payload), loop)
          future.result()

  def _blocking_readline(self, fd) -> str:
    line = ""
    while True:
      buf = fd.readline()

      if self.should_exit:
        return None

      if buf:
        line = line + buf
        if line.endswith("\n"):
          return line
        else:
          continue

      # Log got truncated because gzdoom restarted.
      if fd.tell() > os.stat(fd.fileno()).st_size:
        fd.seek(0)
      time.sleep(0.1)

  async def _dispatch(self, evt: str, payload: Dict[Any, Any]):
    print(">>", evt, payload)
    if evt == "AP-XON":
        await self.recv_xon(**payload)
    elif evt == "AP-ACK":
        await self.recv_ack(**payload)
    elif evt == "AP-CHECK":
        # TODO: write to tuning file
        await self.recv_check(payload["id"])
    elif evt == "AP-CHAT":
        await self.recv_chat(payload["msg"])
    elif evt == "AP-STATUS":
        await self.recv_status(**payload)
    else:
        pass
    self.ctx.watcher_event.set()


  #### Handlers for events coming from gzdoom. ####

  async def recv_xon(self, lump: str, size: int, nick: str, slot: str, seed: str) -> None:
    """
    Called when an AP-XON message is received from gzdoom.

    This indicates that gzdoom is ready to receive messages, so this starts the
    message sending task. Until that point all messages are queued.
    """
    print("XON received. Opening channels to gzdoom and to AP host.")
    self.ipc_path = os.path.join(self.ipc_dir, lump)
    self.ipc_size = size
    self.nick = nick
    self._flush()
    await self.ctx.on_xon(slot, seed)

  async def recv_ack(self, id: int) -> None:
    """
    Called when an AP-ACK message is received from gzdoom.

    Clears acknowledged messages from the outgoing queue, and sends pending messages
    if there were any waiting for free space.
    """
    self._ack(id)
    self._flush()

  async def recv_check(self, id: int) -> None:
    """
    Called when an AP-CHECK message is received from gzdoom.

    Informs the context manager that we have checked the listed location. It's up
    to it to tell the server.

    We should also save it somewhere so it can be used for tuning later!
    """
    await self.ctx.send_check(id)

  async def recv_chat(self, message: str) -> None:
    """
    Called when an AP-CHAT message is received from gzdoom.

    Forwards it to the context manager to deliver to the server.
    """
    await self.ctx.send_chat(message)

  async def recv_status(self, victory: bool) -> None:
    if victory:
      await self.ctx.on_victory()


  #### Handlers for events coming from Archipelago. ####

  def send_item(self, id: int, count: int) -> None:
    """Send the item with the given ID to the player."""
    self._enqueue("ITEM", id, count)
    self._flush()

  def send_text(self, message: str) -> None:
    """Display the given message to the player."""
    # Prefix here avoids an infinite loop when the client uses the same name in
    # AP and in their gzdoom config. AP uses the same chat message format as gzd,
    # so what happens is, the chat message goes to gzd, gets displayed, appears
    # in the log, the client sees it as a new chat message, sends it to the server,
    # which echoes it, etc.
    self._enqueue("TEXT", "[AP]"+ansi_to_gzdoom(message))
    self._flush()


  #### Low-level outgoing IPC. ####

  def _get_id(self) -> int:
    # Use monotonic clock to get a value that increases even across client
    # executions, so client restarts don't reset the sequence counter and confuse
    # the game. We drop the bottom two bytes to make it more manageable, which
    # reduces the resolution to about 15k messages/second, which is still way
    # more than we need (or gzdoom is willing to ingest, since it only processes
    # the buffer once per second).
    # TODO: we can maybe get away with lowering the resolution further, and/or
    # sleeping briefly after an enqueue. But should we?
    return "%012X" % (time.monotonic_ns() // 256 // 256,)

  def _ack(self, id: int) -> None:
    while self.ipc_queue and self.ipc_queue[0].id <= id:
      self.ipc_queue.pop(0)

  def _enqueue(self, *args) -> None:
    id = self._get_id()
    # print("Enqueue:", id, *args)
    msg = IPCMessage(id, *args)
    self.ipc_queue.append(msg)

  def _flush(self) -> None:
    if self.ipc_size == 0:
      # Not connected to gzDoom. Hold messages in the buffer until it (re)connects.
      return

    if not self.ipc_queue:
      # No pending messages? Zero-fill the buffer.
      # We do this, instead of truncating, so that if gzdoom restarts it doesn't
      # get a zero-length IPC buffer.
      with open(self.ipc_path, "w") as fd:
        fd.truncate(self.ipc_size)
      return

    # Pack as many messages as we can.
    last_id = 0
    first_id = 0
    size_left = self.ipc_size
    buf = []
    for msg in self.ipc_queue:
      if len(msg) > size_left:
        break
      buf.append(msg.data)
      size_left -= len(msg)
      if not first_id:
        first_id = msg.id
      last_id = msg.id
    buf = "".join(buf)

    # Is this actually different from the last thing we wrote?
    if buf == self.ipc_buf:
      return
    # print(f"Sending {len(buf)} bytes with ids {first_id}..{last_id}")
    with open(self.ipc_path, "w") as fd:
      fd.write(buf)
      # Use the full size, same rational as above.
      fd.truncate(self.ipc_size)
    self.ipc_buf = buf
