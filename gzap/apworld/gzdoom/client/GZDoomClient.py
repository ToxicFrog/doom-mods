import asyncio
import copy
import time

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

    def __init__(self, server_address, password, log_path, ipc_path):
        print("Initializing gzdoom client")
        super().__init__(server_address, password)
        self.ipc = IPC(self, ipc_path)
        self.log_path = log_path
        self.ipc_path = ipc_path

    async def server_auth(self, password):
        self.auth = "ToxicFrog"  # FIXME: hardcoded for testing
        self.password = None
        await self.send_connect()

    async def start_tasks(self) -> None:
        self.ipc.start_log_reader(self.log_path)
        self.items_task = asyncio.create_task(self._item_loop())
        print("Waiting for XON from gzDoom.")

    async def send_check(self, id: int):
        print("sending check", id)
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
        text = self.jsontotextparser(copy.deepcopy(args["data"]))
        self.ipc.send_chat("Archipelago", text)

    async def _item_loop(self):
        print("Starting delivery loop.")
        last_items = set()
        while not self.exit_event.is_set():
            await self.watcher_event.wait()
            self.watcher_event.clear()
            items = set(self.items_received)
            print("running item loop", items, last_items)
            if items == last_items:
                continue

            for item in items - last_items:
                # TODO: also send the player so we know who sent it to us!
                self.ipc.send_item(item.item)
            last_items = items


def main(*args):
    Utils.init_logging("GZDoomClient")

    # options = Utils.get_options()

    async def actual_main(args):
        ctx = GZDoomContext(args.connect, args.password, args.gzd_log_pipe, args.gzd_ipc_dir)
        await ctx.start_tasks()
        print("done start tasks")
        await ctx.connect()
        print("done setup")
        await ctx.exit_event.wait()
        ctx.ipc.should_exit = True
        await ctx.shutdown()
        print("Exiting...")

    import colorama

    parser = get_base_parser()
    parser.add_argument('--gzd-log-pipe', default=None, help='Path to the fifo gzDoom is writing its logs to.')
    parser.add_argument('--gzd-ipc-dir', default=None, help='Path to the directory containing the GZAPIPC lump.')

    colorama.init()
    args = parser.parse_args(args)
    asyncio.run(actual_main(args), debug=True)
    print("asyncio.run done")
    colorama.deinit()


if __name__ == '__main__':
    main()
