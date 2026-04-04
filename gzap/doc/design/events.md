# Event-based locations

Event-based locations are locations that, rather than being associated with a
statically placed item in the world, are associated with the occurence of some
event during gameplay. They are identifiable by a `pos` field that, rather than
having the usual form of `[map,x,y,z]`, is instead `[map,"event type",...]`,
where the tail fields depend on the event.

## `[map,"event","exit"]` (legacy)
## `[map,"exit"]`
## `[map,"exit",destination]`

This location does not exist in the logic file; the apworld creates one of these
implicitly for every map (or cluster). It does, however, exist in the tuning
file. This location is checked when the player exits the map (in the normal
manner, not by loading a game or using the levelport menu).

At present the exit location always contains a clear token. There are plans to
track level clear status separately and allow items to be randomized into the
level exit.

The first form is what currently exists in the tuning files. The second form is
what I plan to replace it with. The third form is a proposal for supporting
multiple exit events based on where they go, so e.g. "exit from Port Mercy to
Dockside" and "exit from Port Mercy to Odious Gardens" can be different events.

## `[map,"secret","sector",id]`
## `[map,"secret","tid",id]`

This location is defined in the logic file, using an AP-SECRET message (which
contains only the position) rather than an AP-ITEM. This location is checked
when the corresponding secret is discovered by the player. The first form
associates the location with a secret sector; the second form with the
`SecretTrigger` item with the given TID. (`+COUNTSECRET` actors are not
currently supported.)

## `[map,"spawn",n,typename]`
## `[map,"spawn",n,typename,x,y,z]`
## `[map,"spawn",n,typename,x,y,z,r]`

This location is triggered by the spawning of a specific actor at runtime. The
`typename` denotes the actor. `n` is the number of spawns to turn into
locations. If this is more than one, multiple locations will be created numbered
1 through `n` inclusive. In the tuning file, `n` corresponds to the specific
number that was checked.

The second form gives a precise position at which the actor must spawn; spawns
in other locations are ignored. This is useful for items spawned by scripts.

The third form gives a position and a radius, which is useful for items that
spawn as death drops, e.g. from minibosses.

The location will not be automatically checked when the item spawns; rather, the
item will be replaced with a normal check that the player must then collect.

### Implementation

We define a mapping from event types as listed above to string *event ids*,
probably something like:

- exit: `exit`
- secret: `secret:sector:<id>` or `secret:tid:<tid>`
- spawn: `spawn:<type>`

When a relevant event happens, the PerLevelHandler calls

hmm

Ok, we can't do this as straightforwardly as I would like. With secrets, we need
to know the sector or thing ID to generate the event, but we don't know which
one just got discovered, only that the secret count changed, so we need to walk
the list of all secret locations and check them against the sector and TID lists
to find out which one(s) have now been checked.

With spawns, we know the thing type and coordinates, but since we support area-
based spawn events, that's not sufficient either, we need to walk all locations
associated with that spawn type to find the matching one.

So maybe we do something like this.

An EventPosition is a location position associated with an event. When that
event fires, it knows how to check if the event is actually relevant to it.

This is done with, idk, HandleEvent(string event_type, Actor thing)

If it's an ExitPosition, it checks itself as soon as the event fires. thing is unused.

If it's a SecretPosition, it checks the current secret status of the map, and
checks itself if the corresponding secret is no longer marked. thing is unused.

If it's a SpawnPosition, it checks that the spawned thing exists, is of the right
type, and (if it has a defined position) is within the position radius. If those
checks pass, it marks itself as spawned and summons a CheckPickup for itself.

Alternately we can have it check directly, which avoids the case where the player
summons the pickup and then resets the level -- that's fine for stuff like the
AOS rocket disks where they can just kill the minibosses again, but it breaks
things like Hedon where you expend resources to get the checks.

Ok so let's see

When defining a Location in the generated zscript, we can give it a physical
position, or an "event position" which is either an exit event (optionally with
a destination map), a secret event (with sector ID or trigger TID), or a spawn
event (with spawn type, quantity, position, and radius).

The region maintains an event-type-to-list-of-locations mapping.

When an event happens, we call an appropriate event handler on the Region,
probably something like:

- HandleExitEvent(next_map)
- HandleSecretEvent()
- HandleSpawnEvent(actor, pos)

The region looks up the corresponding list and invites every location in it to
trigger.

If it's an exit event, we check all locations with unscoped exits and all
locations with exits pointing to next_map.

If it's a secret event, we check all locations where the map says that the
corresponding sector is revealed/TID is removed.

If it's a spawn event, we also need to turn it into an index. So, when
registering an event predicated on a certain spawn type, we also initialize a
counter for that spawn type at 0; if there's no counter we ignore the event, if
there is we inc it and then fire the location with that index.
