# DXMT: Crysis 3 in-game hang after "Failed to create mesh PSO" (M2 Pro)

## Summary

On M1/M2 GPUs (AGX G14X), Apple's shader compiler service (MTLCompilerService) crashes
on a VS+GS mesh pipeline whose pixel shader reads a varying the geometry shader does
not write. DXMT logs `Failed to create mesh PSO: ... XPC_ERROR_CONNECTION_INTERRUPTED`.
Three DXMT defects turn that compile failure into a broken game:

1. **The draw still runs.** It runs with the previously bound pipeline and its unrelated
   bindings. Only the set-pipeline command was skipped
   (`src/d3d11/d3d11_context_impl.cpp`, `if (!GraphicsPipeline.PipelineState) return;`
   in all three Finalize*RenderPipeline lambdas). The draw lambdas never checked.
2. **The NSError is released twice.** Metal returns errors autoreleased (+0), but the
   `src/winemetal/Metal.hpp` wrappers stored them in the caller's `Reference<Error>`,
   which releases them. The thread crashes when its autorelease pool drains. Pipeline
   compile threads drain when they exit, so process teardown hangs.
3. **Valid pipelines fail as collateral.** A pipeline compiling while the service
   crashes fails with the same XPC error even if it is valid.

The tessellation clamp warning (`maxtessfactor(64) ... Clamping to 8`) is unrelated.
That clamp is deliberate for GPUs below Apple9, and no tessellation pipeline failed in
the session log. Both failing pipelines were geometry-shader pipelines: the string
`Failed to create mesh PSO: <NSError>` exists only in `d3d11_pipeline_gs.cpp`.

## Fix (3 commits on 1c9e911, which is the current gcqd/development)

| Commit | What |
|---|---|
| cbf3c18 fix(winemetal): retain autoreleased errors returned to Reference<Error> | `AdoptAutoreleasedError`. All 11 wrappers take `Reference<Error> &` and retain. |
| cb535b3 fix(d3d11): drop draws whose render pipeline failed to compile | `RenderEncoderData::pipeline_failed`, `TrackRenderPipelineState`, `EmitDrawOP` on all 14 draw paths. Logs a one-time warning. Mesh PSO errors name the shaders. Adds test `tests/dx11/dx11_failed_pipeline.cpp` and fixes the unquoted `dx11_staging_rename` entry in `tests/dx11/meson.build`. |
| 8bad5a1 fix(d3d11): retry pipelines whose compile lost the compiler service | `NewRenderPipelineStateRetryingInterrupted`: up to 2 retries, only on `XPC_ERROR_CONNECTION_INTERRUPTED`. Used for ordinary, GS and TS pipelines. |

The worktree is detached at /Volumes/ExT2/GameHub/work/dxmt-tess/src-wt (HEAD 8bad5a1).
Nothing is pushed. The `000*.patch` files here apply with `git am` onto 1c9e911.

What the fix does **not** do: the effect drawn by the crashing pipeline is still missing.
It is skipped instead of hanging the game. Rendering it needs a converter change in
airconv (inside winemetal.so). That change emits zero for the varyings the pixel shader
reads but the geometry shader does not write. It needs LLVM 15, which is not installed;
see "What remains".

## Files

| Path | What |
|---|---|
| i386-windows/d3d11.dll, x86_64-windows/d3d11.dll | patched DXMT d3d11 (Wine-builtin marked). They contain 214562d + 1c9e911 + these fixes. |
| 0001..0003-*.patch | the commits |
| test/dx11_failed_pipeline.cpp, test/failed_pipeline_test-{i686,x86_64}.exe | regression test |
| test/run_test.sh | runs it in the throwaway prefix (`run_test.sh RUNTIME ARCH LOG [vs\|gs\|all\|control] [idle_ms]`) |
| test/before-*.log, after-*.log, exp-*.log, flake/, prior/ | results, below |
| test/before-i686-hang.sample.txt | `sample` of the hung stock test. One thread is in `_sigtramp` from `objc_autoreleasePoolPop` during `pthread_exit`. |
| evidence/ | native Metal harnesses (meshpso.m, stalepso.m, faultsignal.m), the 2115-pipeline sweep, the correlation script, and a compiler crash report with the same stack as the game's |
| build/cross-*.txt | meson cross files (llvm-mingw 20261006) |
| SHA256SUMS | checksums |

Only d3d11.dll changes. Metal.hpp is compiled into d3d11.dll and is header-only on the
PE side. winemetal.dll/.so, dxgi.dll and d3d10*.dll stay as they are in the runtime.

## Evidence

