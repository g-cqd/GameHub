---
status: accepted
date: 2026-10-22
---

# 0001: One prefix holds every store and every game

## Context
Until October each game shipped as its own wrapper app with its own prefix: NFS 2015, Far Cry 2, CoD4, BF3. Each
wrapper had a private copy of the EA app. Wrappers didn't see the EA app installed in another wrapper (the BF3 app
"does not see any ea app in the prefix"), each one differed, and a fix made in one never reached the others. On
2026-10-22 a separate "SteamLight" prefix (30 GB on the internal disk) also existed for Steam and Act of Aggression.

The owner, verbatim: "ideally we should move away from individual wrapper, and manage everything under a single
prefix that contain all game providers", and "try to make things generic so that it can work for any of the games we
currently have and any future ones".

## Decision
`$HUB_ROOT/Prefix` is the only prefix the hub runs. Drive `E:` maps to `$HUB_ROOT` and the user is `crossover`. It
holds:
- Steam, the EA app, Ubisoft Connect and the Epic launcher;
- every game installed through them, with each store's library under `$HUB_ROOT/Library/<store>`;
- games that need no store.

SteamLight was merged into it on 2026-10-22 (`docs/hub/steam-light-aoa.md`). The backup of that migration is in
`Backups/steamlight-migration-20261022/`.

## Consequences
- A store client installed once serves every game. Fixes go into the runtime and the rules (ADR-0006), not into a
  wrapper.
- One prefix means one wineserver, so only one runtime can serve it at a time (ADR-0004), and stopping it stops every
  store and game (ADR-0018).
- The portable bundles in `apps/bundler` still build their own prefixes, because a bundle is a deliverable for another
  Mac. They are not how the owner plays on this Mac.
