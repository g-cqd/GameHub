---
status: accepted
date: 2026-10-31
---

# 0018: The prefix is stopped only when no game is running, and Steam is asked to quit first

## Context
`hub stop` runs `wineserver -k`, which kills every process in the prefix: the stores, their downloads and any game
being played. On 2026-10-31 it was used twice to restart Steam, which killed it hard each time. Standing rule from the
owner: never kill a game they are playing.

## Decision
- **Check first:** before any action that restarts the wineserver or replaces files a running process maps, check
  for `.exe` processes other than the store clients and Wine's own services. If a game runs, don't stop the prefix:
  wait, or ask the owner.
- **Quit the stores politely:** a store is asked to quit through its own mechanism first, with the session
  environment the hub uses (`steam.exe -shutdown`, run through the hub, not a bare `wine`). Only then does the hub
  kill the prefix.
- **Building:** builds use all cores only when no game runs.

## Consequences
`hub stop` needs a polite-shutdown step for each store that waits for the client to exit (roadmap 0021).