**Compiler crash (measured).** The four MTLCompilerService crash reports of 20:32:38-39
(responsible process Crysis3.exe) all SIGSEGV at a null `llvm::Value` in
`llvm::BinaryOperator::Create` ← `AGCLLVMUserMeshShaderSW::getBasePointer(…, VaryingType, …)`
← `MeshShaderSWAuxiliaryShadersPass::run` ← `AGCModule<AGX::Impl::MeshProgramKey>::compileLLVMObject`.
That is the software mesh-shader path of G14X, failing while it lays out mesh→fragment
varyings. macOS has since rotated those reports out. The two gpuEvent reports
(BIF0 page fault, reads at 0x97d000a940 and 0x556b2e2c00) are gone too.

**Crash trigger (measured, native, no Wine).** I extracted the game's 736 converted
shaders from DXMT's shader cache
(`$(getconf DARWIN_USER_CACHE_DIR)dxmt/Crysis3.exe/shaders_320.db`, copy in
evidence/cache-snapshot). Then I built the mesh PSOs the way `d3d11_pipeline_gs.cpp` does,
for 5 object (vsgs_*) × 5 mesh (gs_*) functions with every one of the 423 pixel shaders.

- Without a fragment function, all 25 object/mesh pairs compile.
- With a fragment function: 344 compiler crashes, with the exact game error. **All 344**
  have a pixel shader reading a `user(regN_C)` varying the mesh function does not output.
  **0 of 1692** pairs whose varyings all link crashed. (53 mismatched pairs compiled
  anyway, so the compiler bug is necessary-but-not-sufficient.)

I could not identify the game's exact pair, because the game's shader paks are
encrypted. The patched DLL now logs `Failed to create mesh PSO (VS=xxxxxxxx GS=xxxxxxxx PS=xxxxxxxx)`.

**Stale-pipeline draw (measured).** `dx11_failed_pipeline` draws a valid red pipeline on
the left half and an unlinkable one on the right half of one render pass.

- Stock 1c9e911: the right half is **red** in vs and gs mode on i686 and x86_64. The
  failed draw ran with the previous pipeline.
- Patched: the right half stays black.
- gs mode reproduces the in-game error string exactly. The test's compiler crash
  report has the same stack as the game's.

**GPU page fault (inferred).** In the test the stale pipeline matches the failed one's
layout, so the GPU does not fault. In the game the stale pipeline is some other mesh
pipeline, and its functions read the GS draw's argument tables (object/mesh buffers
21/29/30) with a different layout. That fits the read page faults in TA/3D.
Experiments:
- A mesh draw with an ordinary vertex PSO bound did not fault (stalepso.m).
- I could not induce a GPU page fault natively (faultsignal.m).

**Hang (inferred, two candidates).**
- (a) After the page fault, Metal ignores the queue's command buffers
  (`Code=4 Ignored`). D3D11 event queries and fences complete through
  `encodeSignalEvent` in those buffers. CryEngine waits on event queries, so it would
  spin, which matches the 200% CPU.
- (b) The over-released NSError crashes a compile thread when it exits (measured in
  the test: the hang is in device release).

The session log is not "endless". Each session stops about 3 frames after the first
fault (frames 23166 and 2324), which is consistent with (a).

**Collateral failures (measured).** In "all" mode the valid GS pipeline failed too in 2
of 7 x86_64 runs without the retry. With the retry it failed in 0 of 10 runs (5 per
arch); the retries hit only the crashing pipeline.

## Test results

| Run | Stock 1c9e911 (runtime clone) | Patched |
|---|---|---|
| i686 vs | FAIL (right half red), **hang** in device release (killed at 120 s) | PASS, exit 0 |
| i686 gs | FAIL (red), compiler crash, hang | PASS, exit 0 |
| x86_64 vs / gs | FAIL (red), hang | PASS, exit 0 (all mode: 5/5 with retry) |
| i686/x86_64 control (pipelines that link) | PASS, exit 0 | PASS, exit 0 |
| draw-skip fix only, i686 vs | - | right half black, but **hang** (attributes the hang to the NSError over-release) |
| rtv_buffer_test, staging_rename_test (previous packages), both arches | - | PASS, exit 0 |

The GPU liveness check (clear and read back, before and after a 15 s idle) passed in
all runs.

## Install (into a runtime clone, never in place)

```bash
bash -c '
set -euo pipefail
PKG=/Volumes/ExT2/GameHub/work/dxmt-tess/20261011-2217
SRC=/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv   # live runtime; left untouched
NEW=/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmttess  # pick a new name
(cd "$PKG" && shasum -a 256 -c SHA256SUMS)
test ! -e "$NEW"
/bin/cp -c -R -p "$SRC" "$NEW"
/bin/cp "$PKG/x86_64-windows/d3d11.dll" "$NEW/lib/wine/dxgi/dxmt/x86_64-windows/d3d11.dll"
/bin/cp "$PKG/i386-windows/d3d11.dll"   "$NEW/lib/wine/dxgi/dxmt/i386-windows/d3d11.dll"
shasum -a 256 "$NEW"/lib/wine/dxgi/dxmt/*/d3d11.dll
'
```

