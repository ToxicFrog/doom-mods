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

  string last_seen;
  int lumpid;

  // Initialize the IPC receiver using the given lump name.
  void Init(string slot_name, string seed, string wadname, string lumpname = "GZAPIPC") {
    last_seen = "";
    lumpid = wads.FindLump(lumpname);
    let buf = wads.ReadLump(lumpid);
    Send("XON", string.format(
      "{ \"lump\": \"%s\", \"size\": %d, \"nick\": \"%s\", \"slot\": \"%s\", \"seed\": \"%s\", \"wad\": \"%s\" }",
      lumpname, buf.Length(),
      cvar.FindCVar("name").GetString(),
      slot_name, seed, wadname));
  }

  void Shutdown() {
    Send("XOFF", "{}");
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

      let id = fields[0];
      let msgtype = fields[1];
      if (id <= last_seen) {
        DEBUG("Skipping %s message (%s <= %s)", msgtype, id, last_seen);
        continue;
      }

      if (!ReceiveOne(msgtype, fields)) {
        console.printf("Error processing message: %s (ReceiveOne() failed)", message);
        continue;
      }

      DEBUG("Successfully processed message %s (%s)", id, msgtype);
      last_seen = id;
      send_ack = true;
    }
    if (send_ack) Send("ACK", string.format("{ \"id\": \"%s\" }", last_seen));
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
    } else if (type == "CHECKED") {
      if (fields.Size() != 3) return false;
      EventHandler.SendNetworkCommand("ap-ipc:checked",
        NET_INT, fields[2].ToInt(10));
      return true;
    } else if (type == "HINT") {
      if (fields.Size() != 6) return false;
      EventHandler.SendNetworkCommand("ap-ipc:hint",
        // fields are map name, item name, finding player name, item location in their world
        NET_STRING, fields[2], NET_STRING, fields[3], NET_STRING, fields[4], NET_STRING, fields[5]);
      return true;
    } else if (type == "PEEK") {
      if (fields.Size() != 6) return false;
      EventHandler.SendNetworkCommand("ap-ipc:peek",
        // fields are map name, location name, destination player name, item name
        NET_STRING, fields[2], NET_STRING, fields[3], NET_STRING, fields[4], NET_STRING, fields[5]);
      return true;
    }
    return false;
  }
}
