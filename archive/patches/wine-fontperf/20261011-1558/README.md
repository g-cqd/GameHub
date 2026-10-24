# win32u: macOS font list cache (2026-10-11 15:58)

Source: commit `825fdbcacc912a0e8ea70161e8479c8983b0a3b6` in the detached worktree
`/Volumes/ExT2/GameHub/work/wine-fontperf/src`, on top of `development` `f52b769965c` (not pushed,
`development` not moved). The patch is `0001-win32u-macos-font-list-cache.patch`; it changes only
`dlls/win32u/freetype.c` (macOS branch of the FreeType backend).

## What it does

Every Wine process that loads user32 used to ask CoreText for the available fonts with duplicate
removal. That removal costs 1.4-1.7 s per process under Rosetta. Now the first process of a
wineserver session stores the resulting file list, in load order, in the volatile key
`HKCU\Software\Wine\Fonts\MacFontCache` (value `Files`). It stores the device, inode, and
modification time of the font folders along with the list. Later processes replay the list while
those folders are unchanged, and ask CoreText again otherwise. Fonts are parsed and added exactly
as before, in the same order.

- `WINE_MAC_FONT_CACHE=0` in the environment disables the cache (old behaviour).
- The key is volatile: it lives in the wineserver's memory only and is never written to `user.reg`.
- Known limit: a font that CoreText activates without any change to a font folder appears at the
  next wineserver start, not at the next process start. Examples are a Font Book activation of a
  font in place, or a font that another application registers for the session.

## Files

| File | Install as | SHA-256 |
|---|---|---|
| `x86_64-unix/win32u.so` | `<Wine>/lib/wine/x86_64-unix/win32u.so` | `b3b12fbdf24009cbc16ea77283143db52582662942a36d07efe5c99c25f4a0a4` |

The original it replaces in `Runtimes/hub-0` and `hub-0-winemacfs` has SHA-256
`cec49d7cfe4f71eb29c05a8329adf3f801f6a162136e166ffa5c1506f6857d08`. The PE side (`win32u.dll`) is
unchanged, and 32-bit programs use the same unix `win32u.so`.

The build is x86_64 with a minimum macOS of 15.0, out of tree in
`/Volumes/ExT2/GameHub/work/wine-fontperf/build`. It uses `configure.sh` and `make.sh` from the
parent directory: FreeType comes from x86_64 Homebrew headers, with the runtime soname
`@loader_path/../../external/libfreetype.6.dylib`, and fontconfig is off, as in the runtime. Its
exported symbols match the runtime's `win32u.so`.

## Install (never into /Volumes/ExT2/Bundles or an in-use runtime directly)

```bash
PKG=/Volumes/ExT2/GameHub/work/wine-fontperf/20261011-1558
SRC=/Volumes/ExT2/GameHub/Runtimes/hub-0          # or any runtime / bundle Wine dir
DST=/Volumes/ExT2/GameHub/Runtimes/hub-0-new       # a new clone
/bin/cp -c -R "$SRC" "$DST"
L="$DST/lib/wine/x86_64-unix"
mv "$L/win32u.so" "$L/win32u.so.orig"
/bin/cp "$PKG/x86_64-unix/win32u.so" "$L/win32u.so"
shasum -a 256 "$L/win32u.so"   # expect b3b12fbd...
```

`/Volumes/ExT2/GameHub/Runtimes/hub-0-fontperf` is such a clone of `hub-0-winemacfs`, with
`win32u.so.orig` kept next to the new file.

## Rollback

```bash
L="$DST/lib/wine/x86_64-unix"
mv "$L/win32u.so.orig" "$L/win32u.so"
```

Or run with `WINE_MAC_FONT_CACHE=0`. A stale cache needs no cleanup: it disappears when the
wineserver exits, and the old `win32u.so` ignores it.

## Checks

- `fontenum.c`: dumps every `EnumFontFamiliesExW` entry with its metrics and signature, plus 42
  `CreateFontW` matches with face, metrics, and text extent. The output is byte-identical for the
  runtime's original `win32u.so`, the new one with the cache off, and the new one with the cache
  on (5278 lines).
- `modcache.c`: deletes the value, or bumps a stored folder stamp, without loading user32. It is
  used to test the miss and invalidation paths.
- `ctprobe.c`: times the CoreText calls in isolation.
- Wine's gdi32 conformance tests, all 14 units, give the same counts and the same failing lines
  with the original and the new `win32u.so`.
