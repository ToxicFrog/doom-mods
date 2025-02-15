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

  def __init__(self, ctx: CommonContext, ipc_dir: str) -> None:
    self.ctx = ctx
    self.ipc_dir = ipc_dir
    self.ipc_queue = []

  def start_log_reader(self, log_path: str) -> None:
    loop = asyncio.get_running_loop()
    # fire and forget
    self.thread = asyncio.create_task(asyncio.to_thread(self._log_reading_thread, log_path, loop))
    # await loop.run_in_executor(None, self._log_reading_thread, log_path, loop)
    print("Log reader startup complete.")

  def _log_reading_thread(self, logfile: str, loop) -> None:
    print("Starting gzDoom event loop.")
    with open(logfile, "r") as fd:
       while True:
          line = fd.readline()
          if not line:
             if self.should_exit:
               return
             time.sleep(0.1)
             continue

          if not line.startswith("AP-"):
            continue

          [evt, payload] = line.split(" ", 1)
          payload = json.loads(payload)
          print("<<", evt, payload)
          future = asyncio.run_coroutine_threadsafe(self._dispatch(evt, payload), loop)
          future.result()

  async def _dispatch(self, evt: str, payload: Dict[Any, Any]):
    print(">>", evt, payload)
    if evt == "AP-XON":
        await self.recv_xon(payload["lump"], payload["size"])
    elif evt == "AP-ACK":
        await self.recv_ack(payload["id"])
    elif evt == "AP-CHECK":
        await self.recv_check(payload["id"])
    elif evt == "AP-CHAT":
        await self.recv_chat(payload["msg"])
    else:
        pass
    self.ctx.watcher_event.set()


  #### Handlers for events coming from gzdoom. ####

  async def recv_ack(self, id: int) -> None:
    """
    Called when an AP-ACK message is received from gzdoom.

    Clears acknowledged messages from the outgoing queue, and sends pending messages
    if there were any waiting for free space.
    """
    self._ack(id)
    self._flush()

  async def recv_xon(self, path: str, size: int) -> None:
    """
    Called when an AP-XON message is received from gzdoom.

    This indicates that gzdoom is ready to receive messages, so this starts the
    message sending task. Until that point all messages are queued.
    """
    self.ipc_path = os.path.join(self.ipc_dir, path)
    self.ipc_size = size
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
