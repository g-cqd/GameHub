# Developer handoff: mtld3d, x87sidecar, and Windows games on Apple Silicon

Prepared on 27 September 2026. Source revisions and local paths were checked while preparing this document. This is a description of the existing work and a proposed sequence for completing it; future phases are not claims of completed implementation.

## 1. The target

We are improving two existing open-source projects so older Windows games can run correctly, safely, and efficiently on an Apple Silicon Mac:

- **mtld3d** translates Direct3D graphics calls into Apple's Metal graphics API. Our fork now has a Rust Direct3D 8 frontend over the existing shared renderer. We want to finish Direct3D 8 and Direct3D 9 support, then extend support to older graphics APIs.
- **x87sidecar** improves the translation of legacy x86 floating-point instructions under Apple's Rosetta. We want better performance, memory efficiency, generated instruction count, security, and correctness, with broader tests and workloads.

The immediate game priority is **Call of Duty 4: Modern Warfare single-player, at maximum quality and native screen resolution**. Morrowind is the Direct3D 8 compatibility target and now plays well enough that the user asked us to move the immediate performance work to CoD4.

The order of priorities is correctness and completeness, then safety and security, then performance and resource efficiency. Reducing rendering quality, silently skipping work, or weakening arithmetic correctness does not count as a successful optimization.

There is no agreed numerical FPS target or delivery deadline. The target is a stable, responsive game at the requested quality, with improvements supported by measurements and no unexplained regressions.

## 2. The system, in beginner terms

These are separate layers with different jobs:

- **Wine** provides Windows APIs on macOS. A **Wine prefix** is a directory containing a virtual Windows installation, registry, installed components, and sometimes game saves. A prefix can contain valuable user data.
- **Rosetta** translates Intel x86 instructions so they can run on an Apple Silicon ARM processor.
- **x87** is an older x86 floating-point instruction set. x87sidecar helps Rosetta translate these instructions. It does not implement graphics APIs.
- **Direct3D 8 and Direct3D 9** are graphics APIs used by the games. mtld3d implements these interfaces and sends work to **Metal**, the host graphics API.
- A **DLL** is a Windows library. A **PE** file is a Windows executable or library. The Unix-side `mtld3d.so` is a native library loaded by Wine on macOS.
- A **shader** is a small program executed by the GPU. Creating a Metal shader pipeline may take time on first use; cached pipelines can be reused.

The graphics path is:

```text
Morrowind, using Direct3D 8
    -> our Rust d3d8.dll frontend
    -> mtld3d D3D9 objects and shared Rust core
    -> mtld3d.dll, the Windows/native bridge
    -> mtld3d.so, the Metal backend
    -> GPU

CoD4, using Direct3D 9
    -> mtld3d d3d9.dll
    -> the same bridge and Metal backend
    -> GPU
```

Alongside this, Wine and the game execute through Rosetta. x87sidecar is a separate native process that translates selected instruction sequences and returns generated ARM code through inter-process communication. Rosetta installs that code into its translation machinery. This makes buffer ownership, register state, translation boundaries, signals, and failure handling particularly important.

A crash in a game executable does not by itself establish whether the defect is in the game, Wine, mtld3d, an audio component, or x87sidecar. Keep these hypotheses separate until evidence connects them.

## 3. Where the source work lives

| Project | Local checkout | GitHub fork | Working branch | Current pushed revision |
| --- | --- | --- | --- | --- |
| mtld3d | `/Users/gc/Developer/mtld3d` | https://github.com/g-cqd/mtld3d | `main` | `5f5331a2d8762356bd49d128271c1b186c31e7ec` |
| x87sidecar | `/Users/gc/Developer/x87sidecar` | https://github.com/g-cqd/x87sidecar | `main` | `dbd680d4cbe14afa12774d53670a18758f15110e` |
| Shared engineering skills | `/Users/gc/Developer/skills` | Inspect this checkout's remote when updating | `main` | Last locally verified revision: `e99e650` |

Both code repositories were committed and synchronized with GitHub. Both working trees were clean at handoff preparation.

All g-cqd repositories now use a single `main` branch. Do not create topic branches; commit coherent changes directly to main following the repository's commit style. Previous development branches and transient branches have been consolidated and removed.

