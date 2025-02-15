"""
Archipelago-side library for communicating with gzDoom.

This is the mirror of IPC.zs in the pk3; it receives messages by reading JSON
from the gzDoom log file, and sends messages by writing to the gzDoom IPC lump
file. See doc/protocol.md for the full details.
"""

import asyncio
import json
import os.path
import time
from threading import Thread
from typing import Any, Dict, List


from CommonClient import CommonContext


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

  def _log_reading_thread(self, logfile: str, loop) -> None:
    print("Starting gzDoom event loop.")
    with open(logfile, "r") as fd:
       while True:
          line = self._blocking_readline(fd).strip()
          if line is None:
             return

          print("readline:", line)
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

  # TODO: we should detect if gzdoom has exited, and if so, recover gracefully:
  # - truncate the log file to 0 and restart the log reading thread
  # - reinitialize the IPC lump and return to our pre-XON state
  # possibly we need some sort of heartbeat for this, and if we go too long without
  # any messages from gzdoom emit a synthetic XOFF that has this effect.
  def _blocking_readline(self, fd) -> str:
    line = ""
    while True:
      buf = fd.readline()
      if not buf:
        if self.should_exit:
          return None
        time.sleep(0.1)
        continue
      line = line + buf
      if line.endswith("\n"):
        return line

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
    else:
        pass
    self.ctx.watcher_event.set()


  #### Handlers for events coming from gzdoom. ####

  async def recv_xon(self, lump: str, size: int, nick: str) -> None:
    """
    Called when an AP-XON message is received from gzdoom.

    This indicates that gzdoom is ready to receive messages, so this starts the
    message sending task. Until that point all messages are queued.
    """
    print("XON received, starting to send messages to gzDoom.")
    self.ipc_path = os.path.join(self.ipc_dir, lump)
    self.ipc_size = size
    self.nick = nick
    self._flush()

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


  #### Handlers for events coming from Archipelago. ####

  def send_item(self, id: int) -> None:
    """Send the item with the given ID to the player."""
    self._enqueue("ITEM", id)
    self._flush()

  def send_chat(self, nick: str, message: str) -> None:
    """Display the given chat message to the player."""
    self._enqueue("CHAT", nick, message)
    self._flush()


  #### Low-level outgoing IPC. ####

  def _get_id(self) -> int:
    self.ipc_id += 1
    return self.ipc_id

  def _ack(self, id: int) -> None:
    while self.ipc_queue and self.ipc_queue[0].id <= id:
      self.ipc_queue.pop(0)

  def _enqueue(self, *args) -> None:
    msg = IPCMessage(self._get_id(), *args)
    print("enqueue", msg)
    self.ipc_queue.append(msg)

  def _flush(self) -> None:
    print("flushing messages:", len(self.ipc_queue))
    if not self.ipc_queue:
      # No pending messages? Truncate the IPC buffer file so gzdoom doesn't
      # waste cycles reading and parsing it.
      # TODO: maybe reset it to original size so if gzdoom restarts IPC isn't
      # suddenly broken?
      with open(self.ipc_path, "w") as fd:
        fd.write("")
      return

    # Pack as many messages as we can.
    size_left = self.ipc_size
    buf = []
    for msg in self.ipc_queue:
      if len(msg) > size_left:
        break
      buf.append(msg.data)
      size_left -= len(msg)
    buf = "".join(buf)

    # Is this actually different from the last thing we wrote?
    if buf == self.ipc_buf:
      return
    with open(self.ipc_path, "w") as fd:
      print("sending:", buf)
      fd.write(buf)
    self.ipc_buf = buf
