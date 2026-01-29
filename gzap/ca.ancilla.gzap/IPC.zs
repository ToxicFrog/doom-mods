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
    DEBUG("Initializing IPC: slot=%s, wad=%s, lump=%s", slot_name, wadname, lumpname);
    last_seen = "";
    lumpid = wads.FindLump(lumpname);
    let buf = wads.ReadLump(lumpid);
    let server = GetArchipelagoServer();
    Send("XON", string.format(
      "{ \"lump\": \"%s\", \"size\": %d, \"nick\": \"%s\", \"slot\": \"%s\", \"seed\": \"%s\", \"wad\": \"%s\", \"server\": \"%s\" }",
      lumpname, buf.Length(),
      cvar.FindCVar("name").GetString(),
      slot_name, seed, wadname, server));
  }

  static void ReportVisited(Array<string> visited) {
    return;
    if (visited.Size() == 0) {
      Send("VISITED", "{ \"visited\": [] }");
    } else {
      Send("VISITED", string.format(
        "{ \"visited\": [ \"%s\" ] }", ::Util.Join("\", \"", visited)));
    }
  }

  static void DefineRegion(string map, string name, Array<string> prereqs) {
    string prereq_str = "";
    if (prereqs.Size() > 0) {
      prereq_str = "\"" .. ::Util.join("\", \"", prereqs) .. "\"";
    }

    Send("REGION", string.format(
      "{ \"map\": \"%s\", \"region\": \"%s\", \"keys\": [%s] }",
      map, name, prereq_str));
  }

  static void ReportWeapons(Map<string, int> weapons) {
    return;
    Array<string> buf;
    MapIterator<string, int> iter;
    iter.Init(weapons);
    foreach (weapon, count : iter) {
      buf.Push(string.format("\"%s\": %d", weapon, count));
    }
    Send("WEAPONS", string.format(
      "{ \"weapons\": { %s } }", ::Util.Join(", ", buf)));
  }

  static void CheckWithoutTuning(int id, string name, string pos_field, bool unreachable) {
    Send("CHECK",
      string.format("{ \"id\": %d, \"name\": \"%s\"%s%s }",
        id, name, pos_field, unreachable ? ", \"unreachable\": true" : ""));
  }

  static void CheckWithKeyTuning(int id, string name, string pos_field, string keys) {
    Send("CHECK",
      string.format("{ \"id\": %d, \"name\": \"%s\"%s, \"keys\": [%s] }",
        id, name, pos_field, keys));
  }

  static void CheckWithRegionTuning(int id, string name, string pos_field, string region) {
    Send("CHECK",
      string.format("{ \"id\": %d, \"name\": \"%s\"%s, \"region\": \"%s\" }",
        id, name, pos_field, region));
  }

  void Shutdown() {
    Send("XOFF", "{}");
  }

  bool IsConnected() {
    return last_seen != "";
  }

  // If the pk3 was downloaded from the web host, it'll contain an archipelago.json
  // file that looks something like this:
  // {"game": "gzDoom", "player": 2, "patch_file_ending": ".pk3", "server": "archipelago.gg:65206"}
  // We want to extract the "server" field from it.
  string GetArchipelagoServer() {
    int lump = wads.FindLump("ARCHIPEL");
    if (lump < 0) {
      return "";
    }

    // This is a hot mess because I don't want to add an entire JSON parser.
    string server = "";
    Array<string> fields;
    wads.ReadLump(lump).Split(fields, ",");
    foreach (field : fields) {
      if (field.IndexOf("\"server\":") != -1) {
        int start = field.IndexOf("\"", field.IndexOf(":"));
        int end = field.IndexOf("\"", start+1);
        server = field.Mid(start+1, (end-start-1));
        break;
      }
    }
    return server;
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
      DEBUG("RECV: %s", message);
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

  // Receive a single parsed message. type is the message type. fields is the
  // complete field array; fields[0] is always the sequence id and fields[1] is
  // the message type, everything after that is arguments.
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
        // fields are map name, location ID, destination player name, item name
        NET_STRING, fields[2], NET_INT, fields[3].ToInt(10), NET_STRING, fields[4], NET_STRING, fields[5]);
      return true;
    } else if (type == "TRACK") {
      if (fields.Size() != 4) return false;
      EventHandler.SendNetworkCommand("ap-ipc:track", NET_INT, fields[2].ToInt(10), NET_STRING, fields[3]);
      return true;
    } else if (type == "DEATH") {
      if (fields.Size() != 4) return false;
      EventHandler.SendNetworkCommand("ap-ipc:death", NET_STRING, fields[2], NET_STRING, fields[3]);
      return true;
    }
    return false;
  }
}
