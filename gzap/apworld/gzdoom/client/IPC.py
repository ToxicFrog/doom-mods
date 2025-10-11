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
from typing import Any, Dict, List, Optional

from CommonClient import CommonContext, logger
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
  gzd_dir: str = ""
  ipc_id: int = 0
  ipc_size: int = 0
  ipc_path: str = ""
  ipc_queue: List[IPCMessage] = None
  ipc_buf: str = ""
  ipc_dir: str = ""
  should_exit: bool = False
  nick: str = ""  # user's name in gzDoom, used for chat message parsing

  def __init__(self, ctx: CommonContext, gzd_dir: str, size: int) -> None:
    self.ctx = ctx
    self.gzd_dir = gzd_dir
    self.ipc_dir = os.path.join(gzd_dir, "ipc")
    self.ipc_size = size
    self.ipc_queue = []

  def start_log_reader(self) -> None:
    loop = asyncio.get_running_loop()
    # We never await this, since we don't care about its return value, but we do need
    # to hang on to the thread handle for it to actually run.
    self.thread = asyncio.create_task(asyncio.to_thread(self._log_reading_thread, self.gzd_dir, loop))
    logger.info("Log reader started. Waiting for XON from gzDoom.")

  # TODO: if there's an existing log file, we (re)process all events from it
  # on startup. This can be annoying if some of them are chat messages or the
  # like. We may in fact need a little dance on connect where we generate a
  # message ID, and until we see our first ACK >= that ID, the only message
  # we process is XON.
  def _log_reading_thread(self, ipc_dir: str, loop) -> None:
    print("Starting gzDoom event loop.")
    try:
      self._log_reading_loop(ipc_dir, loop)
    except Exception as e:
      # HACK HACK HACK
      # Without this it just stays running in the background forever and I don't
      # even get to see the error until I kill it. :(
      # TODO: fix this
      logger.error(e)
      sys.exit(1)

  def _tuning_file_path(self, ipc_dir: str, wadname: str) -> str:
    return os.path.join(
      ipc_dir, "tuning", f"{wadname}.{int(time.time())}.tuning"
    )

  def _log_reading_loop(self, ipc_dir: str, loop):
    log_path = os.path.join(ipc_dir, "gzdoom.log")
    tune = None
    with open(log_path, "r", encoding="utf-8") as log:
       self._wait_for_live_log(log)
       while True:
          line = self._blocking_readline(log).strip()
          if line is None:
             # should_exit set, wind down the thread
             return

          # print("[gzdoom]", line)
          # if the line has the format "<username>: <line of text>", this is a chat message
          # this needs special handling because there is no OnSayEvent or similar in gzdoom
          if self.nick and line.startswith(self.nick + ": "):
            evt = "AP-CHAT"
            payload = { "msg": line.removeprefix(self.nick + ": ").strip() }
          elif line.startswith("AP-"):
            [evt, payload] = line.split(" ", 1)
            try:
              payload = json.loads(payload)
            except json.JSONDecodeError as e:
              logger.error(f"Error decoding message from gzdoom: {line}")
              logger.error(f"Error reported is: {e}")
              continue
          else:
            continue

          if evt == "AP-XON":
            if tune:
              tune.close()
            tune = open(self._tuning_file_path(ipc_dir, payload["wad"]), "a", encoding="utf-8")

          if evt in {"AP-CHECK", "AP-KEY"} and tune:
            tune.write(line+"\n")
            tune.flush()

          future = asyncio.run_coroutine_threadsafe(self._dispatch(evt, payload), loop)
          future.result()

  def _wait_for_live_log(self, fd) -> None:
    """
    Wait for the log to be "live", i.e. being written by a running gzdoom process
    rather than something left over from an earlier run.

    We use a blunt hammer for this: read the logfile contents, and if they don't
    have an XOFF in them we're good to go, and if they do, wait for it to get
    truncated by a new gzdoom process.
    """
    if fd.read().find("\nAP-XOFF") >= 0:
      # Dead log, wait for it to be truncated
      logger.info("Logfile is from a previous run of gzdoom. Waiting for a new one.")
      while fd.tell() <= os.stat(fd.fileno()).st_size:
        time.sleep(1)
        if self.should_exit:
          return
    fd.seek(0)

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
        await self.recv_check(payload["id"])
    elif evt == "AP-CHAT":
        await self.recv_chat(payload["msg"])
    elif evt == "AP-STATUS":
        await self.recv_status(**payload)
    elif evt == "AP-DEATH":
        await self.recv_death(**payload)
    elif evt == "AP-XOFF":
        await self.recv_xoff()
    else:
        pass
    self.ctx.awaken()


  #### Handlers for events coming from gzdoom. ####

  async def recv_xon(self, lump: str, size: int, nick: str, slot: str, seed: str, wad: str, server: str) -> None:
    """
    Called when an AP-XON message is received from gzdoom.

    This indicates that gzdoom is ready to receive messages, so this starts the
    message sending task. Until that point all messages are queued.
    """
    print("XON received. Opening channels to gzdoom and to AP host.")
    self.ipc_path = os.path.join(self.ipc_dir, lump)
    assert size == self.ipc_size, "IPC size mismatch between gzdoom and AP -- please exit both, start the client, then gzdoom"
    self.nick = nick
    self.flush()
    await self.ctx.on_xon(slot, seed, server)

  async def recv_ack(self, id: int) -> None:
    """
    Called when an AP-ACK message is received from gzdoom.

    Clears acknowledged messages from the outgoing queue, and sends pending messages
    if there were any waiting for free space.
    """
    self._ack(id)
    self.flush()

  async def recv_check(self, id: int) -> None:
    """
    Called when an AP-CHECK message is received from gzdoom.

    Informs the context manager that we have checked the listed location. It's up
    to it to tell the server.
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

  async def recv_death(self, reason: str) -> None:
    await self.ctx.on_death(reason)

  async def recv_xoff(self) -> None:
    # Stop sending things to the client.
    self.nick = None
    await self.ctx.on_xoff()
    self.flush()


  #### Handlers for events coming from Archipelago. ####

  def send_item(self, id: int, count: int) -> None:
    """Send the item with the given ID to the player."""
    self._enqueue("ITEM", id, count)

  def send_checked(self, id: int) -> None:
    """Mark the given location as having been checked."""
    self._enqueue("CHECKED", id)

  def send_text(self, message: str) -> None:
    """Display the given message to the player."""
    # Prefix here avoids an infinite loop when the client uses the same name in
    # AP and in their gzdoom config. AP uses the same chat message format as gzd,
    # so what happens is, the chat message goes to gzd, gets displayed, appears
    # in the log, the client sees it as a new chat message, sends it to the server,
    # which echoes it, etc.
    self._enqueue("TEXT", "[AP]"+ansi_to_gzdoom(message))

  def send_track(self, id: int, track_type: str) -> None:
    """Tell the game that the tracker thinks this location is in logic now."""
    self._enqueue("TRACK", id, track_type)

  def send_hint(self, map: Optional[str], item: str, player: str, location: str) -> None:
    """Send a hint to the game. map is only set if it's a scoped item being hinted."""
    self._enqueue("HINT", map or "", item, ansi_to_gzdoom(player), ansi_to_gzdoom(location))

  def send_peek(self, map: str, location: str, player: str, item: str) -> None:
    """Send a peek to the game."""
    self._enqueue("PEEK", map, location, ansi_to_gzdoom(player), ansi_to_gzdoom(item))

  def send_death(self, source: str, reason: str) -> None:
    self._enqueue("DEATH", source, reason)

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
    id = time.monotonic_ns() // 256 // 256
    if id <= self.ipc_id:
      # Sending messages too fast to get more IDs; manually increment
      id = self.ipc_id + 1
    self.ipc_id = id
    return "%012X" % id

  def _ack(self, id: int) -> None:
    while self.ipc_queue and self.ipc_queue[0].id <= id:
      self.ipc_queue.pop(0)

  def _enqueue(self, *args) -> None:
    id = self._get_id()
    # print("Enqueue:", id, *args)
    msg = IPCMessage(id, *args)
    self.ipc_queue.append(msg)

  def flush(self) -> None:
    if not self.ipc_path:
      # Not connected to gzdoom yet
      return

    if not self.nick or not self.ipc_queue:
      # Either gzdoom has disconnected (after being previously connected) or we
      # have no messages for it.
      # In either case we clear the on-disk buffer so that gzdoom doesn't end
      # up receiving messages before XON next time it connects.
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
    with open(self.ipc_path, "w", encoding="utf-8") as fd:
      fd.write(buf)
      # Use the full size, same rationale as above.
      fd.truncate(self.ipc_size)
    self.ipc_buf = buf
    # print("Send complete.")
