import asyncio
import copy
import locale
import os
import os.path
from typing import Any, Dict

import Utils
from CommonClient import ClientCommandProcessor, ClientStatus, get_base_parser, gui_enabled, server_loop, logger
from .IPC import IPC
from .Hint import GZDoomHint

tracker_loaded = False
try:
    from worlds.tracker.TrackerClient import TrackerGameContext as SuperContext
    print("Universal Tracker detected, enabling tracker support.")
    tracker_loaded = True
except ModuleNotFoundError:
    from CommonClient import CommonContext as SuperContext
    print("No Universal Tracker detected, running without tracker support.")

_IPC_SIZE = 4096

class GZDoomContext(SuperContext):
    game = "gzDoom"
    items_handling = 0b111  # fully remote
    want_slot_data = False
    slot_name = None
    tags = {"AP"}

    def __init__(self, server_address: str, password: str, gzd_dir: str):
        self.found_gzdoom = asyncio.Event()
        super().__init__(server_address, password)
        self.ipc = IPC(self, gzd_dir, _IPC_SIZE)

    def make_gui(self):
        ui = super().make_gui()
        ui.base_title = "GZDoom Client"
        return ui

    async def start_tasks(self) -> None:
        print("Starting log reader")
        self.ipc.start_log_reader()
        print("Starting item/location sync")
        self.items_task = asyncio.create_task(self._item_loop())
        self.locations_task = asyncio.create_task(self._location_loop())
        self.hints_task = asyncio.create_task(self._hint_loop())
        if tracker_loaded:
            self.tracker_task = asyncio.create_task(self._tracker_loop())
        else:
            self.tracker_task = None
        print("Starting server loop")
        self.server_task = asyncio.create_task(server_loop(self), name="ServerLoop")
        print("All tasks started.")

    async def send_check(self, id: int):
        await self.send_msgs([
            {"cmd": 'LocationChecks', "locations": [id]}
            ])

    async def send_chat(self, message: str):
        await self.send_msgs([
            {"cmd": "Say", "text": message}
            ])

    async def get_username(self):
        if not self.auth:
            print("Getting slot name from gzdoom...")
            await self.found_gzdoom.wait()
            self.username = self.slot_name
            self.auth = self.username
            print("Got slot info:", self.username)

    async def server_auth(self, *args):
        """Called automatically when the server connection is established."""
        await super().server_auth(*args)
        await self.get_username()
        await self.send_connect()

    async def on_xon(self, slot: str, seed: str):
        self.slot_name = slot
        self.seed_name = seed
        self.last_items = {}  # force a re-send of all items
        self.last_locations = set()
        self.last_tracked = set()
        self.last_hints = {}
        self.found_gzdoom.set()
        self.ipc.send_text("Archipelago<->GZDoom connection established.")

    async def on_xoff(self):
        self.username = None
        self.auth = None
        self.slot_name = None
        self.found_gzdoom.clear()
        logger.info("Connection to GZDoom closed.")

    async def on_victory(self):
        self.finished_game = True
        await self.send_msgs([
            {"cmd": "StatusUpdate", "status": ClientStatus.CLIENT_GOAL }
            ])

    def on_package(self, cmd, args):
        # print("on_package", cmd, args)
        if cmd == "Connected" and tracker_loaded:
            args.setdefault("slot_data", dict())
        super().on_package(cmd, args)
        self.awaken()

    # async def send_msgs(self, msgs):
    #     for msg in msgs:
    #         print("SEND", msg)
    #     await super().send_msgs(msgs)

    def awaken(self):
        # Annoyingly, uncaught exceptions in coroutines, by default, DO NOTHING,
        # the coroutine just silently dies and you never know why.
        # So whenever we awaken, we first check to see if any of the coros died,
        # and propagate the error if so.
        for task in [self.items_task, self.locations_task, self.hints_task, self.tracker_task]:
            if task is not None and task.done():
                print(f"Task {task} has exited!")
                task.result()  # raises if the task errored out
        self.watcher_event.set()

    def _is_relevant(self, type = None, item = None, receiving = None, **kwargs) -> bool:
      if type in {"Chat", "ServerChat", "Goal", "Countdown"}:
          return True
      if type in {"Hint", "ItemSend"}:
          return self.slot_concerns_self(receiving) or self.slot_concerns_self(item.player)
      return False

    def on_print_json(self, args: Dict[Any, Any]) -> None:
        super().on_print_json(args)
        if not self._is_relevant(**args):
            return
        text = self.jsontotextparser(copy.deepcopy(args["data"]))
        self.ipc.send_text(text)

    def pending_hints(self):
        return {
            hint["item"]: GZDoomHint(**hint)
            for hint in self.stored_data.get(f"_read_hints_{self.team}_{self.slot}", [])
            if not hint["found"] and GZDoomHint(**hint).is_relevant(self)
        }

    async def _item_loop(self):
        self.last_items = {}
        while not self.exit_event.is_set():
            await self.watcher_event.wait()
            self.watcher_event.clear()
            new_items = {}
            for item in self.items_received:
                new_items[item.item] = new_items.get(item.item, 0) + 1
            # print("Item loop running:", new_items)
            for id,count in new_items.items():
                if count != self.last_items.get(id, 0):
                    self.ipc.send_item(id, count)
            self.ipc.flush()
            self.last_items = new_items

    async def _location_loop(self):
        self.last_locations = set()
        while not self.exit_event.is_set():
            await self.watcher_event.wait()
            self.watcher_event.clear()
            new_locations = self.checked_locations - self.last_locations
            # print("Location loop running", new_locations, self.checked_locations)
            for id in new_locations:
                self.ipc.send_checked(id)
            self.ipc.flush()
            self.last_locations |= new_locations

    async def _tracker_loop(self):
        self.last_tracked = set()
        self.last_tracked_ool = set()
        while not self.exit_event.is_set():
            await self.watcher_event.wait()
            self.watcher_event.clear()
            if hasattr(self, 'glitches_locations'):
                new_ool = set(self.glitches_locations) - self.last_tracked_ool
            else:
                # Older version of UT
                new_ool = set()
            new_il = set(self.locations_available) - self.last_tracked

            print("tracker_loop IL: ", new_il, self.last_tracked)
            print("tracker_loop OOL:", new_ool, self.last_tracked_ool)
            for id in new_ool:
                self.ipc.send_track(id, "OOL")
            for id in new_il:
                self.ipc.send_track(id, "IL")
            self.ipc.flush()
            # Over the course of the game, locations may be added to OOL and then
            # removed from it and added to IL. These locations will gradually
            # accumulate in last_tracked_ool. However, this is fine, because on
            # startup the IL and OOL sets are guaranteed disjoint, and once we've
            # sent an OOL message for a location once we won't re-send it, and
            # it will later be overwritten by the IL message.
            self.last_tracked_ool |= new_ool
            self.last_tracked |= new_il

    async def _hint_loop(self):
        self.last_hints = {}
        while not self.exit_event.is_set():
            await self.watcher_event.wait()
            self.watcher_event.clear()
            hints = self.pending_hints()
            new_hint_ids = set(hints.keys()) - set(self.last_hints.keys())
            # print(f"in hint loop, old={self.last_hints.keys()}, cur={hints.keys()}, new={new_hint_ids}")
            for id in new_hint_ids:
                hint = hints[id]
                if hint.is_hint(self):
                    # print("sending hint:", hint.hint_info(self))
                    self.ipc.send_hint(*hint.hint_info(self))
                if hint.is_peek(self):
                    # print("sending peek:", hint.peek_info(self))
                    self.ipc.send_peek(*hint.peek_info(self))
            self.ipc.flush()
            self.last_hints = hints


