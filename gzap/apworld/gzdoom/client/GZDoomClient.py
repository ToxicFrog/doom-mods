import asyncio
import copy
import os
import os.path

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

    async def server_auth(self, password):
        self.auth = "ToxicFrog"  # FIXME: hardcoded for testing
        # self.password = None
        await self.send_connect()

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

    def on_package(self, cmd, args):
        print("RECV", cmd, args)

    async def send_msgs(self, msgs):
        for msg in msgs:
            print("SEND", msg)
        await super().send_msgs(msgs)

    def on_print_json(self, args: dict):
        super().on_print_json(args)
        # TODO: this inserts terminal colour escapes which gzdoom does not cope
        # with well. Translate to gzdoom colour codes.
        text = self.jsontotextparser(copy.deepcopy(args["data"]))
        # TODO: filter for relevance.
        self.ipc.send_text(text)

    async def _item_loop(self):
        last_items = set()
        while not self.exit_event.is_set():
            await self.watcher_event.wait()
            self.watcher_event.clear()
            items = set(self.items_received)
            if items == last_items:
                continue

            for item in items - last_items:
                # TODO: also send the player so we know who sent it to us!
                self.ipc.send_item(item.item)
            last_items = items


def main(*args):
    Utils.init_logging("GZDoomClient")

    # Initialize the gzDoom IPC structures on disk
    # TODO: do we want to support multiple running instances as the same user?
    ipc_dir = os.path.join(Utils.home_path(), ".gzdoom-ipc")
    os.makedirs(ipc_dir, exist_ok=True)

    # Preallocate input lump
    ipc_lump = os.path.join(ipc_dir, 'GZAPIPC')
    with open(ipc_lump, 'w') as fd:
        fd.write('.' * 1024)

    # Truncate output log
    ipc_log = os.path.join(ipc_dir, 'gzdoom.log')
    with open(ipc_log, 'w'):
        pass

    # TODO: automatically create a different tuning file for each wad, and don't truncate
    # os.truncate(os.path.join(ipc_dir, "tuning.logic"), 0)

    async def actual_main(args):
        ctx = GZDoomContext(args.connect, args.password, ipc_dir)
        await ctx.start_tasks()
        await ctx.connect()
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
