import asyncio
import copy
import os
import os.path
from typing import Any, Dict

import Utils
from CommonClient import CommonContext, ClientCommandProcessor, ClientStatus, get_base_parser, gui_enabled, server_loop, logger
from .IPC import IPC

class GZDoomCommandProcessor(ClientCommandProcessor):
    pass


class GZDoomContext(CommonContext):
    command_processor = GZDoomCommandProcessor
    game = "gzDoom"
    items_handling = 0b111  # fully remote
    want_slot_data = False
    slot_name = None

    def __init__(self, server_address: str, password: str, ipc_dir: str):
        self.found_gzdoom = asyncio.Event()
        super().__init__(server_address, password)
        self.ipc = IPC(self, ipc_dir)

    def make_gui(self):
        from kvui import GameManager
        class TextManager(GameManager):
            base_title = "gzDoom Client"

        return TextManager

    async def start_tasks(self) -> None:
        print("Starting log reader")
        self.ipc.start_log_reader()
        print("Starting item/location sync")
        self.items_task = asyncio.create_task(self._item_loop())
        self.locations_task = asyncio.create_task(self._location_loop())
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
            print("Getting slot name from gzdoom:", self.auth, self.username)
            await self.found_gzdoom.wait()
            self.username = self.slot_name
            self.auth = self.username

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
        self.found_gzdoom.set()
        self.ipc.send_text("Archipelago<->GZDoom connection established.")
        # TODO: devs on the discord suggest starting the server loop manually
        # rather than calling connect(), which will allow the user to specify
        # a server address...later?
        # await self.connect()

    async def on_victory(self):
        self.finished_game = True
        await self.send_msgs([
            {"cmd": "StatusUpdate", "status": ClientStatus.CLIENT_GOAL }
            ])

    # def on_package(self, cmd, args):
    #     print("RECV", cmd, args)

    # async def send_msgs(self, msgs):
    #     for msg in msgs:
    #         print("SEND", msg)
    #     await super().send_msgs(msgs)

    def _is_relevant(self, type, item = None, receiving = None, **kwargs) -> bool:
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
            self.last_locations = self.checked_locations


def main(*args):
    Utils.init_logging("GZDoomClient")

    # Initialize the gzDoom IPC structures on disk
    # TODO: do we want to support multiple running instances as the same user?
    ipc_dir = os.path.join(Utils.home_path(), "gzdoom-ipc")
    os.makedirs(ipc_dir, exist_ok=True)

    # Preallocate input lump
    ipc_lump = os.path.join(ipc_dir, 'GZAPIPC')
    with open(ipc_lump, 'w') as fd:
        fd.write('.' * 1024)

    # Create empty logfile if it doesn't exist
    ipc_log = os.path.join(ipc_dir, 'gzdoom.log')
    with open(ipc_log, "a"):
        pass

    async def actual_main(args):
        ctx = GZDoomContext(args.connect, args.password, ipc_dir)
        await ctx.start_tasks()
        if gui_enabled:
            ctx.run_gui()
        ctx.run_cli()

        await asyncio.sleep(1)

        logger.info("*" * 80)
        logger.info("Client started. Please start gzDoom with the additional flags:")
        # TODO: can we give the actual zip name here?
        # Not until we know the seed, looks like, which we don't get until we
        # connect to gzdoom...
        logger.info(f"    -file '{ipc_dir}' +'logfile \"{ipc_log}\"'")
        logger.info("*after* any other arguments (e.g. for wad/pk3 loading).")
        logger.info("*" * 80)

        await ctx.exit_event.wait()
        print("Shutting down...")
        ctx.ipc.should_exit = True
        await ctx.shutdown()

    import colorama

    parser = get_base_parser()

    colorama.init()
    args = parser.parse_args(args)
    asyncio.run(actual_main(args), debug=True)
    print("asyncio.run done")
    colorama.deinit()


if __name__ == '__main__':
    main()
