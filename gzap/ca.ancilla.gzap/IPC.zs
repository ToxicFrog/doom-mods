// Library for IPC to and from the Archipelago client program.
//
// See doc/protocol.md for details on how this contraption works.

#namespace GZAP;
#debug off;

class ::IPC {
  // Send a message. "Type" is a message type (without the AP- prefix). "Payload"
  // is the JSON payload.
  static void Send(string type, string payload = "{}") {
    console.printfEX(PRINT_LOG, "AP-%s %s", type, payload);
  }

  int last_seen;
  int lumpid;

  // Initialize the IPC receiver using the given lump name.
  void Init(string slot_name, string seed, string lumpname = "GZAPIPC") {
    last_seen = 0;
    lumpid = wads.FindLump(lumpname);
    let buf = wads.ReadLump(lumpid);
    Send("XON", string.format(
      "{ \"lump\": \"%s\", \"size\": %d, \"nick\": \"%s\", \"slot\": \"%s\", \"seed\": \"%s\" }",
      lumpname, buf.Length(),
      cvar.FindCVar("name").GetString(),
      slot_name, seed));
  }

  // Receive all pending messages, dispatch them internally, and ack them.
  void ReceiveAll() {
    // Not initialized yet. That's fine, it means the menu loop has started up
    // but the game loop hasn't yet.
    if (!lumpid) return;

    let buf = wads.ReadLump(lumpid);
    // console.printf("Read %d bytes from IPC buffer.", buf.Length());

    Array<string> messages;
    buf.split(messages, "\x17");
    // Last entry is either an incomplete message or an empty string.
    messages.Pop();

    bool send_ack = false;
    Array<string> fields;
    foreach (message : messages) {
      fields.Clear();
      message.split(fields, "\x1F");
      if (fields.Size() < 2) {
        console.printf("Error processing message: %s (not enough fields for header)", message);
        continue;
      }

      let id = fields[0].ToInt(10);
      let msgtype = fields[1];
      if (id <= last_seen) {
        DEBUG("Skipping %s message (%d <= %d)", msgtype, id, last_seen);
        continue;
      }

      if (!ReceiveOne(msgtype, fields)) {
        console.printf("Error processing message: %s (ReceiveOne() failed)", message);
        continue;
      }

      DEBUG("Successfully processed message %d (%s)", id, msgtype);
      last_seen = id;
      send_ack = true;
    }
    if (send_ack) Send("ACK", string.format("{ \"id\": %d }", last_seen));
  }

  bool ReceiveOne(string type, Array<string> fields) {
    if (type == "TEXT") {
      if (fields.Size() != 3) return false;
      EventHandler.SendNetworkCommand("ap-ipc:text",
        NET_STRING, fields[2]);
      return true;
    } else if (type == "ITEM") {
      if (fields.Size() != 4) return false;
      EventHandler.SendNetworkCommand("ap-ipc:item",
        NET_INT, fields[2].ToInt(10), NET_INT, fields[3].ToInt(10));
      return true;
    }
    return false;
  }
}
