---
status: not-started
blocked-by: []
date: 2026-10-31
---

# 0015: Fullscreen that holds, at the panel's native size

- **Stale monitor handle:** DXMT's cached HMONITOR goes stale ("Failed to query monitor info", "EnterFullscreenMode:
  Cannot query containing output").
- **winemac:** the Enter→fullscreen quirk.
- **Display size:** winemac reports the 5120x2880 HiDPI backing store instead of the panel's native 3840x2160. The
  external Samsung LS32D70xE is used with the lid closed. The launcher reads the native size from the main display's
  native-flagged mode since b2455c8, but Wine's display modes still need the change.

## Done when
A DXMT game toggles fullscreen several times without losing its output, and the games see 3840x2160 as the native
mode.
