// Information about a key managed by Archipelago.
//
// This is simpler than an item in some ways, since we don't have to track
// quantities -- a player either has a key or they don't.
//
// A key is identified by its user-facing name, typename, scopename, and scope.
// The scope is the set of levels the key exists in; for Doom 1/2 style maps,
// this is always just the level the key is found in, but for hubmap games like
// Hexen, Strife, Faithless, etc it may include multiple levels, and once the
// player has the key at all, they should have it in every level it's in scope
// for.

// THE KEY LIFECYCLE
//
// The lifecycle of a key is a bit complicated, because it's used in a bunch of
// different places.
//
// At startup, all keys are created with RandoState.RegisterKey(). This creates
// a Key with associated APID, typename, and scope name. This also automatically
// calls UpdateKeyScope(), which, if the scope name exactly matches the name of
// a map, initializes the Key's scope to just that map.
//
// For keys with custom (multimap) scopes, the initializer then calls
// UpdateKeyScope() repeatedly to add all relevant maps to the Key. This adds
// the map name to the Key's internal map list, but also finds the matching
// Region and adds the Key to its key-typename-to-Key lookup table.
//
// When receiving a key, the Key is looked up by APID in the RandoState, and
// flagged as held.
//
// When receiving a hint for a key, we are given the scope and the key's FQIN.
// The hint data needs to be associated with every level that the key is used
// in, so we:
// - scan the set of keys in the RandoState until we find one with a matching
//   FQIN;
// - for each level in its scope, find the matching Region, and add the hint
//   data for this key to its hint table.
//
// In the level select display, the typename-to-Key map in each Region is used
// to collect the keys for each level. Note that this means keys used across
// multiple maps will show up in the key display for every one of those maps.
//
// When entering a level, the same map is used: every key in the player's
// inventory is considered, and ones that don't have an entry in the Region-
// local map are pruned.
//
// When leaving a level, we need to check the player's inventory for keys that
// the scanner didn't know about, and create a corresponding Key for them so
// they don't get destroyed. The "did the scanner know about this" check is
// straightforward: we can once again use the Region-local Key map. If a key in
// inventory doesn't exist there, we:
// - check if it has -INTERHUBSTRIP or InterHubAmount>0
//   - if so, the scope name is "global"
//   - if not, but this level was part of a hubcluster in the original game,
//     the scope name is "cluster [original cluster ID]"
//   - otherwise it is the name of the map we are leaving
// - call RegisterKey with an invalid APID (-1?) and the chosen scope name
// - if it has global scope, also call UpdateKeyScope() for every Region in the
//   RandoState
// - if it has cluster scope, also call UpdateKeyScope for every Region originally
//   in that cluster


#namespace GZAP;
#debug off;

class ::RandoKey play {
  // Underlying type, e.g. RedCard
  string typename;
  // Short scope name, e.g. "MAP01" or "EP1".
  // FQIN is "$typename ($scopename)"
  string scopename;
  // Set of maps this key should exist in.
  Map<string, bool> maps;
  // Whether or not the player has this key.
  bool held;

  static ::RandoKey Create(string scope, string typename) {
    let key = ::RandoKey(new("::RandoKey"));
    key.typename = typename;
    key.scopename = scope;
    key.held = false;
    return key;
  }

  string FQIN() const {
    return string.format("%s (%s)", typename, scopename);
  }
}
