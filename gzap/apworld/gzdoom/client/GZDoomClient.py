import asyncio
import copy
import os
import os.path
from typing import Any, Dict

import Utils
from CommonClient import CommonContext, ClientCommandProcessor, get_base_parser
from .IPC import IPC

class GZDoomCommandProcessor(ClientCommandProcessor):
    pass


class GZDoomContext(CommonContext):
    command_processor = GZDoomCommandProcessor
    game = "gzDoom"
    items_handling = 0b111  # fully remote
    want_slot_data = False

    def __init__(self, server_address: str, password: str, ipc_dir: str):
        super().__init__(server_address, password)
        self.ipc = IPC(self, ipc_dir)
        self.log_path = os.path.join(ipc_dir, "gzdoom.log")

    async def start_tasks(self) -> None:
        self.ipc.start_log_reader(self.log_path)
        self.items_task = asyncio.create_task(self._item_loop())

    async def send_check(self, id: int):
        await self.send_msgs([
            {"cmd": 'LocationChecks', "locations": [id]}
            ])

    async def send_chat(self, message: str):
        await self.send_msgs([
            {"cmd": "Say", "text": message}
            ])

    async def server_auth(self, *args):
        """Called automatically when the server connection is established."""
        await super().server_auth(*args)
        await self.get_username()
        await self.send_connect()

    async def on_xon(self, slot: str, seed: str):
        self.username = slot
        self.seed_name = seed
        self.last_items = {}  # force a re-send of all items
        # TODO: devs on the discord suggest starting the server loop manually
        # rather than calling connect(), which will allow the user to specify
        # a server address...later?
        await self.connect()

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
            print("Item loop running:", new_items)
            for id,count in new_items.items():
                if count != self.last_items.get(id, 0):
                    self.ipc.send_item(id, count)
            self.last_items = new_items


def main(*args):
    Utils.init_logging("GZDoomClient")

    # Initialize the gzDoom IPC structures on disk
    # TODO: do we want to support multiple running instances as the same user?
    ipc_dir = os.path.join(Utils.home_path(), ".gzdoom-ipc")
    os.makedirs(ipc_dir, exist_ok=True)

    # Preallocate input lump
    ipc_log = os.path.join(ipc_dir, 'gzdoom.log')
    ipc_lump = os.path.join(ipc_dir, 'GZAPIPC')
    with open(ipc_lump, 'w') as fd:
        fd.write('.' * 1024)

    # TODO: automatically create a different tuning file for each wad, and don't truncate
    # os.truncate(os.path.join(ipc_dir, "tuning.logic"), 0)

    async def actual_main(args):
        ctx = GZDoomContext(args.connect, args.password, ipc_dir)
        await ctx.start_tasks()
        print("┏" + "━"*78 + "╾")
        print("┃ Client started. Please start gzDoom with the additional arguments:")
        # TODO: can we give the actual zip name here?
        print(f"┃     -file AP_whatever.zip -file '{ipc_dir}' +'logfile \"{ipc_log}\"'")
        print("┃ after any other arguments (e.g. for wad/pk3 loading).")
        print("┗" + "━"*78 + "╾")
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
