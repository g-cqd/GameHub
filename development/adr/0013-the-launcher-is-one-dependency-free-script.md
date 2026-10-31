---
status: accepted
date: 2026-10-14
---

# 0013: The hub's launch path is one dependency-free script

## Context
The October work produced two kinds of code:
- **Swift apps** in `apps/bundler`: the GameHub.app library, the starters and the session helper. Their purpose is
  portable, signed and notarised bundles for another Mac.
- **Shell scripts** on ExT2 (`start-ea.sh`, `start-steam.sh`, `hubenv.sh`), which drifted apart.

The owner wants "proper ways to run our apps and fixes" instead of scripts.

## Decision
`launcher/hub` is the one launch path on this Mac. It is a single Python 3 file that uses only the standard library
and is tested by `launcher/tests`. It discovers games, picks the runtime (ADR-0004), prepares the stores, builds the
session environment, and starts and stops the prefix. It does nothing while a game runs, apart from optional
watchers. The per-program knowledge it still holds is moving into the runtime rules (ADR-0006).

## Consequences
- The ExT2 scripts are superseded and to be deleted.
- A native front end (a menu-bar or library app over `launcher/hub`) is an open roadmap item (0027). It must keep the
  script as the one engine rather than duplicate its logic.
