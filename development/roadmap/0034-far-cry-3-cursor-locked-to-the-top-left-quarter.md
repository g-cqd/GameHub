---
status: not-started
blocked-by: []
date: 2026-11-01
---

# 0034: Far Cry 3's cursor is locked to the top-left quarter of the screen

Reported by the owner three times. The game is a DPI-unaware 32-bit DX11 game, full screen at 2560x1440 on a
5120x2880 raw desktop (`LogPixels` 192, `RetinaMode=y`, `FullscreenMode=native`).

## Facts (trace `ubisoft-20261101-022842.log`, `+cursor,warn+macdrv`)
- During the owner's test, every `macdrv_mouse_moved` came from Ubisoft Connect's thread `0184` (window `0x100ae`).
  The thread predates the game, so it belongs to `upc.exe`. The game process logged none.
- x never exceeded 2559 raw (half of 5120).
- The game's thread `09f0` only hid the cursor (`NtUserSetCursor 0x0`, 244 times) and called `ClipCursor(NULL)`
  (400 times). It draws its own cursor.
- The `ClipCursor` rects in the session are full screen in raw pixels (`(4,66)-(5116,2880)`).
- `NtUserSetCursorPos` and `NtUserGetCursorPos` both map between virtual and raw coordinates.

## Not yet known
- Whether the game process is ever the active macOS app with the key window. Measure the front app and key window
  once per second while the owner moves the mouse, before changing code.
- Whether the same cause is behind Wolfenstein II's mouse after Cmd-Tab (0029).

## Done when
The game's cursor reaches all four corners, and mouse events are delivered to the game's process.