Read mtld3d's `AGENTS.md` and `CONTRIBUTING.md` first. Then read `README.md`, `docs/STATUS.md`, `docs/CONVENTIONS.md`, `docs/ARCHITECTURE.md`, and `windows/tests/COVERAGE.md`. Read `unix/conformance/CONFORMANCE.md` before changing rendering or shader behavior. These files explain existing choices that may otherwise look like accidental bugs.

For x87sidecar, start with `README.md`, `docs/internals.md`, and `docs/investigations/native-buffer-reserve.md`.

These repositories are primarily Rust and C++ with generated assembly and supporting scripts. The user's general Swift instructions apply when Swift is involved; they are not a request to rewrite these projects in Swift.

## 4. Useful source entry points

Paths in this table start with the repository directory name under `/Users/gc/Developer`. When two paths share a row, the second belongs to that same repository.

| Area | Where to start | Responsibility |
| --- | --- | --- |
| D3D8 Windows interface | `mtld3d/windows/d3d8/src/` | Factories, devices, resources, shader handles, state blocks, copies, and swap chains |
| D3D8 binary interface definitions | `mtld3d/windows/d3d8-types/src/` | COM interface layouts, method signatures, and D3D8 types |
| Pure D3D8 rules | `mtld3d/windows/core/src/d3d8/` | Declarations, shader conversion rules, state conversion, rectangle validation |
| Shared graphics logic | `mtld3d/windows/core/src/` | Capabilities, configuration, display modes, shaders, and render-pass policy |
| D3D9 implementation | `mtld3d/windows/d3d9/src/` | Windows API implementation, encoding, surfaces, presentation |
| Native graphics side | `mtld3d/unix/` | Metal operations, boundary types, and test/conformance tooling |
| Game-specific compatibility | `mtld3d/windows/core/src/app_profile.rs` | Profiles selected from game identity; settings have documented reasons |
| Graphics regression tests | `mtld3d/windows/tests/tests/d3d8/` and `windows/tests/tests/e2e/` | Behavior exercised through the Windows interfaces |
| x87 translation code | `x87sidecar/rosetta_core/` | Translation machinery and local assembler storage |
| x87 request handling | `x87sidecar/rosetta_loader/src/sidecar.cpp` | Request validation, translation, and publication back to the target |
| Rosetta discovery and hooks | `x87sidecar/rosetta_loader/src/offset_finder.cpp` and `stub_asm.cpp` | Verify native runtime assumptions and generate the hook/stub code |
| Guest address mapping | `x87sidecar/rosetta_loader/src/guest_pc_map.cpp` | Map translated execution back to guest x86 addresses for profiling |
| x87 tests and measurements | `x87sidecar/tests/`, `benchmarks/`, and `scripts/` | Correctness matrix, fault cases, profiling tools, and benchmarks |

**COM** is the Windows interface mechanism used here. Its method order, calling conventions, reference counts, and object identity are part of the contract. A wrapper that renders one scene correctly can still be wrong if it releases an object too early or reports the wrong interface.

## 5. What has been completed in mtld3d

The latest commit is `Implement Rust D3D8 support and Morrowind compatibility`.

It adds a Rust D3D8 frontend using the shared renderer, with factories, devices, textures, surfaces, cube and volume resources, vertex/index buffers, additional swap chains, shader handles, declarations, state blocks, copy operations, and tests. It also updates build/install integration and documents remaining gaps.

Important compatibility fixes from this work include:

- Morrowind startup accepts the older D3D8 SDK value used by its executable. This addressed its earlier “system description not found” startup failure.
- A Morrowind profile adds host-supported 4:3 modes for its legacy Video menu. Runtime enumeration was verified. A definitive visual confirmation of the menu itself was still outstanding in the retained report.
- D3D8 rectangle copies use the correct destination position when destination points are omitted.
- CPU writes to the backbuffer are ordered correctly with later rendering operations.
- Shared fixed-function rendering gained corrections and coverage, including MULTIPLYADD and LERP texture operations.
- Morrowind's door-transition corruption was traced to discarding backbuffer color before a frame that drew only partial interface content. Its profile now preserves that color across DISCARD presentation. Explicit color clears still replace it, and the option defaults off for other applications.

The transition fix has both a focused rendering regression test and GPU-capture evidence. The earlier capture showed tiled labels and corrupted content; the corrected capture showed retained scene pixels and the expected interface. The user confirmed that gameplay improved.

