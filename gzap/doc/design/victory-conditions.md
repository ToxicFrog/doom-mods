# Victory conditions

⚠️ This is a work in progress.

This document describes the proposed redesign of the victory conditions.

## Status quo

At present, you get a victory token (VT) for each map you finish (defined as: a
levelport initiated by triggering a linedef in that map). The overall win
condition is: have N VTs (by default N is the number of levels), and also have
one VT from each level in a specified set (default is {}).

## Redesign

The redesign is still token-based, but there is more flexibility in how you get
tokens.

### Token acquisition

Actions that can earn you tokens are:
- finish a level
- X% kills
- X% secrets
- X% checks

These can be enabled or disabled individually. For ease of implementation we
might want to fix X at 100% when enabled.

Additionally, the function for combining them can be selected from:
- AllOf: completing all enabled VT actions for a level gets you 1 token
- AnyOf: completing any enabled VT action for a level gets you 1 token; subsequent
  actions for the same level get you nothing
- SumOf: completing a VT action gets you a token even if you've already gotten a
  token from that level

### Win condition

The win condition is to have N VTs, and/or to have M VTs from each of a specified
set of maps.

The configurations that mimic the old behaviours are:
- N = level count, M = 0 for the defaults
- N = 0, M = 1 for the "beat these specific levels" configuration

