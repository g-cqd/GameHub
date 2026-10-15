# winemac: emulated display modes + native macOS full screen, rev 2 (2026-10-11 15:21)

Source: g-cqd/wine, two commits on top of `development` 9bd6d74b374. They were made in a detached
worktree at `/Volumes/ExT2/GameHub/work/winemac-fs/src`; nothing is pushed and `development` has not
moved.

- `ecc4a8ef878` winemac: Emulate display modes and use native full screen for covering windows.
- `f52b769965c4e9f40c83ace2fc784986bf24545e` winemac: Keep the full-screen space black where the
  program draws nothing.

The patches are `0001-*.patch` and `0002-*.patch`. This package supersedes `../20261011-1347`.

## What changed since 20261011-1347

The bug: in the native full-screen space, a strip a few pixels wide at the right edge of the screen
was white.

- **Cause.** DXMT sets a present rect for a full-screen swap chain. win32u then hands the driver
  monitor-sized rects, so there is no letterbox mask, while the Metal layer's view follows the
  window's client rect. A game whose window ends up a few pixels narrower than the monitor (BF4 at
  the native mode) leaves a strip where the window surface shows through. A Direct3D program never
  paints that surface, so it stays white.
- **Reproduction.** The D3D11 test with its window narrowed by 6 px gives a white strip at
  x 3534–3539 of a 3600 px screen with the 20261011-1347 build.
- **Fix.** While the window is in the space, an opaque black layer of the driver's own now sits
  under the program's views and covers the whole content area. Anything the game doesn't draw is
  black.
  - Changing the window's or the content layer's background colour instead caused AppKit to reveal
    the full-screen title bar. A bisect showed this, so it isn't done.
- **Placement.** Fitted content now sits on whole device pixels, centred. Content that already fits
  the space is shown at exactly 1:1 with no resampling.
- **The notch.** On a notched display, a game at the native mode (3600x2338) cannot be 1:1: the
  space below the camera housing is only 2260 px tall. It is scaled to fit, keeping its aspect
  ratio, with equal black bars left and right (60 px each).

## Files

| File | Install as | SHA-256 |
|---|---|---|
| `x86_64-unix/winemac.so` | `<Wine>/lib/wine/x86_64-unix/winemac.so` | `bc25480591c3a264e2cbedb3ef4fb5d3de1899afd9fa95536242f1a679beac84` |
| `x86_64-windows/winemac.drv` | `<Wine>/lib/wine/x86_64-windows/winemac.drv` | `2efa81c964de67364d5dfa44ef7dc364be36d40be9112ab039bff08220d7f159` (unchanged since 1347) |

All changes are in the unix side (`winemac.so`). The PE `winemac.drv` comes from the same build, but
its code is unchanged: installing it is optional. Neither the 32-bit `i386-windows/winemac.drv` nor
`win32u` changes. It is built for x86_64 with a minimum macOS of 15.0, against Wine 11.0
(`WINE_GDI_DRIVER_VERSION` 108). It was tested in a clone of the BF3 bundle runtime
(`Battlefield 3 Bundled 20261009-5ee7913`, the same files as `Runtimes/hub-0`).

## Updating an existing install (for example `Runtimes/hub-0-winemacfs`)

Quit the game and every Wine process of that prefix first. Then replace only `winemac.so`; the
`.orig` file from the first install stays as the rollback copy:

```bash
PKG=/Volumes/ExT2/GameHub/work/winemac-fs/20261011-1521
L=/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs/lib/wine
/bin/cp "$PKG/x86_64-unix/winemac.so" "$L/x86_64-unix/winemac.so"
shasum -a 256 "$L/x86_64-unix/winemac.so"    # bc25480591c3a264...
```

## Fresh install (never into /Volumes/ExT2/Bundles directly)

Install into a clone of a runtime. `cp -c` makes APFS clones, so the copy is instant and takes no
space.