**This does not mean Direct3D 8 or Direct3D 9 is complete.** `docs/STATUS.md` remains the detailed implementation inventory. Current D3D8 gaps include tessellator declarations, N-patch levels above one, an actual CPU vertex-processing implementation, exact native-driver Z-bias behavior, and parts of additional-swap-chain presentation such as multiple windows and presentation rectangles/dirty regions.

D3D9 still has documented gaps and deliberate divergences. Examples include D3D9Ex, fixed-function bump-environment mapping, several query types, color render-target feedback hazards, and some resource-copy/format combinations. The original project's exclusions must be reconciled explicitly with this fork's broader completion goal. Do not silently redefine “complete” to mean only that these two games launch.

## 6. What has been completed in x87sidecar

Recent work concentrated on correctness and safe storage management before further optimization:

- Bound assembler storage growth and release buffers owned by the local implementation.
- Validate request metadata and resource sizes before allocating translation storage.
- Invalidate cached register state whenever translation falls back to stock Rosetta.
- Reserve insufficient native output capacity through verified native allocator functions, on the requesting parent thread, then retry the original translation once.
- Check the native allocator's caller and locking assumptions against the installed runtime. Changed runtime code requires another audit; guessed addresses are not accepted.
- Distinguish safe stock fallback from cases that require an explicit fatal result. In particular, synthetic ARPL has no usable stock implementation, so silently falling back would be incorrect.
- Add native transaction, generated-stub, allocation-failure, and runtime-discovery regressions, with sanitizer coverage.

The most detailed explanation is `docs/investigations/native-buffer-reserve.md`. It distinguishes our locally owned buffers from Rosetta's native arena ownership and documents the thread-safety assumptions.

The completed matrix reported **1,026 passing checks, zero failures, and two known stock-Rosetta divergences, out of 1,028 total**. Relevant native tests also passed AddressSanitizer and UndefinedBehaviorSanitizer checks.

The reserve work did not establish a speedup for requests that already fit. Its recorded timings overlapped, and fitting-path allocation traffic was unchanged. The remaining temporary allocation is a concrete optimization candidate, but an allocation reuse change must preserve ownership, bounds, and failure behavior. Reserve/retry intentionally adds work when storage is insufficient; it prevents unsafe handling of growth.

## 7. Game installations, runtimes, and evidence

Source code, installed binaries, game data, and Wine prefixes are different things. A successful source build does not automatically update a game. A running game may use an older retained renderer snapshot. Always record which binary actually loaded.

### CoD4: current performance priority

- Game directory: `/Users/gc/Games/CoD4`
- Normal launcher: `/Users/gc/Games/CoD4-tools/Play_CoD4.command`
- Private runtime: `/Users/gc/Games/CoD4-tools/wine`
- Persistent prefix: `/Users/gc/Games/CoD4-tools/prefix`
- Installed sidecar: `/Users/gc/Games/CoD4-tools/x87sidecar`
- Current configuration/deployment report: `/Users/gc/Games/CoD4-tools/diagnostics/maximum-quality-20260927/RESULT.md`
- Deployment receipt and rollback data: the same directory, especially `deployment.json` and `rollback/`
- Benchmark copy and retained automation: `/Users/gc/Games/CoD4-tools/benchmark`
- Production source snapshot, artifact hashes, and test logs: `/Users/gc/Games/CoD4-tools/performance-20260927-U9gG37`

The requested native resolution on the current Mac is the physical panel's **2560 × 1600**, not the larger scaled desktop dimensions. The installed Gigi profile is configured for fullscreen, Retina mode, 4× MSAA, supersampled alpha anti-aliasing, 16× anisotropic filtering, Extra textures, and maximum installed shadow/effect/model settings. Render scale is 1.

Shader compilation is synchronous for this setup so first-use pipelines do not omit draws. The tradeoff is possible first-use pauses; compiled pipelines remain cached. Normal launches disable renderer performance telemetry by default. x87sidecar is enabled by default; the launcher supports `COD4_X87=0` for an explicitly needed comparison.

The production renderer files installed for this setup were checked against the tested artifacts. The user's cargo-ship progress from the diagnostic session was restored to Gigi, with the earlier profile backed up.

Nine accepted training-checkpoint samples recorded these results:

