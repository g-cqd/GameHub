# Logitech MX Master 4 under Wine

Status: 2026-10-26. The wheel setting and the Wine patch for buttons 5 and up are applied; Back and Forward as real buttons
need Logi Options+ to be stopped and the mouse power-cycled.

## How the mouse reaches Windows programs

- The mouse is a Bluetooth LE HID device (VID 046D, PID B042). Its standard HID report has **7 buttons**, X/Y, a vertical wheel
  and a horizontal wheel (Consumer "AC Pan"). A second, vendor-specific collection (usage page FF43, HID++) carries the
  configuration and the **diverted** buttons.
- Wine's macOS HID bus (`winebus`) deliberately ignores mice and keyboards (`dlls/winebus.sys/bus_iohid.c`), so the mouse never
  shows up as a Windows HID device. Windows programs only get what `winemac.drv` builds from macOS mouse events.
- `winemac.drv` maps macOS buttons 0, 1, 2 to left, right, middle and buttons 3, 4 to XBUTTON1, XBUTTON2. Button 5 and up would
  give invalid XBUTTON data. Windows has no more than **5 mouse buttons**, so any other button can only reach a game as a key.
- Wine hard-codes `GetSystemMetrics(SM_CMOUSEBUTTONS)` to 3 and never reports a horizontal wheel
  (`SM_MOUSEHORIZONTALWHEELPRESENT` is not handled). The events still arrive; a game that checks the metric first may not
  listen for buttons 4 and 5.

## Measured with the probes in `scripts/mouse-probe/` (Options+ running)

| Control | macOS delivers | Windows program receives |
|---|---|---|
| Left, right, wheel click | mouse buttons 0, 1, 2 | `WM_L/R/MBUTTON*` and Raw Input, correct |
| Back and Forward buttons | not a mouse button: Options+ diverts them and sends its assigned action (here Smart Zoom and ⌘C) | no `WM_XBUTTON*` ever |
| Gesture (thumb) button | its assigned action (here ⌘V) | Ctrl+V |
| Top (mode shift) button, haptic panel | actions inside Options+ (wheel mode, Back gesture) | nothing a game can use |
| Vertical wheel | continuous scroll events in pixels | `WM_MOUSEWHEEL`, see below |
| Thumb wheel | horizontal scroll events | `WM_MOUSEHWHEEL` and Raw Input `RI_MOUSE_HWHEEL`, works |

Options+ has no preset that emits mouse buttons 4 or 5: its mouse cards are Middle button, Back gesture and Forward gesture
(`card_presets_osx.json`). Keystroke assignments can carry any key; Wine maps macOS F13-F20 to `VK_F13`-`VK_F20`, which gives
eight spare keys no game uses by default.

## Wheel: fixed by a Wine setting

With Options+ smooth scrolling every wheel event is "continuous": Wine multiplies the pixel delta by 6, so a slow notch gave
`WM_MOUSEWHEEL` deltas of 78 (less than one notch, which a game that divides by 120 reads as zero) and a fast flick gave 500-600
(four or five notches). `HKCU\Software\Wine\Mac Driver\UsePreciseScrolling = n` (set in the shared prefix on 2026-10-26) makes
Wine accumulate and report whole multiples of 120 instead. Remove the value to go back. A very fast spin still produces large
multiples (up to 26 notches in one event), the same distance you actually spun.

## Result of the second test (Options+ stopped, mouse power-cycled)

Stopping Options+ is not enough: the mouse stays in diverted mode until it is switched off and on (or reconnected). After that
power cycle macOS delivers **buttons 3 to 6** and Wine reports Back and Forward as `XBUTTON1` and `XBUTTON2`. The gesture (thumb) and top
buttons are buttons 5 and 6, which Wine used to encode as invalid `XBUTTON` data (4 and 8). The vertical wheel arrives as plain
notches (not continuous). The haptic panel sends nothing without Options+.

Wine patch (branch `mx-extra-buttons` of the Wine fork, `dlls/winemac.drv`): macOS buttons 5 and up now arrive as key events F13 to
F20. With the patched `winemac.so` in `hub-1`, one test gave: gesture button `VK_F13` (0x7c), top button `VK_F14` (0x7d), Back
`XBUTTON1`, Forward `XBUTTON2`. The previous file is in `Backups/hub-1-winemac-before-extra-buttons-20261026/`. The SDK copy
(`sdk/wine-ours`) has the patched file too, so a new `assemble_runtime.sh` keeps it.

Cost of this mode: with Options+ stopped, its assignments (Copy, Paste, Smart Zoom, haptic panel, Actions Ring) do not work.
Starting Options+ again diverts the buttons again; going back to games needs another power cycle of the mouse.

## What would give the mouse all its controls in games

1. **Back and Forward as real buttons 4 and 5.** Needs Options+ not to divert them. Options: quit Options+ while gaming (the mouse
   then reports its standard buttons 1-7 and macOS sends buttons 3 and 4), or give them keystrokes and bind those in the game.
2. **Gesture, top button and haptic panel.** Assign F13, F14 and F15 in Options+ and bind them in the game.
3. **Only for games.** A per-application Options+ profile would keep Copy, Paste and Smart Zoom everywhere else, but Options+
   attaches profiles to `.app` bundles and Wine is not one; whether it accepts the `wine` binary is untested.
4. **Optional Wine patch:** report 5 buttons and a horizontal wheel in `get_system_metrics`.
