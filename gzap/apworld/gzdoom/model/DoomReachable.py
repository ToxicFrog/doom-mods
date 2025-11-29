from typing import NamedTuple, Optional, Set, List, FrozenSet, Collection

from . import prereqs

class DoomReachable:
    """
    A class for things that we can reach in-game, with rules about when it is
    and is not reachable based on the game state.

    This is the superclass for both Locations (representing individual points in
    a map where items can be found) and Regions (representing map areas that may
    or may not contain locations within them). Ideally it would also be the
    superclass for Maps but Maps are complicated inside and were originally
    written without this commonality of functionality in mind.
    """
    # Or-of-ands of prerequisites needed to access this place, in the format
    # described in regions.md.
    prereqs: FrozenSet[FrozenSet[str]] | None = None
    # Unprocessed tuning data read from the tuning file and not yet turned into
    # prereqs.
    tuning: List[FrozenSet[str]]
    # Unreachability flag.
    unreachable: bool = False

    def __init__(self):
        self.tuning = []

    def record_tuning(self, keys: List[str] | None, unreachable: bool = None):
        """
        Record a single tuning record for this location. This won't be turned into
        actual reachability logic until all logic and tuning has been loaded.

        The tuning data is stored as a list of sets of requirement strings.
        Once all tuning data is loaded, it gets minimized (redundant sets pruned)
        and turned into actual evaluatable requirements.
        """
        if unreachable is not None:
            self.unreachable = unreachable
        self.tuning.append(frozenset(k if '/' in k else 'key/'+k for k in keys))

    def finalize_tuning(self, default):
        """
        Compute the minimal version of the tuning data and store it in self.keys.

        If there is no tuning data, use default.
        """
        keysets = set()
        for tuning in self.tuning or default:
            # Remove all keysets we've seen so far that the tuning is a proper
            # subset of
            keysets = set(ks for ks in keysets if not (tuning < ks))
            # Add the new keyset iff there is no existing keyset that it is a
            # proper superset of.
            if not frozenset(ks for ks in keysets if ks < tuning):
                keysets.add(frozenset(tuning))

        # print(f'Tuning {self}: optimizing {self.tuning} -> {keysets}')
        self.prereqs = frozenset(keysets)

    def access_rule(self, world, wad, map):
        """
        Convert the string-based requirements in self.keys into a callable rule
        evaluator for use by the logic engine.
        """
        prereq_fns = [
            prereqs.strings_to_prereq_fn(world, wad, map, ps)
            for ps in self.prereqs
        ]

        def rule(state):
            if hasattr(world.multiworld, "generation_is_fake"):
                # If Universal Tracker is generating, pretend that locations
                # with the unreachable flag are unreachable always, so they
                # don't show up in the tracker.
                if self.unreachable:
                    return False
                # Also consider everything unreachable in pretuning mode, because
                # in pretuning the idea of "logic" kind of goes out the window
                # entirely.
                if world.options.pretuning_mode:
                    return False

            # Skip all checks in pretuning mode -- we know that the logic is
            # beatable because it's the vanilla game.
            if world.options.pretuning_mode:
                return True

            # If this location has no prerequisites, trivially succeed.
            if not prereq_fns:
                return True

            # Prereqs is an or-of-ands, so if any prereq succeeds, the rule
            # succeeds.
            for fn in prereq_fns:
                if fn(state):
                    return True

            # If keys are forced to be in vanilla locations, assume that all
            # items are reachable since key-based progression will work as normal.
            # TODO: replace with a more sophisticated check that confirms that
            # *all* items we have as prereqs have vanilla location placement.
            if world.options.included_item_categories.all_keys_are_vanilla:
                return True

            return False

        return rule


