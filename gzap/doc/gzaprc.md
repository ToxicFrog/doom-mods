# GZAPRC, the UZArchipelago Run Control Lump

This is a lump that can be included in a WAD or PK3 to control how UZAP behaves,
both when scanning the wad and when playing it. For historical reasons, this is
called `GZAPRC`, not `UZAPRC`. The extension is irrelevant; by convention the
lump is called `GZAPRC.<wad name>`, e.g. `GZAPRC.eviternity`.

## Directives

A `GZAPRC` lump consists of a series of directives that are read by the mod on
game startup. Invalid syntax will result in an error message in the console
**but will not stop the game from loading**.

### `#` (Comments)

Comments start with `#` and run until the end of the line. There are no
multiline comments.

### Map-related directives

#### `require <map> <checksum> ;`

This GZAPRC will be loaded only if the given map is present, and has the given
checksum. This can be used to make GZAPRCs specific to a certain megawad load
only if that megawad is also loaded.

You can specify multiple require lines, in which case the GZAPRC will be loaded
if **any** of them match.

#### `scanner { ... }`

    scanner {
      maps <list of maps to start scanning at>;
      skip <list of maps to skip>;
      prune <list of maps to prune entirely>;
      recurse <true|false>;
      clusters <true|false>;
    }

Set defaults for the scanner. These settings correspond to the `ap_scan_` CVARs,
which can also be set in-game from the options menu. There is in-game help for
them, but to summarize them here:

- `maps` is the list of initial maps to start the scan with, and is typically
  a list of episode starts.
- `skip` is a list of maps to skip (i.e. not include in the output), but still
  search for exits to other maps; typically these are mid-episode intermissions
  and cutscenes.
- `prune` is a list of maps to ignore entirely; typically these are end-of-episode
  maps, but it's also needed for (e.g.) 8-level midiwads where MAP08 exits to
  doom2.wad MAP09 (and thus would cause the scanner to pick up MAP09-MAP32).
- `recurse` tells the scanner to automatically search each map for exits and
  scan those, too, which is usually what you want; if disabled, only the maps
  listed in `maps` will be scanned.
- `clusters` tells the scanner to automatically scan all maps in a cluster, even
  if it can't find exits to them, e.g. for wads that use ACS to create exits at
  runtime.

#### `prereqs { ... }`

    prereqs {
      all: <prereqs for all maps>;
      actor <ActorType> ...: <prereqs for maps with those actors>;
      map <MAPxx> ...: <prereqs for those maps>
    }

Add custom logical access prerequisites, on a per-level basis, either to all
levels, to specific named levels, or to levels containing certain actors. This
is a convenient way to, e.g., declare that if a level contains shotgunners, the
shotgun is expected by combat logic, but any valid prerequisite (as described in
[regions.md](design/regions.md) or emitted by the in-game logic editor) can be
used here.

#### `cluster <number> <name> ;`

When scanning maps in this cluster, use <name> as the cluster name rather than
the cluster or episode name reported by the WAD. <name> can contain anything
except a semicolon, including whitespace, so this is legal:

    cluster 66 Knee-Deep in the Dead;

This is primarily useful in cases where the cluster/episode autodetection does
not produce useful results, or it's desireable to abbreviate the results for
Archipelago.

#### `episode <name> : <map list> ;`

Declare the listed maps as belonging to an episode with the given name, in the
listed order. This allows maps to be grouped into episodes even in cases where
the WAD author did not follow a 1:1 cluster:episode convention, and allows map
order to be dictated by the logic maintainer rather than autodetected.

All of the listed maps will be scanned (there is no need for a `scanner` block
adding them separately).

### Item-related directives

#### `category <cat> : <class list> ;`

Assign the listed classes to the given category. Any category can be specified,
including ones not otherwise known to the scanner -- they will be passed through
to the apworld as is. This can be used to add objects to the scan that would
normally be skipped, or change the category of objects.

Some categories have special handling, such as `key`, `maprevealer`, `weapon`,
and all `ap_` categories; see [the glossary](doc/glossary.md) for a complete
list.

A category of `none` will exclude something from the scan entirely, even if it
would normally have been included.

As a special case, a category of `.replaceonly` means the item/location should
not be included in the logic file, but during gameplay, it *is* a valid target
for replacement by a check. This is primarily useful with manually placed
checks meant to replace specific props.

#### `tag <class> : <name> ;`

Supply a tag (player-facing name) for the given class of actors. This will
override the developer-provided tag the actor has, if any. This is the name that
will be used in AP messages, the user interface, etc.

In a lot of wads, some items don't have real tags, and messages like "you picked
up the Cool Item" are instead handled via custom pickup messages. This directive
provides a way to communicate to the game that it should display "Cool Item"
instead of whatever the underlying class name is.

For historical reasons, the `:` after the class is optional, but the version
with the `:` is preferred for consistency with other directives (and will become
mandatory at some point).

#### `destroy-on-spawn <class list> ;`

This directive only affects the scanner. Actors of the listed classes will be
scanned as normal, but then destroyed before they can execute any states. This
is primarily useful for actors that randomly replace or delete themselves or
spawn additional actors around them that should not be included in the scan.

#### `replacement <replacement class> : <replacee classes> ;`

Replaces all `replacee` actors with `replacement`. This applies to both the
scanner and normal gameplay, and happens **before anything else**; the
replacement occurs as the level is being loaded (or as the actor spawns in, for
actors that spawn during gameplay).

This is primarily useful for replacing non-deterministic spawners with specific,
deterministic items.

Replacements are not processed recursively, so something like this:

    replacement SuperShotgun: Shotgun;
    replacement Shotgun: SuperShotgun;

will swap super shotguns and normal shotguns, rather than looping forever.

#### `keyshape <missing> <held> : <key classes or patterns>`

Define a shape used for the key display in the inventory screen. The `missing`
and `held` shapes should each be a single character UZDoom is capable of
displaying in menus. This includes much of unicode, but emoji tend not to
work, or display badly.

The classes can be actor class names, or [globbing expressions](./glossary.md#globbing-expression).
Matching is case-insensitive.

Later `keyshape` directives take precedence over earlier ones, and GZAPRC lumps
loaded later take precedence over earlier ones.

The default configuration is:

    keyshape ◇ ◆ : *;
    keyshape ○ ● : *Skull*;
    keyshape □ ■ : *Card*;

Which is to say, keys with `Card` in the class name will use boxes, keys with
`Skull` will use circles, and everything else will use diamonds.

#### `keycolour <colour> : <key classes or patterns>`

As above, but defines a colour for the key. Since the same colour is used when
both missing and held, only one colour is needed.

Any colour listed [here](https://zdoom.org/wiki/Text_colors) can be used; use
the part of the name after the leading `CR_`. It is case insensitive.

The default configuration is:

    keycolour white: *;
    keycolour red: *red* *ruby*;
    keycolour orange: *orange*;
    keycolour yellow: *yellow* *topaz*;
    keycolour green: *green* *emerald*;
    keycolour cyan: *cyan*;
    keycolour blue: *blue* *sapphire*;
    keycolour purple: *purple* *pink* *amethyst*;
    keycolour grey: *disk* *gear*;
    keycolour black: *black* *iron*;
    keycolour gold: *gold*;
    keycolour ice: *silver* *steel*;

Which is sufficient to cover all vanilla Doom and Heretic keys and several
common types of modded key.