| Setup | Accepted samples | Median FPS | Range of run FPS | Median frame time |
| --- | --- | --- | --- | --- |
| x87sidecar enabled | 5 | 146.1 | 140.9–147.6 | 6.86 ms |
| x87sidecar disabled | 4 | 79.2 | 68.7–80.3 | 12.72 ms |

These are observed results for the recorded, instrumented, windowed checkpoint. The report records configuration, runtime hashes, timing conditions, and limits. They are not a whole-campaign FPS guarantee or per-frame percentile measurements. A tenth run lost focus and was excluded.

The native single-player demo replay fixture crashes at game address `0x0043d8f2`, reading a null pointer, with x87 both enabled and disabled. Its demo and logs were retained; it was excluded from performance timing. This is separate from a normal gameplay result and is not proof of an x87 defect.

**The user explicitly stopped repetitive benchmarking and does not want to play the same route repeatedly.** No more runs are scheduled. Use the existing measurements, logs, tests, and source first. Do not turn onboarding into another manual replay request. The final normal fullscreen setup was not relaunched after that instruction.

### Morrowind: preserve the working D3D8 target

- Normal launcher: `/Users/gc/Games/Morrowind-tools/Play_Morrowind.command`
- Runtime: `/Users/gc/Games/Morrowind-tools/wine`
- Persistent prefix and installed game: `/Users/gc/Games/Morrowind-tools/prefix/drive_c/Morrowind`
- Convenience game path: `/Users/gc/Games/Morrowind`
- Corrected renderer snapshot: `/Users/gc/Games/Morrowind-tools/renderer-snapshots/20260926T233403Z`
- Corrected door-capture report: `/Users/gc/Games/Morrowind-tools/diagnostics/door-preserved-x7pqc4xm/RESULT.md`
- Later exit-crash evidence: `/Users/gc/Games/Morrowind-tools/diagnostics/morrowind-92844-exit-fault`

The current recorded setup uses 1680 × 1050 fullscreen, pixel-shader water, six shadows, and the original game's maximum render distance. Music works through LAVFilters installed in this prefix. HDR remains off from the transition comparison. Do not describe Morrowind as already verified at native Retina resolution or maximum HDR output.

The user reported that Morrowind now works well. A separate intermittent **exit-time crash** remains unresolved. One report involved Wine heap freeing; another faulted at `0x004b676d` while making an indirect call through an invalid pointer. Neither establishes the original cause of corruption. This investigation was deferred when the user prioritized CoD4. Do not re-enable expensive heap diagnostics during normal play.

Temporary profiling/test runtimes created during the work were retired after retaining useful evidence. Persistent game prefixes, user profiles, and saved games are not temporary files and must not be deleted as cleanup.

## 8. Coordination with the other worker

The shared communication directory is `/Users/gc/Desktop/The_Board`.

Our existing log is `mtld3d-x87-root-20260926.jsonl`. The other worker's log is `nfs2015-ea-debugger-171bd1d8.jsonl`. A JSONL file contains one JSON message per line. Read recent entries before starting work that could interfere with another runtime or consume substantial CPU/GPU time.

A new developer should introduce themselves in a new, clearly owned log file, listing their paths, task, and questions. Append to their own file; do not rewrite another worker's log or impose a new directory structure. Include timestamps and distinguish questions, observations, and confirmed results.

The other worker owns NFS/EA diagnostics and a separate macOS packaging project at `/Users/gc/Games/NFSMW-tools/macos-app`, with outputs under `/Users/gc/Desktop/Game Builds`. Its repository is `g-cqd/nfs-macos`. The latest board entry reviewed here names branch `refresh-runtimes-cod4-bundle` and fix `b3b3427`. Those are board-reported facts, not a fresh audit of that repository.

That worker is packaging NFS Most Wanted 2005 and CoD4 using the tested mtld3d/x87 revisions. They reported a CoD4 bundle `fileSysCheck` startup problem caused by Wine falling back to `C:\windows` when the game's working directory was outside the mapped C drive. They implemented a temporary game-only G-drive mapping with cleanup; gameplay retest was pending in that entry. This packaging problem is separate from the demo replay crash above.

**NFS 2015 is paused according to the latest board update.** Earlier it exited with `-6` before creating a window. No x87 arithmetic fault was established. Preserving Wine debug-register values and delivering execution breakpoints were separate diagnostic issues. A later private Wine 11.18 diagnostic fix reportedly passed both 7/7 execution-breakpoint fixtures after repairing a trap-handler return path. That result did not establish the cause of NFS's startup exit and was not installed into our game runtimes.

