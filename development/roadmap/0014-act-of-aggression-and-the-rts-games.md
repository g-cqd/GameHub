---
status: not-started
blocked-by: []
date: 2026-10-31
---

# 0014: Act of Aggression and the RTS games

- **Act of Aggression:** bisect the graphics settings, then add a MetalFX preset (an `Option.ini` seed in the
  launcher, a rule for the upscaler).
- **To test:** Rise of Nations (287450), Generals (2229870) and C&C Zero Hour (2732960).
- **Reinstall:** Steam uninstalled the Unity "Zero Hour" (1359090) and Rise of Nations on 2026-10-30.
- **Unity "Zero Hour":** an uncommitted `zero-hour-metalfx` rule waits in `runtime/hub-rules.txt`. Commit it after
  testing.

## Done when
Each reaches gameplay, and AoA has a preset that holds its frame rate at the display's native size.
