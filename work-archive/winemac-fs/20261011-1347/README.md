# winemac: emulated display modes + native macOS full screen (2026-10-11 13:47)

Source: g-cqd/wine commit `ecc4a8ef878f3ae6ffcc0b649cde062ed3d17033` (on top of `development`
9bd6d74b374, made in a detached worktree at
`/Volumes/ExT2/GameHub/work/winemac-fs/src`; not pushed, `development` not moved). The patch is
`0001-winemac-fullscreen.patch`.

## Files

| File | Install as | SHA-256 |
|---|---|---|
| `x86_64-unix/winemac.so` | `<Wine>/lib/wine/x86_64-unix/winemac.so` | `d2619ad05a66f60a9b9c07118da8dc264273837a3713a625b11c5b325104153a` |
| `x86_64-windows/winemac.drv` | `<Wine>/lib/wine/x86_64-windows/winemac.drv` | `2efa81c964de67364d5dfa44ef7dc364be36d40be9112ab039bff08220d7f159` |

All changes are in the unix side (`winemac.so`). The PE `winemac.drv` comes from the same build, but
its code is unchanged: installing it is optional. Neither the 32-bit `i386-windows/winemac.drv` nor
`win32u` changes; 32-bit games such as BF3 use the same `winemac.so`.

Built for x86_64 with a minimum macOS of 15.0 (same as the runtime's), against Wine 11.0 headers
(`WINE_GDI_DRIVER_VERSION` 108). It was tested by dropping it into a clone of the BF3 bundle's
runtime (`Battlefield 3 Bundled 20261009-5ee7913`), whose `win32u.so` accepts it.

## Install (never into /Volumes/ExT2/Bundles directly)

Install into a **clone** of a runtime: a cloned bundle, or a clone of `Runtimes/hub-0`.
`cp -c` makes APFS clones, so the clone is instant and takes no space.

```bash
PKG=/Volumes/ExT2/GameHub/work/winemac-fs/20261011-1347
# Example: a clone of the hub-0 runtime
SRC=/Volumes/ExT2/GameHub/Runtimes/hub-0
DST=/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs        # any new name
/bin/cp -c -R "$SRC" "$DST"
# A clone of a bundle runtime works the same way:
#   SRC="<Bundle>.app/Contents/SharedSupport/Wine"  (or clone the whole .app and use its SharedSupport/Wine)

L="$DST/lib/wine"
mv "$L/x86_64-unix/winemac.so"      "$L/x86_64-unix/winemac.so.orig"
mv "$L/x86_64-windows/winemac.drv"  "$L/x86_64-windows/winemac.drv.orig"
/bin/cp "$PKG/x86_64-unix/winemac.so"     "$L/x86_64-unix/winemac.so"
/bin/cp "$PKG/x86_64-windows/winemac.drv" "$L/x86_64-windows/winemac.drv"
shasum -a 256 "$L/x86_64-unix/winemac.so" "$L/x86_64-windows/winemac.drv"   # compare with the table
```

When cloning a whole `.app` bundle and editing its contents, re-sign it ad hoc afterwards if the
bundle was signed (`codesign --force --deep -s - "<clone>.app"`); the `Runtimes/hub-0` layout needs no
signing step. Quit every Wine process of the prefix before swapping
(`<Wine>/bin/wineserver -k` with that `WINEPREFIX`, only for a prefix you started).

## Rollback

```bash
L="$DST/lib/wine"
mv "$L/x86_64-unix/winemac.so.orig"     "$L/x86_64-unix/winemac.so"
mv "$L/x86_64-windows/winemac.drv.orig" "$L/x86_64-windows/winemac.drv"
```

Or delete the clone. The originals of the BF3 bundle (= `Runtimes/hub-0`) are
`winemac.so` `80e348e8e76098e6e12a2e102deccff2902f633f2a469700b72bd4e80b28728a` and `winemac.drv`
`b80d447a6b7a766976319490e08d4af5beeee0096393475ac19c6f84acf1ae50`.

Without swapping files back, the old behaviour is one registry value away (for the whole prefix):

```
wine reg add "HKCU\Software\Wine\Mac Driver" /v FullscreenMode /d legacy /f
```

## The setting

`HKCU\Software\Wine\Mac Driver\FullscreenMode` (string; per prefix, no AppDefaults override,
because every process of a prefix must see the same display modes):

- `native` (default): display mode changes are emulated, and a covering window that draws with
  Metal/OpenGL/D3DMetal enters a native macOS full-screen space (Game Mode eligible).
- `borderless`: display mode changes are emulated, and covering windows stay borderless windows over
  the desktop (Dock and menu bar hidden), as before.
- `legacy`: the previous behaviour, with real hardware mode switches and display capture.

What a game sees in `native`/`borderless`:

- `EnumDisplaySettings` lists the native mode (for example 3024x1964 on a 14" MacBook Pro with
  RetinaMode=Y) and the standard sizes below it, at 60 Hz and at the desktop rate. They are listed in
  ascending order, as on Windows, and DXGI's mode list is built from the same list.
- `ChangeDisplaySettingsEx(CDS_FULLSCREEN)` succeeds at once. The requested mode becomes the current
  one for `EnumDisplaySettings`, `GetMonitorInfo` and `GetSystemMetrics`, while the hardware stays at
  its native mode. `ChangeDisplaySettings(NULL)`, or the process exiting, restores it.

## What was verified (throwaway prefix, BF3 runtime clone, 14" MBP, desktop 1800x1169@2x 120 Hz)

- **Win32 test (`test/fs_test.c`).** Mode changes return 0 in about 25 ms, and the virtual mode is
  reported back by `EnumDisplaySettings`, `GetMonitorInfo` and `SM_CXSCREEN`.
  - The physical mode, sampled with `CGDisplayCopyDisplayMode` at every stage, never changed, and
    the displays were never captured.
  - A GDI-only borderless window covering the screen stays a borderless window and does not enter a
    Space.
- **DXMT full-screen swap chain (`test/d3d_fs_test.c`).** This is the BF3/BF4 path: DXMT logs
  `Setting display mode`, then `ChangeDisplaySettingsEx(CDS_FULLSCREEN)`, the restyle and the present
  rect. It ran with `WINE_COMPATDB` set to `name=default;exe=*;dxgi=dxmt`.
  - `D3D11CreateDeviceAndSwapChain(Windowed=FALSE)` returned in 100–200 ms, with no hang.
  - The window entered a native full-screen Space (CGWindowList: 1800x1130 at y=39, below the
    camera housing). It was foreground and focused throughout, and presented about 60 fps.
  - 1920x1200 emulated: the whole frame is visible in the safe area, with the borders intact and
    black above.
  - Native size 3600x2338: the frame is scaled by 2260/2338 into the safe area, with 60 px black
    pillars.
  - `SetCursorPos` / `GetCursorPos` round trips matched to within 1 px.
  - `SetFullscreenState(FALSE)` takes about 70 ms and restores the native mode.

Not verified: Battlefield 3 or 4 themselves, multiple monitors, and leaving the Space by hand
(Esc, the green button, Ctrl-Cmd-F) while a game runs.

## Re-running the tests

`test/run.sh <runtime-dir> <exe> ...` uses the throwaway prefix
`/Volumes/ExT2/GameHub/work/winemac-fs/prefix`. For the D3D test:

```bash
export WINE_COMPATDB='v=3
name=default;exe=*;d3d9=mtld3d;dxgi=dxmt'
./run.sh /Volumes/ExT2/GameHub/work/winemac-fs/runtime ./d3d_fs_test.exe 8 1920 1200 1   # seconds w h modeswitch
./run.sh /Volumes/ExT2/GameHub/work/winemac-fs/runtime ./fs_test.exe 8 1920 1200
```

Each run takes over the screen for its duration.