The original shared breakpoint probes are under `/Users/gc/Games/NFSMW-tools/diagnostics/nfs2015-context/`. Rosetta address mapping may help diagnosis, but mapping an address is not sufficient to deliver reliable breakpoints. Translation invalidation, exception delivery, thread state, and concurrency require separate proofs.

The packaging worker also reports that temporal upscaling/frame generation was deferred outside their current bundle release. The renderer currently provides spatial upscaling. Do not add temporal rendering work to the immediate CoD4 optimization task by assumption.

## 9. Roadmap and concrete completion criteria

The sequence below preserves the user's priorities. It is not a commitment to fixed dates.

### Phase 1: Establish a safe development starting point

Read the repository rules and this handoff, verify the current branch/revision, read the board, and choose a private test environment. Inventory the existing CoD4 evidence before running anything new.

Completion: the developer can explain which component owns a proposed change, identify the loaded runtime and its source revision, locate the saves and rollback data, and run a focused repository test without touching another worker's game runtime.

### Phase 2: Improve CoD4 performance at the fixed quality target

Use existing profiles and frame reports to select one demonstrated cost: game CPU work, x87 translation/execution, API overhead, shader compilation, synchronization, uploads, or GPU work. Make one scoped change in the component responsible. Keep 2560 × 1600, render scale 1, and the documented quality settings.

Completion for each optimization: a before/after comparison for the changed operation or workload, matching output/quality, relevant correctness tests, no skipped draws, and a clear statement of CPU, GPU, memory, or latency effects. Do not claim campaign-wide gains from a microbenchmark. Further game measurements must respect the user's stop instruction and avoid repetitive manual play.

Keep bundle startup/input problems coordinated with the packaging owner. Do not mix unrelated launcher fixes into renderer changes.

### Phase 3: Continue x87 safety and efficiency work

Use the existing correctness matrix and broaden it with justified workloads and failure cases. Candidate work includes reducing per-request temporary allocation, measuring translation latency and emitted instruction counts, and reducing copies or instruction sequences where profiling supports it.

Completion for each change: stock-versus-sidecar behavioral checks, valid fallback behavior, allocation-failure and malformed-input coverage, relevant signal/concurrency tests, sanitizer checks for changed native code, and measured resource effects. Do not weaken floating-point behavior or runtime verification to obtain a faster result.

### Phase 4: Close D3D8 gaps and preserve Morrowind

Use `docs/STATUS.md` to select one missing or incorrect D3D8 contract at a time. Cover API results, object lifetime, state restoration, and rendered output where applicable. Preserve the fixed transition behavior and the existing game setup.

Completion for each API slice: implementation, regression tests, capability/error behavior consistent with the implementation, updated documentation, and both supported Windows test architectures passing. Resume the separate Morrowind exit-crash investigation as a scoped bug task when prioritized; it is not already fixed.

### Phase 5: Complete the agreed D3D9 surface

Turn the remaining STATUS entries into explicit, independently testable work items. Resolve the difference between the fork's completion objective and upstream's deliberate exclusions. Prioritize safety hazards and contracts required by target games, then remaining compatibility work such as queries, fixed-function operations, copy semantics, and D3D9Ex as appropriate.

A known follow-up worth reviewing is oversized nonzero vertex/index-buffer lock requests: `windows/d3d9/src/vertex_buffer.rs` around line 645 and `index_buffer.rs` around line 530 currently warn about clamping rather than rejecting the request. The returned writable pointer can leave the caller expecting a larger writable range than exists. This is not a proven cause of Morrowind's exit crash. Start with a precise boundary regression before changing behavior.

Completion: every item in the agreed D3D9 scope is implemented and tested or explicitly recorded as an accepted exclusion. A clean test run alone is not proof of complete API coverage.

### Phase 6: Add APIs older than D3D8

The user chose D3D8 and D3D9 first, followed by older APIs. No implementation for earlier Direct3D or DirectDraw is claimed here. Inventory candidate APIs and choose the next concrete application/API contract before implementing another frontend over shared functionality.

Completion for each older API phase: an agreed target application, an explicit compatibility scope, a working frontend, contract tests, and a demonstrated game/application outcome. Do not attempt every older API at once.

