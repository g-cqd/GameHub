# DXMT: Crysis 3 in-game hang after "Failed to create mesh PSO" (M2 Pro), complete fix

This package supersedes ../20261011-2217. The diagnosis and its evidence are in
../20261011-2217/README.md and are not repeated here. Compared with that package, this one:

- **renders the effect instead of skipping it.** The converter now gives the geometry
  shader a mesh output for every varying the pixel shader reads, so Apple's compiler no
  longer crashes. This needs a new `winemetal.so`.
- **drops dispatches whose compute pipeline failed** (same defect as for draws), and
  retries compute pipelines on a lost compiler connection.

## Root cause (short)

On M1/M2, Apple's shader compiler crashes when a geometry shader pipeline is linked to a
pixel shader that reads a varying the geometry shader does not write. Crysis 3 does
that. D3D11 allows it: the value is undefined.

DXMT then made it worse in three ways:
1. It ran the draw with the previously bound pipeline (GPU page fault, everything after
   it ignored).
2. It released the Metal error twice (crash, so teardown hangs).
3. Pipelines compiling at the same moment failed too.

## Commits (detached worktree /Volumes/ExT2/GameHub/work/dxmt-tess/src-wt, on 1c9e911 = gcqd/development; not pushed)

| # | Commit | What |
|---|---|---|
| 1 | cbf3c18 fix(winemetal): retain autoreleased errors returned to Reference<Error> | Metal.hpp (compiled into d3d11.dll) |
| 2 | cb535b3 fix(d3d11): drop draws whose render pipeline failed to compile | plus shader hashes in mesh PSO errors, the regression test, and the meson.build fix |
| 3 | 8bad5a1 fix(d3d11): retry pipelines whose compile lost the compiler service | up to 2 retries on XPC_ERROR_CONNECTION_INTERRUPTED |
| 4 | 82b4f16 fix(d3d11): drop dispatches whose compute pipeline failed to compile | same for compute; compute PSOs retried too |
| 5 | 2d4d1a9 build(airconv): use the public atomic API in air_tessellation.metal | needed to build airconv with the macOS 27 Metal toolchain (32023) |
| 6 | 71994e6 fix(airconv): output the varyings a pixel shader reads from a GS mesh pipeline | GS variant keyed on the pixel shader; varyings the GS does not write read as zero |

The `000*.patch` files apply with `git am` onto 1c9e911.

## Files

| Path | What |
|---|---|
| i386-windows/d3d11.dll, x86_64-windows/d3d11.dll | patched d3d11 (Wine-builtin marked) |
| x86_64-unix/winemetal.so | patched unix side with the converter fix. It is used by both 32-bit and 64-bit games (WoW64). |
| 000*.patch | the 6 commits |
| test/ | regression test source and exes, run scripts, all before/after logs |
| evidence/, build/ | as in the previous package |
| SHA256SUMS | checksums |

`winemetal.so` was built from the same sources against LLVM 15.0.7, the version DXMT's
CI pins, using the official x86_64 macOS release
(/Volumes/ExT2/GameHub/toolchains/llvm-15.0.7-x86_64).
- It links the same system libraries as the runtime's copy, and exports the same
  symbols plus one new airconv function.
- CI builds LLVM with assertions on and the release tarball has them off. That only
  changes LLVM-internal symbols.
- winemetal.dll, dxgi.dll and d3d10*.dll are unchanged.
- The new d3d11.dll also works with the old winemetal.so: the old converter ignores the
  new argument and you get the previous package's behaviour.

## Test results (throwaway prefix /Volumes/ExT2/GameHub/work/dxmt-tess/prefix-test)

`test/run_test.sh RUNTIME ARCH LOG MODE [idle_ms]`, test `dx11_failed_pipeline`:

| Mode | Stock 1c9e911 | This package (runtime clone runtime-link) |
|---|---|---|
| gs (Crysis case: PS reads TEXCOORD1, GS does not write it) | compiler crash, the draw runs with the previous pipeline (red), teardown hangs | compiles, renders exactly green (TEXCOORD1 = 0), exits 0 (i686, x86_64) |
| vs (same mismatch, VS→PS: Metal rejects the link) | the draw runs with the previous pipeline (red), hang | draw skipped, exits 0 |
| ts (one patch at tess factor 64, clamped to 8) | 1024/1024 pixels | 1024/1024 pixels |
| control (stages that link) | pass | pass |
| rtv_buffer_test, staging_rename_test (earlier packages) | - | pass, both arches |

Not covered by a test:
- The compute dispatch skip. A compute pipeline that fails cannot be produced on
  purpose.
- The packed-register case (PS reads `regN_2` where the GS writes `regN_0`). This is
  handled by the same code path, but vkd3d's HLSL compiler cannot be made to emit it.
- The game's real shader pairs. Its shader paks are encrypted; the next run logs any
  remaining failure with its hashes.

