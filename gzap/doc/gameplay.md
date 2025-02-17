TBW. Needs to cover:

- what files to download
- brief note on logic file generation + link to main docs
- generating your game (SW and MW)
- how to play in SW (load order)
- how to play in MW (client setup, etc)

Some of this needs more work in code, e.g. the client is currently a hot mess.

Singleplayer -- load other mods, then gzap, then AP_1234.zip. No other commands
needed unless you want to do tuning, in which case add `+'logfile tuning.log'` or
similar to the command line.

Multiplayer -- start client first; it gives you needed command line.
Run gzdoom with command line, client should automatically connect to game.
You can quit gzdoom and restart it and the client will automatically reconnect to it.
If you restart the client it *might* just work or you might need to restart gzdoom
after, need to test.