```bash
PKG=/Volumes/ExT2/GameHub/work/winemac-fs/20261011-1521
SRC=/Volumes/ExT2/GameHub/Runtimes/hub-0          # or "<Bundle>.app/Contents/SharedSupport/Wine"
DST=/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs2
/bin/cp -c -R "$SRC" "$DST"
L="$DST/lib/wine"
mv "$L/x86_64-unix/winemac.so"      "$L/x86_64-unix/winemac.so.orig"
mv "$L/x86_64-windows/winemac.drv"  "$L/x86_64-windows/winemac.drv.orig"
/bin/cp "$PKG/x86_64-unix/winemac.so"     "$L/x86_64-unix/winemac.so"
/bin/cp "$PKG/x86_64-windows/winemac.drv" "$L/x86_64-windows/winemac.drv"
shasum -a 256 "$L/x86_64-unix/winemac.so" "$L/x86_64-windows/winemac.drv"
```

If you cloned a signed `.app` bundle, re-sign the clone ad hoc
(`codesign --force --deep -s - "<clone>.app"`).

## Rollback

```bash
L=<clone>/lib/wine
mv "$L/x86_64-unix/winemac.so.orig"     "$L/x86_64-unix/winemac.so"
mv "$L/x86_64-windows/winemac.drv.orig" "$L/x86_64-windows/winemac.drv"   # if it was replaced
```

You can also go back one step to `../20261011-1347/x86_64-unix/winemac.so`, or delete the clone.
The originals in the BF3 bundle and `Runtimes/hub-0` are `winemac.so`
`80e348e8e76098e6e12a2e102deccff2902f633f2a469700b72bd4e80b28728a` and `winemac.drv`
`b80d447a6b7a766976319490e08d4af5beeee0096393475ac19c6f84acf1ae50`.

To get the old behaviour back without swapping files, for the whole prefix:
`wine reg add "HKCU\Software\Wine\Mac Driver" /v FullscreenMode /d legacy /f`

## The setting

`HKCU\Software\Wine\Mac Driver\FullscreenMode` is a string that applies to the whole prefix:

- `native` (default): display modes are emulated, and a covering window that draws with
  Metal/OpenGL/D3DMetal enters a native macOS full-screen space.
- `borderless`: display modes are emulated, and covering windows stay borderless windows over the
  desktop.
- `legacy`: real hardware mode switches and display capture, as before.

## Verified

Setup: a throwaway prefix, the BF3 runtime clone, a 14" MBP with the desktop at 1800x1169@2x
(3600x2338 px) and 120 Hz, and DXMT selected with `WINE_COMPATDB`. Screenshots were taken 5 s in.
All four edges were checked for near-white pixels (≥250 in a 150 px band), and colour runs were
printed along rows and columns at 10, 50 and 90 % (`test/edge_run.sh`, `test/edges.m`).

| Case | Swap chain | White px at edges (left/right/top/bottom) | Horizontal | Vertical | Title bar |
|---|---|---|---|---|---|
| Native, window 6 px narrower (BF4-like) | 3600x2338, no mode switch | 0/0/0/0 (1347 build: right 11300, x 3534–3538) | 60 black · content · 66 black | 78 black (notch) · content to 2337 | hidden |
| Native | 3600x2338, no mode switch | 0/0/0/0 | 60 black · 3480 content · 60 black | 78 black · 2260 content | hidden |
| Smaller virtual mode | 1920x1200, mode switch | 0/0/0/0 | content 0–3599 | 83 black · 2250 content · 5 black | hidden |

In every case:

- Swap-chain creation took 120–150 ms, with no hang.
- The window was foreground and focused, in a native Space at 1800x1130 pt below the camera
  housing.
- `SetCursorPos` / `GetCursorPos` round trips matched.
- `SetFullscreenState(FALSE)` took about 60 ms and restored the native mode.
- The physical display mode never changed and the displays were never captured.

The earlier results in `../20261011-1347/README.md` still hold: the mode list, the GDI-only
borderless fallback, and 1920x1200 with a full frame.

Not verified: Battlefield 3 or 4 themselves with this revision, multiple monitors, and leaving the
Space by hand while a game runs.

## Re-running the tests

```bash
cd test
# edge_run.sh expects the layout of /Volumes/ExT2/GameHub/work/winemac-fs/test (runtime clone,
# throwaway prefix, /tmp/wfs/{modes,winlist,edges} built from the .c/.m files here).
./edge_run.sh native 7 3600 2338 0 0      # tag seconds w h modeswitch shrink-px
./edge_run.sh shrink 7 3600 2338 0 6
./edge_run.sh virtual 7 1920 1200 1 0
```

Each run takes over the screen for about 7 seconds.