Point the EA/Crysis 3 launch at `$NEW/bin/wine`, the same way the dxmtrtv runtime is
selected now. The log then shows
`compatdb:   dxgi = dxmt (from /Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmttess/...)`.

## What to look for in the next game run

Hub log (/Volumes/ExT2/GameHub/Hub/Logs/ea-*.log):

- Expected, harmless:
  - `warn:  maxtessfactor(64) is too large for a mesh pipeline. Clamping to 8`
  - `err:   Failed to create mesh PSO (VS=........ GS=........ PS=........): ... XPC_ERROR_CONNECTION_INTERRUPTED ...`
    (report these hashes: they name the crashing combination)
  - `warn:  Metal compiler service connection interrupted, retrying pipeline creation (1/2)` and `(2/2)`
  - once: `warn:  Skipping draws whose render pipeline failed to compile (see the error above)`
- Must **not** appear any more: `Device error at frame N: ... Caused GPU Address Fault`,
  `... InnocentVictim`, `... Ignored (for causing prior/excessive GPU errors)`.
- The game keeps rendering past the point where it froze. At most one effect
  (whatever that geometry shader draws) is missing.
- New MTLCompilerService-*.ips reports in ~/Library/Logs/DiagnosticReports are still
  expected; that is Apple's crash, now contained.

Game.log (/Volumes/ExT2/GameHub/EA Games/Crysis 3/Game.log) is a release-build log that
stops at `Registering TPS Extensions...` in every session, including successful loads.
It carries no rendering information here.

## Rollback

Point the launcher back at hub-0-winemacfs-dxmtrtv, which is not modified. Its DLLs are
1c9e911: x86_64 c00c060a3fa5dc2a839e38790c904d94be8a68917b2259e12b9ef42744af47f2, i386
87962b8699dc9c8e7d0e7155bffadbee83666726a1ff3759768d9a8bc2eede58. Remove the clone with
`rm -rf /Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmttess`.

## Rebuild

```bash
bash -c 'W=/Volumes/ExT2/GameHub/work/dxmt-tess
for t in x86_64 i686; do ninja -C $W/build/$t src/d3d11/d3d11.dll src/d3d11/d3d11.dll.postproc; done'
```

Configured with meson from src-wt and the cross files in build/:
`-Dbuildtype=release -Dwine_install_path=/Volumes/ExT2/GameHub/toolchains/wine-sdk-cx-26.3.0-5/wine -Dnative_llvm_path=/opt/homebrew/opt/llvm -Denable_tests=true`.
The test exe: `i686-w64-mingw32-clang++ -O2 -static -Wl,--large-address-aware dx11_failed_pipeline.cpp -ld3d11 -ld3dcompiler_47`
(x86_64: the same without the linker flag).

## Crysis 3 config

Not changed. No cvar is tied to the failing path. The tessellation cvars
(`r_Tessellation`, `r_ParticlesTessellation`, `r_ParticlesTessellationTriSize`) govern
hull/domain pipelines, which compiled fine. I found no documented Crysis 3 cvar for the
geometry-shader draws (`r_UseGSParticles` is Crysis 1/DX10). No dxmt.conf switch was
added for the same reason: a tessellation switch would not touch the failing path.

## What remains

- **Render the effect** (airconv, winemetal.so). Pass the pixel shader input signature
  into the GS variant (`ShaderVariantGeometry`), and emit every user varying it reads:
  the GS register value if the GS writes that register, else zero, which is undefined
  in D3D. The same applies to DS→PS. This needs a winemetal.so build against LLVM 15
  (CI pins llvmorg-15.0.7). Report the Apple compiler crash too: a null deref instead of
  a link error. The repro is evidence/meshpso.m with any crashing pair from
  evidence/sweep_gs.txt.
- Compute dispatches still run with a stale compute pipeline when theirs fails to
  compile (`d3d11_context_impl.cpp` Dispatch*). That is the same pattern; no evidence
  that the game hits it.
- A wineserver of the live runtime hub-0-winemacfs-dxmtrtv (pid 20193) was running
  when I checked at 22:2x, started about 20:20. It is probably left over from the hung
  session. It is not mine and I did not touch it.

> Superseded by ../20261011-2246 (adds the converter fix in winemetal.so and the compute fix).
