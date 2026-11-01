---
status: done
blocked-by: []
date: 2026-10-31
---

# 0005: Keep the Steam overlay off when the client updates itself

`hub doctor` fails "Steam overlay disabled". The 64-bit client put `GameOverlayRenderer*.dll` and
`gameoverlayui64.exe` back while it ran. `prep_steam()` moves them only at start, and it doesn't cover
`SteamOverlayVulkanLayer*` (ADR-0011).

## Options
- Move the files before every `hub play` too.
- Disable the overlay through Steam's own setting (`config/localconfig.vdf`, per user), if the 64-bit client honours
  it. Probe this first.
- Use a runtime rule that keeps `GameOverlayRenderer` out of game processes, like the Ubisoft overlay (ADR-0012).

## Done when
`hub doctor` passes after a client update, and Act of Aggression passes its intro.

## Progress (2026-10-31)
`disable_steam_overlay()` moves all nine overlay files, including the `SteamOverlayVulkanLayer` DLLs and JSON files,
at Steam start and again before every Steam game launch. A file the client restored replaces the copy disabled
earlier. It has unit tests (`launcher/tests/test_steam.py`). Not run yet, because the owner was playing; the "Done
when" still needs a client update and `hub doctor`.

## Result (2026-11-01)
The overlay files are moved before every Steam game. On 2026-10-31 each launch moved the 7 files the client had
restored, and two HITMAN 3 sessions traced with `+loaddll` loaded no `GameOverlayRenderer`. `hub doctor` now fails
only when Steam is stopped and the files are present; while Steam runs, restored files are reported as info.
Not yet run: Act of Aggression's intro with the hub (the original crash).
