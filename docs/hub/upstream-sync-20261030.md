# Upstream sync of 2026-10-30, runtime hub-2, Crysis 2 Remastered, Battlefield 3

## Forks (all merged into `main` of g-cqd/*, fast-forward, pushed)

| Fork | Upstream taken | Our fixes kept | Notes |
|---|---|---|---|
| dxmt | 3Shain/dxmt `main` 3b25259 (26 commits: D3D12 GS/tessellation, airconv fixes, winemetal leak fixes) | all, including the GTA V options (`d3d11.preciseDivide`, `strictMath`, `dxgi.maxDeviceMemory`, `debug.skipPixelShaders`) that were only on `gtav-precise-divide` | upstream 5cafc43 now retains errors on the unix side; our `AdoptAutoreleasedError` (cbf3c18) adopts the +1 handle instead of retaining again. New `bf3.exe` app profile: `sampleNaNToZero`, `defuseFma`, `preferredMaxFrameRate=60` (the settings of the tuned BF3 bundle). |
| mtld3d | athei/mtld3d `main` 82de936 (0.15.1: every display mode served, `display.maxResolutions`, x87 control word at device creation, focus window activation in fullscreen, ...) | `display.legacy4By3` now applies to the `maxResolutions` bound; `display.dropUnscalableSizes` stays latched in the adapter table | host unit tests: 2271 passed. Three e2e-harness tests (`unix/e2e/src/binary`) timed out under `taskpolicy -b` with a game running; untouched by the merge. |
| x87sidecar | athei/x87sidecar `master` | | already contained every upstream patch (checked by patch id) |
| wine | athei/wine `cx-26-patched` | `main` fast-forwarded to the mouse-button patch already in hub-1 | `winemac-real-mode-hints` is not merged (experimental, untested) |

## Runtime hub-2

Built from the `main` branch of every fork and assembled from scratch with `scripts/assemble_runtime.sh`,
`scripts/install_mtld3d.sh` and `scripts/bundle_media.py` (same file set as hub-1, no file missing):

| Component | Source |
|---|---|
| Wine | g-cqd/wine `main` 7819dea: athei cx-26-patched + our 123 commits (all ten wine-0010 bundle patches, trap-flag and W^X emulation, EA anti-cheat, raw syscalls, winemac full-screen work, mouse buttons) + the wine-0011 dsound SSE2 resampler and phase cache, which only the BF3 and NFS bundles had |
| DXMT | g-cqd/dxmt `main` ae22950 |
| mtld3d | g-cqd/mtld3d `main` 6f119dc, production profile |
| x87sidecar | g-cqd/x87sidecar `main` dbda79a |
| compatdb.so, lib/external (freetype, gnutls, SDL), hub-rules.txt | as in hub-1 (`runtime/hub-rules.txt` of the repo) |

Smoke-tested in a scratch prefix (64-bit and 32-bit `cmd`); not yet run with a game. Try it with
`hub play <game> --runtime hub-2` (the prefix session restarts when the runtime changes).

Build notes:
- `build/wine-ours` had been reconfigured on 2026-10-26 without `build-macos-x86_64.sh`, so pkg-config gave arm64
  Homebrew paths and ws2_32, winegstreamer, winedmo and sfnt2fon no longer linked. Always configure through the script
  (`WINE_BUILD_DIR=/Volumes/ExT2/GameHub/build/wine-ours ./build-macos-x86_64.sh configure --enable-archs=i386,x86_64
  --prefix=/Volumes/ExT2/GameHub/sdk/wine-ours --with-mingw`), and do not put llvm-mingw first in PATH: its `clang`
  then replaces the configured host compiler.
- DXMT's meson build dirs (`$HUB_ROOT/build/dxmt/{x64,x32}`) were configured with cross files in `/tmp/dxmt-cross`,
  which were gone; they are now kept in `toolchains/dxmt-cross/` (copy them to `/tmp/dxmt-cross/` before `ninja`).

## Battlefield 3

- The d3d11 proxy from the tuned bundle (`EA Games/Battlefield 3/d3d11.dll`) wrote every `CreateTexture2D` and RTV to
  `C:\bf3-rtv.log` (19 MB, 154k lines by 2026-10-26), unbuffered. DXMT (214562d) backs buffer RTVs itself, and the last
  BF3 log shows DXMT's own message, so the proxy only cost time. Renamed to `d3d11.dll.rtv-proxy-off`.
- The hub gave BF3 none of the bundle's DXMT settings; the `bf3.exe` profile in DXMT (hub-2) restores them.
- Open: the last BF3 session set the display mode eight times, and one tessellation pipeline failed to compile
  ("vertex shader output signature doesn't match hull shader input signature"; its draws are skipped).

## Crysis 2 Remastered (Steam 2096600)

`hub play c2r` (aliases `crysis2`, `c2`). Its process gets a DXMT info log in `Hub/Logs/dxmt-crysis2remastered/`,
`launcher/settings/Crysis2Remastered/dxmt.conf` if one is added, and `HUB_DXMT_HUD`/`--metalfx`. It ran from Steam on hub-1
(DX11, 1920x1080 fullscreen, `sys_spec 4`); its `system.cfg` also enables a Vulkan context (`r_VkContext`) for ray tracing.

## Crysis 3

Only `Bin32` is installed (EA's installer data lists Bin32 only), so it always runs 32-bit through the x87 sidecar.
Its DXMT logs show tessellation clamped to factor 8 in mesh pipelines and the 32-bit staging rename budget being reached
("waiting for the GPU instead", DXMT 1c9e911), which stalls the CPU. Both need a measured run before a change.
