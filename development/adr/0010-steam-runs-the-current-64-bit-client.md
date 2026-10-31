---
status: accepted
date: 2026-10-31
---

# 0010: Steam runs the current 64-bit client

## Context
On 2026-10-22 the current Steam client did not render under hub-0 (blank window, update prompts, "steam folder not
writable"). The hub then ran an older 32-bit client with its updates blocked by flags and a blocked update host. Steam
has since retired the 32-bit client, and a blocked client can't install or update games.

## Evidence
On hub-2 the current 64-bit client renders, signs in and updates itself (307536d, 2026-10-31).

## Decision
- **Client:** `Library/Steam` is the current 64-bit client, updating itself normally, on hub-2. The update block and
  the anti-update flags are gone. The 32-bit client is kept in `Library/Steam-legacy` as the only rollback.
- **Steam Client Service:** it is installed as Steam installs it.
- **Library:** games are registered in `Library/Steam/steamapps` with Steam's own manifests. Where a game's files are
  already on disk, its manifest is restored from the old library, or written minimally and left for Steam to rewrite
  (HITMAN 3, Crysis Remastered and Wolfenstein II on 2026-10-31).

## Consequences
- The client updates itself, and an update can bring back files the hub disables (the overlay, ADR-0011).
- Launching a game through the 64-bit client is not yet tested (roadmap 0006).
- `Library/Steam-legacy` (1.1 GB) can go once the owner no longer wants the rollback.
