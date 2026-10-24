# DXMT v0.80: buffer render-target views (Battlefield 3/4 "CreateRenderTargetView ... E_INVALIDARG")

## What this fixes

Stock DXMT v0.80 returns E_INVALIDARG for every `CreateRenderTargetView` on a buffer.
`D3D11Buffer` (src/d3d11/d3d11_buffer.cpp) never overrides `CreateRenderTargetView`, so the call
falls through to the `TResourceBase` default (src/d3d11/d3d11_resource.hpp:287), which
returns E_INVALIDARG. Frostbite creates `D3D11_RTV_DIMENSION_BUFFER` views (R32G32B32A32_FLOAT,
8192 elements, on buffers bound as render targets; 104 of them in one BF3 session, all
E_INVALIDARG, per C:\bf3-rtv.log) and stops with the DirectX Error dialog.

The patched `d3d11.dll` creates a hidden NumElements x 1 texture of the view format for a valid
buffer RTV request. It returns a view of that texture and logs one warning:
`warn:  D3D11Buffer: render target view on a buffer (format 2, 8192 elements) is backed by a hidden texture; the buffer contents are not preserved`.
Draws into the view succeed but never reach the buffer, which is the same behaviour as the BF3
game-folder proxy. Invalid requests (no BIND_RENDER_TARGET, NULL desc, UNKNOWN format,
non-BUFFER dimension) still return E_INVALIDARG.

Source: commit 214562d726bf1708ae6add589ad85059eedbd6d3 on top of v0.80 (589adb7), in the
detached worktree /Volumes/ExT2/GameHub/work/dxmt-rtv/src-wt (registered with
/Volumes/ExT2/GameHub/src/dxmt-v0.80). Not pushed. The same change is in
`0001-dxmt-buffer-rtv-hidden-texture.patch` (`git am` onto v0.80).

## Files

| Path | What |
|---|---|
| x86_64-windows/d3d11.dll | 64-bit DXMT d3d11, Wine-builtin marked |
| i386-windows/d3d11.dll | 32-bit DXMT d3d11, Wine-builtin marked |
| test/rtv_buffer_test.cpp, test/rtv_buffer_test-{x86_64,i686}.exe | regression test (exit 0 = pass) |
| test/before-*.log, test/after-*.log | test output on stock and patched DXMT |
| build/cross-*.txt | meson cross files used (llvm-mingw 20261006) |
| SHA256SUMS | checksums |

Only `d3d11.dll` changes. dxgi.dll, d3d10*.dll, winemetal.dll and winemetal.so stay the
runtime's v0.80 files. Every winemetal symbol the new DLL imports (110 per arch) is exported by
the runtime's winemetal.dll, and the export list matches the stock d3d11.dll.

## Install (into a clone of a runtime, never in place)

A ready clone with the patch already exists: `/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv`
(APFS clone of hub-0-winemacfs plus the two DLLs below). To make another one:

```bash
bash -c '
set -euo pipefail
PKG=/Volumes/ExT2/GameHub/work/dxmt-rtv/20261011-1515
SRC=/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs          # base; left untouched
NEW=/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv   # pick a new name
(cd "$PKG" && shasum -a 256 -c SHA256SUMS)
test ! -e "$NEW"
/bin/cp -c -R -p "$SRC" "$NEW"
/bin/cp "$PKG/x86_64-windows/d3d11.dll" "$NEW/lib/wine/dxgi/dxmt/x86_64-windows/d3d11.dll"
/bin/cp "$PKG/i386-windows/d3d11.dll"   "$NEW/lib/wine/dxgi/dxmt/i386-windows/d3d11.dll"
shasum -a 256 "$NEW"/lib/wine/dxgi/dxmt/*/d3d11.dll
'
```

Then launch the game with the new runtime's `bin/wine` and a `WINE_COMPATDB` rule selecting
`dxgi=dxmt` for the game executable, as the recipes already do. The game folder needs no
proxy and no `d3d11` DllOverride. For BF3, remove the game-folder d3d11.dll proxy (or its
per-exe override) when testing this runtime, otherwise the proxy still sits in front.

Check that it took effect: the game log shows
`compatdb:   dxgi = dxmt (from .../Runtimes/<new name>/lib/wine/dxgi/dxmt)`, and the first
buffer RTV logs the `D3D11Buffer: render target view on a buffer ...` warning once.

## Rollback

Point the launcher back at the original runtime (hub-0-winemacfs or hub-0, both unmodified).
To remove the clone:

```bash
bash -c 'rm -rf /Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv'
```

To restore stock DLLs inside a clone instead:
`/bin/cp $SRC/lib/wine/dxgi/dxmt/{x86_64,i386}-windows/d3d11.dll` back over the clone's
copies. Stock sha256: x86_64 7ca382af0eb32d8a432f6efb14d594fefb45673663be1f7e6682254bff885c47,
i386 9afc2b3419818618c4c87274435a28935b0df002caa4b9a8d3a88d3dc846b17d.

## Verify (throwaway prefix only)

```bash
bash -c '
export WINEPREFIX=/Volumes/ExT2/GameHub/work/dxmt-rtv/prefix-test WINEDEBUG=-all
export WINE_COMPATDB="$(printf "v=3\nname=rtvtest-0;exe=*;dxgi=dxmt")"
R=/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv
for t in x86_64 i686; do
  ~/.agent-harness/bin/work run -- "$R/bin/wine" /Volumes/ExT2/GameHub/work/dxmt-rtv/20261011-1515/test/rtv_buffer_test-$t.exe
done'
```

Stock runtime: `FAIL buffer RTV, R32G32B32A32_FLOAT x 8192 elements hr=0x80070057`, exit 1.
Patched clone: all 7 checks PASS, exit 0, on both 64-bit and 32-bit.

## Rebuild

```bash
bash -c '
W=/Volumes/ExT2/GameHub/work/dxmt-rtv
for t in x86_64 i686; do
  meson setup $W/build/$t $W/src-wt --cross-file $W/build/cross-$t.txt --buildtype release \
    -Dwine_install_path=/Volumes/ExT2/GameHub/toolchains/wine-sdk-cx-26.3.0-5/wine \
    -Dnative_llvm_path=/opt/homebrew/opt/llvm
  ninja -C $W/build/$t src/d3d11/d3d11.dll src/d3d11/d3d11.dll.postproc
done'
```

The cross files force `-include functional -include iterator`, because v0.80's
sha1_util.hpp and ftl.hpp miss those includes under llvm-mingw's newer libc++. The
`postproc` target runs `winebuild --builtin`, which adds the Wine builtin marker.
