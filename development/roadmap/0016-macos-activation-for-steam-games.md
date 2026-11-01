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

## Wrong process activated (2026-11-01)
The first real run through the hub hurt: HITMAN 3 started with `hub play` lost keyboard focus and mouse capture, and
Enter took it out of fullscreen, while the same game started from the Steam UI had played for five hours. `hub play`
handed activation to the first process `game_procs` found, `Launcher.exe`, which has no window: the game's own
process, `retail\hitman3.exe` (a relative command line the install-folder match misses), lost focus to it 6 s into
its start, the same path as a Cmd-Tab away. Wolfenstein II's run at 14:16 went through the same step.

Now the hub offers every Windows process started since the game's first one, without the stores' and Wine's, and
the helper activates the one that owns the largest on-screen window. When that one is already active, it does
nothing, because the handoff itself is a moment of focus loss. Each run is logged in `Hub/Logs/activate.log`.
Checked: an active app is left alone, and a process with no window gives up after 20 s without touching
activation. The handoff to a game that isn't active hasn't been watched yet.

Correction, the same evening: the 22:36 HITMAN 3 session that showed the problems was started with `--no-wait`, which
returned before the activation step, so that step did not cause them; the cause of that session's problems is not
known. The next session (22:43, Steam already running) was fine. Two gaps found on the way, fixed:
- `--no-wait` now schedules the activation step too (`_activate_game` waits for the game's first process).
- `game_procs` missed games started by a relative command line (`retail\hitman3.exe`, from Launcher.exe's folder):
  a relative path that exists in the install folder, compared without case (ExT2 is case-sensitive), is the game.