def main(*args):
    Utils.init_logging("GZDoomClient")

    # Initialize the gzDoom IPC structures on disk
    # TODO: do we want to support multiple running instances as the same user?
    gzd_dir = os.path.join(Utils.home_path(), "gzdoom")
    ipc_dir = os.path.join(gzd_dir, "ipc")
    os.makedirs(ipc_dir, exist_ok=True) # communication with gzdoom
    os.makedirs(os.path.join(gzd_dir, "logic"), exist_ok=True) # in-dev logic files
    os.makedirs(os.path.join(gzd_dir, "tuning"), exist_ok=True) # in-dev tuning files

    # Preallocate input lump
    ipc_lump = os.path.join(ipc_dir, 'GZAPIPC')
    with open(ipc_lump, 'w') as fd:
        fd.write('.' * _IPC_SIZE)

    # Create empty logfile if it doesn't exist
    ipc_log = os.path.join(gzd_dir, 'gzdoom.log')
    with open(ipc_log, "a"):
        pass

    print(f"GZDoom IPC files created. Host encoding: {locale.getencoding()}. IPC encoding: UTF-8.")

    async def actual_main(args, ipc_dir, ipc_log):
        ctx = GZDoomContext(args.connect, args.password, gzd_dir)
        await ctx.start_tasks()
        if tracker_loaded:
            logger.info("Initializing tracker...")
            ctx.run_generator()
        if gui_enabled:
            ctx.run_gui()
        ctx.run_cli()

        await asyncio.sleep(1)

        logger.info("*" * 80)
        logger.info("Client started. Please start gzDoom with the additional flags:")
        # Use forward slashes unconditionally here; windows will accept either,
        # but preferentially generates backslashes, which then are treated as
        # escapes when invoking gzdoom.
        logger.info(f"    -file \"{ipc_dir}\" +logfile \"{ipc_log}\"")
        logger.info("*after* any other arguments (e.g. for wad/pk3 loading).")
        logger.info("*" * 80)

        await ctx.exit_event.wait()
        print("Shutting down...")
        ctx.ipc.should_exit = True
        ctx.awaken()
        await ctx.shutdown()

    import colorama

    parser = get_base_parser()

    colorama.init()
    args = parser.parse_args(args)
    asyncio.run(
        actual_main(args, ipc_dir.replace("\\", "/"), ipc_log.replace("\\", "/")),
        debug=True)
    colorama.deinit()


if __name__ == '__main__':
    main()