## Install (into a runtime clone, never in place)

```bash
bash -c '
set -euo pipefail
PKG=/Volumes/ExT2/GameHub/work/dxmt-tess/20261011-2246
SRC=/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv   # live runtime; left untouched
NEW=/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmttess  # pick a new name
(cd "$PKG" && shasum -a 256 -c SHA256SUMS)
test ! -e "$NEW"
/bin/cp -c -R -p "$SRC" "$NEW"
/bin/cp "$PKG/x86_64-windows/d3d11.dll" "$NEW/lib/wine/dxgi/dxmt/x86_64-windows/d3d11.dll"
/bin/cp "$PKG/i386-windows/d3d11.dll"   "$NEW/lib/wine/dxgi/dxmt/i386-windows/d3d11.dll"
/bin/cp "$PKG/x86_64-unix/winemetal.so" "$NEW/lib/wine/x86_64-unix/winemetal.so"
/bin/cp "$PKG/x86_64-unix/winemetal.so" "$NEW/lib/wine/dxgi/dxmt/x86_64-unix/winemetal.so"
shasum -a 256 "$NEW"/lib/wine/dxgi/dxmt/*/d3d11.dll "$NEW"/lib/wine/x86_64-unix/winemetal.so "$NEW"/lib/wine/dxgi/dxmt/x86_64-unix/winemetal.so
'
```

The runtime has two copies of winemetal.so (identical in hub-0-winemacfs-dxmtrtv);
replace both. Stop EA first. Then start it on the new runtime:
`HUB_RUNTIME=/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmttess /Volumes/ExT2/GameHub/bin/start-ea.sh`.
How to stop and start is in ~/Desktop/Wineserver-restart-GameHub.md.

## What to look for in the next game run

Hub log (/Volumes/ExT2/GameHub/Hub/Logs/ea-*.log):

- The log should start with `compatdb:   dxgi = dxmt (from /Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmttess/...)`.
- Expected: `warn:  maxtessfactor(64) is too large for a mesh pipeline. Clamping to 8`. Unchanged, harmless.
- Expected **gone**:
  - `Failed to create mesh PSO`
  - `Device error at frame … GPU Address Fault`, `InnocentVictim`, `Ignored`
  - new MTLCompilerService-*.ips reports in ~/Library/Logs/DiagnosticReports while
    playing
- If a mesh pipeline still fails: the line now reads
  `Failed to create mesh PSO (VS=xxxxxxxx GS=xxxxxxxx PS=xxxxxxxx): …`, followed by
  `retrying pipeline creation` and once `Skipping draws whose render pipeline failed to compile`.
  The game should still not freeze. Send the hashes.
- The game keeps rendering past the point where it froze. Effects drawn with geometry
  shaders are visible.
- The first time each geometry shader pipeline is used, it compiles again: the GS
  variants have new cache keys. Expect brief hitches the first time.

Game.log stops at `Registering TPS Extensions...` in every session (release build). It
shows nothing about rendering.

## Rollback

Point the launcher back at hub-0-winemacfs-dxmtrtv, which is unmodified, or remove the
clone with `rm -rf /Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmttess`.

Previous hashes:
- d3d11.dll x86_64 c00c060a3fa5dc2a839e38790c904d94be8a68917b2259e12b9ef42744af47f2
- d3d11.dll i386 87962b8699dc9c8e7d0e7155bffadbee83666726a1ff3759768d9a8bc2eede58
- winemetal.so: copy it from hub-0-winemacfs-dxmtrtv/lib/wine/x86_64-unix/

## Rebuild

```bash
bash -c 'W=/Volumes/ExT2/GameHub/work/dxmt-tess
ninja -C $W/build/x86_64 src/d3d11/d3d11.dll src/d3d11/d3d11.dll.postproc src/winemetal/unix/winemetal.so
ninja -C $W/build/i686   src/d3d11/d3d11.dll src/d3d11/d3d11.dll.postproc'
```

The x86_64 build dir uses `-Dnative_llvm_path=/Volumes/ExT2/GameHub/toolchains/llvm-15.0.7-x86_64`.
In that toolchain dir I moved the libc++/libunwind dylibs and archives to
`lib-dylibs-moved/`, so that winemetal.so links the system libc++ like the runtime's
copy. Without that move it links `@rpath/libc++.1.dylib`, which Wine cannot load.

## What remains

- The same varying gap exists for domain shader → pixel shader (tessellation mesh
  pipelines). No tessellation pipeline failed in the game; the fix would be the same
  pattern in `ShaderVariantTessellationDomain`.
- Report the compiler crash to Apple: it is a null dereference instead of a link error.
  The native repro is evidence/meshpso.m with any crashing pair from
  evidence/sweep_gs.txt.
- The event-query hypothesis for the in-game freeze (a GPU fault makes Metal ignore the
  signal commands CryEngine waits on) stays unverified; the fault no longer happens.
