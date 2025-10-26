# Region-based logic

Work on Faithless reveals that while the autotuner is fine for classical doom
maps, for more complicated wads we require something more sophisticated. For
this, we use *regions*. A region is a named, map-scoped area defined by the user
when tuning the wad; once defined, any checks collected are associated with that
region until a new one (or lack of one) is defined.

Like checks, the same region can be defined multiple times, and the access
requirements combined by the logic loader to produce a minimal disj-of-conjs
describing the access requirements.

No provision is currently given for modeling edges between regions. If region A
has no requirements, region B can be reached from A using just the yellow key,
and region C can be reached from B using just the green key, C requires both the
green and yellow keys, same as checks.

## On naming

In Archipelago, these are modeled with Region objects, as are the enclosing
maps. At runtime, a zscript `Region` currently has a 1:1 correspondence with
a map lump and the (sub)regions described here aren't modeled at all except as
a tag to be emitted into the tuning file.

## The UI

In-game, the play accesses region control via the inventory screen. This
contains a widget that can be used to set or unset the current region name,
along with controls for keys, weapons, and maps.

### Keys

This is just the key control UI that already exists -- it shows all keys valid
in the current scope, and if the user has any, lets them be toggled on and off.
Keys toggled on will be considered requirements to access the current region.

### Weapons

This lists all weapons the player has received through AP and lets them be
toggled between ignored, soft-required, and hard-required. A soft-required
weapon is used for carryover weapon logic; by default a region is in logic when
you have half of its soft-required weapons. A hard-required weapon is needed to
access the region at all and models things like walls that can only be broken by
certain weapons.

### Maps

This lists all maps in the current scope (if there are more than one). Maps flip
to visited as the player first visits them and can be flipped back to unvisited
by the user. Access to visited maps is considered a hard requirement for region
access; this models behaviour like "to reach this region of map A you must
detour through map B".

## The AP-REGION message

When a region is (re)defined from the UI, this causes an `AP-REGION` message to
be emitted. The message declares the enclosing map, the name of the region, and
the requirement list. Regions are scoped to a map, so multiple regions can have
the same name as long as they are in different maps.

The message also includes a list of prerequisites needed to access the region,
named `keys` to match AP-CHECK, with extensions to support things that are not
keys.

### Extended keylist format

Entries in a keylist have the form `type/name/qualifier`. The following types
are supported:

`map`. The `name` is the lump name, e.g. `map/E1M1`. The qualifier is optional;
if present, this is the name of a subregion, e.g. `map/E1M1/belltower`. The
player must have the access token for the given map. If a region is specified,
they must also have access to the given region.

`key`. The `name` is the key typename, e.g. `key/KeyYellow`. Qualifier is not
currently supported, although I could see it being useful for count, e.g. for
stacking key items like the souls in Golden Souls. The key scope is implicitly
the scope the region belongs to.

`weapon`. The `name` is the weapon typename, e.g. `weapon/Crossbow2`. The
qualifier is required and can be either `want`, for a weapon considered in
carryover weapon logic according to the yaml, or `need`, for a weapon which is
absolutely required to reach the check. In practice most things will be `want`,
but some checks may need rocket jumps, barriers that can only be destroyed with
certain weapons, etc.

We may in the future want to add `location`, for "this is not in logic unless
this specific location is reachable", and `item`, for "this is not in logic
unless you have found this non-key, non-weapon item somewhere".

As a special case for backwards compatibility, a completely unqualified name is
taken as the name of a key in the same scope, i.e. there is an implicit `key/`.

## Changes to AP-CHECK

An `AP-CHECK` message can have a `region` field. If present, this is the name of
the check's enclosing region, and access to the region is a prerequisite for
accessing the check.

The `keys` field is omitted by default if a region is defined. If both fields
are present they form a logical conjunction, i.e. that location requires both
access to the enclosing region and everything in the `keys`. The `keys` field
now uses the *extended keylist format* described above.
