---
status: in-progress
blocked-by: []
date: 2026-10-31
---

# 0016: Games started by Steam become the active macOS app

A game launched by the Steam client doesn't get macOS activation, so input and focus stay with the previous app. A
handoff helper is proven in `/tmp/kusd/handoff.swift`. Move it into the repository first: `/tmp` is not kept.

## Done when
The helper, or the same logic in winemac, is part of the runtime or the hub, and a game started from the Steam UI is
frontmost with keyboard focus.

## Progress (2026-10-31)
- The helper is now `launcher/macos/activate-handoff.swift`. The other probes of that session are in
  `archive/probes/20261031-activation-input-display/`.
- `hub play` starts a background `_activate` step once the game process exists. That step waits 6 s, builds the
  helper into `Hub/State/bin` with `swiftc` when the source is newer, and hands activation to the game's Wine
  process. `HUB_NO_ACTIVATE=1` turns it off.
- It compiles, but it hasn't been run through the hub: the owner was playing, and it would have taken focus.
- Games started from the Steam UI without the hub still need the same in winemac: activation requested by the
  app's first visible window, using the cooperative `yieldActivation` path.

