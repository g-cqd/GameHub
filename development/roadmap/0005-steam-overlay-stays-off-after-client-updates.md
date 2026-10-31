---
status: not-started
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
