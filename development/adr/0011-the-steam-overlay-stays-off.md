---
status: accepted
date: 2026-10-22
---

# 0011: The Steam overlay stays off

## Context
The Steam overlay crashes Act of Aggression right after its intro, and its hook is a risk for every DXMT game.
`hub doctor` checks for it.

## Decision
Before Steam starts, `prep_steam()` moves `GameOverlayRenderer.dll`, `GameOverlayRenderer64.dll`, `gameoverlayui.exe`,
`gameoverlayui64.exe` and `GameOverlayUI.exe` to `Library/Steam/_overlay-disabled`.

## Consequences
The 64-bit client restores these files when it updates while running, and it also ships `SteamOverlayVulkanLayer*`,
which the list doesn't cover. `hub doctor` failed on this on 2026-10-31. The mechanism must also run before each game
launch, or be replaced by one the client doesn't undo (roadmap 0005).
