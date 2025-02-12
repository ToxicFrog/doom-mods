// Library for IPC to and from the Archipelago client program.
//
// See doc/protocol.md for details on how this thing works.

#namespace GZAP;

class ::IPC {
  // Send a message. "Type" is a message type (without the AP- prefix). "Payload"
  // is the JSON payload.
  static void Send(string type, string payload = "{}") {
    console.printfEX(PRINT_LOG, "AP-%s %s", type, payload);
  }
}