## 10. Build and verification workflow

Do not copy an old environment blindly. `WINE_SDK` must point to a compatible SDK, and Wine prefixes/runtimes must have clear ownership. A game runtime is not automatically a development SDK. Historical temporary paths may already have been cleaned up.

For mtld3d, after establishing the owned SDK/prefix and toolchain environment described by its Makefile and contributing guide:

```sh
cd /Users/gc/Developer/mtld3d
git status --short --branch
make check ISOLATED=1
make test ISOLATED=1
```

`make check` covers formatting, Clippy, the repository audit, and documentation. `make test` covers host tests and both Windows PE architectures. Rendering or shader changes also need the relevant conformance comparison; that suite has a documented baseline and does not expect every native-Windows behavior to pass identically.

**Test/install commands write renderer binaries into the Wine tree they target.** The isolated mode exists to avoid overwriting shared installations. It creates a reusable environment under `.wine-isolated/`; it does not make simultaneous use of that same environment by multiple developers safe. Coordinate access or use a separately owned environment.

The latest mtld3d source matched the recorded 535-file source-hash manifest. Recorded checks passed, with **2,227 host tests** and **923 passing tests plus 11 intentionally ignored benchmarks per Windows architecture**. The exact production i686 artifacts installed for CoD4 also passed 923 tests with zero failures. Existing conformance reports contain baseline/environment differences; do not present the whole conformance suite as zero-failure.

For x87sidecar, the repository documents these commands:

```sh
cd /Users/gc/Developer/x87sidecar
cmake -B build
cmake --build build
build/bin/x87sidecar --probe
bash scripts/run_tests.sh --no-build
```

The probe checks compatibility with the installed Rosetta runtime. Full attachment tests have the entitlement/authorization requirements documented in the README. Native storage and request tests such as `test_assembler_buffer` and `test_sidecar_transaction` provide smaller entry points; do not equate them with the complete matrix.

Use permanent tests for changed behavior. Prefer a failing regression first, then the fix, then the relevant suite. Record commands, revisions, configurations, binary hashes where needed, test counts, and known exceptions. A build succeeding is different from a game working, and a game working is different from an API being complete.

## 11. Working agreements

- Preserve user saves and settings. Back up before deployment and retain a usable rollback.
- Keep diagnostic prefixes and artifacts in clearly owned paths. Clean temporary files and processes created by your work when finished; preserve evidence needed to understand a result.
- Never stop all Wine processes to clean up one test. Stop only the runtime/prefix/processes you own after checking ownership.
- Do not overwrite live renderer libraries under a running game or another worker's test.
- All work goes to the single `main` branch. Commit coherent changes with explicit titles and push authorized work. Do not force-push or rewrite history.
- Use existing tests and benchmarks, broadening coverage where it tests a real missing behavior. Avoid redundant benchmark runs or asking the user to repeat a route.
- Treat performance claims as measurements with conditions. Keep first-use shader compilation, warm steady-state performance, and loading time separate.
- Use the skills repository for debugging, graphics, performance engineering, memory safety, secure coding, testing, review, and delivery guidance. Its installed skills are under `/Users/gc/.agent-harness/skills`. Check the current catalog when selecting them.
- If using AI assistance, the user permits at most **one GPT-6 Astra request per hour**, reserved for genuinely difficult reasoning. Check coordination before spending it. Ordinary source reading and documentation do not need that model.
- Ask only when a missing decision materially changes the work. Routine reversible decisions should not become approval loops.

## 12. A suitable first assignment for the new developer

Read the CoD4 result report and mtld3d's architecture and status documents. Trace one operation from a D3D8 or D3D9 entry point into shared logic and its existing regression test. Run that focused test in an owned environment and explain what it proves.

Then select one bounded missing behavior with an experienced reviewer. Write its failing boundary or rendering test, implement the smallest correction, and run the relevant gates. Native Rosetta allocator/hook changes should receive experienced review because an incorrect assumption can corrupt another process or break signal handling.

The immediate target is better CoD4 performance at unchanged maximum quality, while preserving the working Morrowind setup. The longer-term target remains complete agreed D3D8/D3D9 support, safer and more efficient x87 translation, and then older APIs. Current game success and passing tests are progress toward that target, not a declaration that the overall project is finished.
