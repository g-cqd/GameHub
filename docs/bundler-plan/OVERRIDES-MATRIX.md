# Overrides matrix: every override and workaround, per game and per layer

Read-only investigation, 2026-10-09. Path prefixes: `G/` = `/Users/gc/Developer/Games/`, `D/` = `/Users/gc/Developer/`,
`APP/` = `G/nfs-release/macos-app/` (recipe system, branch `bf4-recipe-schema`), `MW/` = `G/NFSMW-tools/macos-app/`,
`FC/` = `G/FarCry2-tools/macos-app/`, `BF3B/` = the BF3 tuned bundle `Battlefield3-Tuned-20261009/`. **Note:** BF3B was read at
`G/bf4-bundle-stage/` early in this survey; another worker removed that local stage during the survey (its `clean_prefix.py` now sits at
`G/bf4-run/bundle-tools/`); the bundle now exists only at `mbp23.local:/Volumes/ExT2/Bundles/Battlefield3-Tuned-20261009`.
A Sonnet review checked 34 rows against the sources (about 85% correct); its corrections are applied below.

Columns: **X** = cross-game reusable (the bundler's knowledge layer should own it, not a game recipe).
**Status**: `verified` (observed in a run, log, test or by the owner), `code` (present in source/config, effect not re-observed),
`unverified`, `rejected`. Statuses are taken from the cited source, not re-tested here (no games were run).
Layers: runtime, prefix-reg (prefix registry), dll-ovr (DLL override), env, compat (WINE_COMPATDB renderer rule),
game-file (file put in the game folder), settings (game settings file), launch (launch method), client (EA/Steam layer handling),
bundle (packaging/process rule).

## 1. Runtime layer (Wine fork g-cqd/wine, runtimes wine-0005..0011)

Base: athei/wine `1a7b0c76` (tag `athei-cx-26-patched-1a7b0c76` on g-cqd/wine) + patches. Patch files: `/Users/gc/Documents/NFS-backups/wine-patches/0001..0011*.patch`.
All 11 patches are on GitHub g-cqd/wine (patch-id verified by a Sonnet check): branches `nfs2015-runtime-0005/0010/0011`, tags `nfs2015-runtime-000N-20261008`.

| X | Game | Layer | Override (exact) | Why (symptom + root cause) | Evidence | Status | Lives now |
|---|---|---|---|---|---|---|---|
| X | NFS 2015 (any game with debug-register anti-tamper) | runtime | patches 0001-0004: Rosetta debug-register state + trap-flag (TF) execution-breakpoint emulation; budgets; PUSHF/POPF prefix decode; fixture | NFS16.exe self-terminates / respawn loop: the protection arms a hardware execution breakpoint that Rosetta never delivers | `APP/docs/NFS2015.md` §3.2; `G/wine-rebuild/HANDOFF.md`; GH commits 58ce112, 73e31fa, 930d0d3, c810543 | verified (game passes the check; fixture) | g-cqd/wine, wine-patches, runtime wine-0005+ |
| X | NFS 2015 | env | `WINE_TF_EMULATION=1`, `WINE_TF_MAX_STEPS=0`, `WINE_TF_MAX_NS=0` | a step/time budget stops the emulation instead of the game | `APP/Packaging/Recipes/nfs2015.json:21-25` (`runtimeTuning`); NFS2015.md §5 | verified | recipe `runtimeTuning`; Swift `RuntimeTuning.swift:12`; `recipes.py:207` (duplicated in 4 places) |
| X | NFS 2015 | runtime | 0005-0007: kernelbase crash-context snapshot, code windows/page history, exec-page toggles + page trace | diagnostics for the `rip=0x1B30159` fault | HANDOFF.md §10-14 | verified as diagnostics; toggles "not the cause" (HANDOFF.md:338) | g-cqd/wine |
| X | NFS 2015 | env | `WINE_ROSETTA_FLUSH_TOGGLE`, `WINE_ROSETTA_PROTECT_TOGGLE`, `WINE_TRACE_PAGE` off | experiments, nothing showed they help | `APP/Sources/.../NFS2015WineExperiments.swift:18-25` | rejected (kept as switches) | Swift app |
| X | NFS 2015 (any self-modifying-code game) | runtime + env | 0008-0010: optional W^X emulation for RWX pages, TF leak/straddling stores, self-modifying pages; `WINE_RWX_WX_EMULATION=1`, `WINE_RWX_WX_HOT_LIMIT` (4096/s), `WINE_RWX_WX_NEAR_LIMIT`, `WINE_RWX_WX_TF_RELEASE`, `WINE_RWX_WX_LOG` | NFS16 faults at `rip=0x1B30159`: Rosetta resumes one byte late after self-modifying code (HANDOFF.md:301) | patches 0008-0010; `NFS2015WineExperiments.swift:6-12` | verified on test programs; default ON in the -0009/-0010 apps; BF3/BF4 keep it OFF (`BF_RWX`, `BF4_RWX`) | g-cqd/wine; Swift app; `G/bf4-run/env.sh:20-21` |
| X | RoN, BF3, (all dsound games) | runtime | 0011: dsound SSE2 resampler + mixer phase cache (no env knob) | dsound mixer burned ~1.05 cores under Rosetta (RoN menu: 1.05 -> median 0.369 with SSE2 + phase cache, 0.254 with the sidecar too; SSE2-only variants noisy 0.326-0.881) | `G/ron-tools/PERF.md:6-10,31`; HANDOFF.md:418; GH 71133b5 | measured at idle only; not listened to; **not pinned in any shipped recipe** (runtime-inputs.json stops at 0010) | g-cqd/wine `nfs2015-runtime-0011`; `G/wine-rebuild/runtime/wine-0011`; BF3B runtime (dsound files only, `BF3B/DIFF-vs-wine-0010.txt`) |
| X | BF3 | dll-ovr | wine-0011 `dsound.dll` copied into the game folder / native override | supposed to load the faster mixer | `G/bf4-run/bf3/NOTES.md:70` | **rejected**: not mapped; wine-0010 builtin dsound kept loading. Fix used instead: replace the two dsound DLLs inside the runtime (BF3B README) | BF3B/runtime |
| X | all | runtime | known open bug: 32-bit wined3d/DXGI/D3D10 path faults reading `0x00005dc9` at `ntdll+0x1123d` | any 32-bit DXGI user in this runtime | NFS2015.md §9 | verified bug, **not fixed**; worked around per app (IGOProxy32 disabled) | knowledge only |
| X | all | runtime | durable fix would be ARM64 hardware breakpoints (`ARM_DEBUG_STATE64` unimplemented in `server/mach.c`, `signal_arm64.c`) | TF emulation is slow; protection timing checks may fail | NFS2015.md §9 | open | knowledge only |
| X | NFSMW | runtime | `winemac.so` cursor-activation patch | macOS arrow cursor returns in game | `G/NFSMW-tools/TASK-NOTES.md:91` | verified (standalone tests) | runtime `nfsmw-cursor` profile (`runtime-inputs.json:29`) |
| X | all | runtime | `compatdb.so` (Rust) renderer rules engine + built-in rules (`builtin.rs`) | per-exe dxgi/d3d9 backend choice | HANDOFF.md (Rust 1.97.1 for compatdb.so) | code | runtime |
| X | RoN Steam client | compat | built-in rule forces `dxgi=gptk` for steamwebhelper; fix = alias/override to `dxmt` | Steam client Chromium crashes; with dxmt the login window renders | `G/ron-tools/FULL-REQUIREMENTS.md:70-73` | prototype verified in a scratch runtime; source fix not done | knowledge only (`G/ron-tools/full/runtime-scratch`) |
| X | experiment | runtime | `wx-experiment` branch 44974bf ("EXPERIMENT (not for delivery)") | W^X variant | `G/wine-rebuild/src/wine` | rejected/experimental; **local-only** | `G/wine-rebuild/src/wine` only |
| X | all (arm64-native route) | runtime | wine-arm64: native arm64 Wine + WoW64 (`r3wow64.dll` x86 CPU), "no x87sidecar lookup on arm64" | alternative to Rosetta-hosted Wine | `D/wine-arm64/docs/BRINGUP.md`; `D/wine-arm64/src` 98 commits | experimental; **local-only, no remote** | `D/wine-arm64` |

## 2. Renderer layer (DXMT, mtld3d, wined3d, D3DMetal)

| X | Game | Layer | Override (exact) | Why | Evidence | Status | Lives now |
|---|---|---|---|---|---|---|---|
| X | default for all | compat/env | `WINE_COMPATDB` default `v=3 … exe=*;d3d9=mtld3d;dxgi=wined3d` | D3D9 via mtld3d, DXGI fallback wined3d | `APP/Sources/LauncherCore/LaunchEnvironment.swift:40` | code | Swift |
| X | CoD4, FC2 (mtld3d users) | env | `WINEDLLPATH=<rt>/lib/wine/d3d9/mtld3d` | puts mtld3d's d3d9/d3d8 on the DLL path | `LaunchEnvironment.swift:96-101` | code | Swift |
| X | NFS 2015 | compat | `exe=NFS16.exe;dxgi=dxmt`; `exe=EADesktop.exe;dxgi=dxmt`; `EACefSubProcess.exe` dxmt | D3DMetal faults on D3D11 timestamp queries (c0000005 at ~2:52); D3DMetal for the EA client logged shared-handle errors that dropped the session | `nfs2015.json:154-173`; NFS2015.md §5, §6 | verified | recipe `renderers` |
| X | NFS 2015 | bundle | `deniedBackends`: `gptk` denied for NFS16.exe; `runtimeRetention: lib/wine/dxgi/dxmt` (no D3DMetal shipped) | as above; no Apple framework redistributed | `recipes.py:25-32`, `GameKind.swift:68-78` (duplicate, different wording) | code | recipe + Swift |
| X | NFS 2015 | env | MetalFX: `DXMT_METALFX_SPATIAL_SWAPCHAIN=1`, `DXMT_CONFIG=d3d11.metalSpatialUpscaleFactor=<1.0-2.0>` per program | spatial upscaling (factor must be above 1.0, `nfs2015_metalfx.py:21`) | `NFS2015MetalFX.swift:18-22,30-45`; `nfs2015_metalfx.py:18`; gate `check_nfs2015_metalfx.py` | **experimental, labelled "known to crash NFS16", default off** (basis: crashes in 2 launches on 2 Macs vs 0 in 17 launches without; cause unknown) | Swift + Packaging |
| X | BF3 | env (prefix machine env) | `bin/tune.sh`: `fps 60`, `dxmt "d3d11.sampleNaNToZero=True;d3d11.defuseFma=True"`, `metalfx on`, `rtvlog off` written to the prefix's machine environment (EA starts the game with a clean env) | DXMT v0.80 documented knobs | BF3B/README.md "Defaults" | unverified (none measured; machine-env propagation assumed) | BF3B/bin |
| X | BF3 | game-file + dll-ovr | proxy `d3d11.dll` next to `bf3.exe` (`d3d11_log.c`), `HKCU/HKLM\Software\Wine\AppDefaults\bf3.exe\DllOverrides d3d11=native,builtin`; `BF3_RTV_NOSHIM=1` disables | DXMT v0.80 rejects a render-target view on a *buffer* (E_INVALIDARG) -> "DirectX Error"; proxy returns a view on a same-size texture (contents not preserved) and logs to `C:\bf3-rtv.log` | `G/bf4-run/bf3/NOTES.md:49-57`; `bf3/dx/interposer/d3d11_log.c:53`; `bf3/dx/FINDINGS.md` | verified (NOTES.md: no DirectX Error after 1:28; BF3B README: ran windowed 8+ min on Mac A) | `G/bf4-run/bf3/dx/interposer` (**not in git**); copy BF3B/docs/src |
| X | BF3 | settings | theory: `ResolutionWidth/Height=0` caused the RTV failure | | `bf3/dx/FINDINGS.md:14-17` | rejected | knowledge |
| X | BF3 | env | `dx-logging.sh on`: `DXMT_LOG_LEVEL=debug`, `DXMT_LOG_PATH` in HKLM environment | trace | `bf3/dx/dx-logging.sh:8-9` | verified (no RTV descriptors in DXMT logs) | bf4-run |
| X | BF3, BF4 | compat | `bf3-0 bf3.exe dxgi=dxmt` (`BF3_DXGI=wined3d`), helpers bf3-1..3 dxmt; `bf4-0 bf4.exe`, `bf4-1 EADesktop.exe`, `bf4-2 EACefSubProcess.exe` dxmt (`BF4_DXGI`) | helpers failed to import dxgi/d3d11; wine-0010 ships only dxmt + wined3d | `bf3/env-bf3.sh:3-8`; `G/bf4-run/env.sh:28-32` | BF3 verified; BF4 unverified | bf4-run env scripts |
| X | RoN | compat | `ron-0 riseofnations.exe dxgi=dxmt`; `ron-1 patriots.exe` | game is D3D11 via `d3dgl` -> DXMT, not mtld3d | `G/ron-tools/env.sh:7-9`; `ron-recipe-draft.json:22` | verified (Quick Battle with in-game HUD, `FULL-REQUIREMENTS.md:11-13`; INVESTIGATION t7-t11 rows say menu not visually verified) | ron-tools |
| X | FC2 | dll-ovr | `WINEDLLOVERRIDES=…;d3d10,d3d10_1,d3d10core,dxgi=` + `GamerProfile.xml Platform="d3d9"` | force the DX9 path (mtld3d has no D3D10) | `FC/Sources/LauncherCore/LaunchEnvironment.swift:17` (APP copy :22); `FC/docs/FARCRY2.md:159-170` | code ("not verified on the real game" per doc) | Swift, player folder |
| X | FC2 | game-file | `mtld3d.conf`: `adapter.spoof=nvidia`, `shader.asyncCompile=false`, `shaderCache.enable=true`, `render.scale=1`, `present.maxFps=0` | foliage alpha-to-coverage only enabled on NVIDIA/ATI; otherwise leaves draw opaque | `FC/Packaging/FarCry2Defaults/mtld3d.conf`; `G/fc2-dev/patches/foliage/0001-*.patch` + PNGs | verified (screenshots) | FC2 defaults; mtld3d profile (GH `integrate-farcry2-profile` 845b6c9) |
| X | FC2 | bundle | `shaderCache: true` + `mtld3dSource` (cache key tracks mtld3d inputs) | prebuilt shader cache | `farcry2.json:15`; gate `check_shader_cache.py` | code | recipe |
| X | CoD4 | game-file | `mtld3d.conf`: `shader.asyncCompile=false`, `render.scale=1` | keep every draw; native res | `MW/Packaging/CoD4Defaults/mtld3d.conf:1-3` | verified (file) | app defaults |
| X | Morrowind | dll-ovr | `WINEDLLOVERRIDES=d3d8=n,b` + `WINEDLLPATH` mtld3d | load mtld3d's D3D8 front end | `G/Morrowind-tools/Play_Morrowind.command:6-7` | verified (owner: plays well) | Morrowind-tools script |
| X | Morrowind | runtime (mtld3d profile) | 4:3 modes; DISCARD colour preservation | video modes; door-transition corruption | `D/mtld3d-x87.md:95-102`; `G/Morrowind-tools/README.md:11` | fix verified (GPU capture) | mtld3d |
| X | all mtld3d | knob | `MTLD3D_CONFIG`, `color.hdr.enable`, `shaderCache.enable`, `shader.asyncCompile`, `render.scale` (<1 = MetalFX spatial), `render.lodBias`, `present.maxFps` | per-game tuning surface | `D/mtld3d/mtld3d.conf`, `README.md:100` | code | mtld3d |
| X | mtld3d limits | — | point fill drawn solid; dynamic depth textures outside DEFAULT-pool D16/D24X8/D24S8 unavailable | | `D/mtld3d/docs/STATUS.md:132,134-135` | known limits | mtld3d |
| X | DXMT limits | — | buffer RTV rejected (see BF3); D3D10 not covered by mtld3d; DXMT `main` is LGPL since 2026-04-25 (v0.80 MIT) | | BF3 NOTES; `G/mtld3d-test/dxmt-src/dxmt` LICENSE history | verified (BF3) | knowledge |
| X | all | env | DXMT knobs from source: `DXMT_CONFIG`, `DXMT_CONFIG_FILE`, `DXMT_ENABLE_NVEXT`, `DXMT_SHADER_CACHE=0`, `DXMT_SHADER_CACHE_PATH`, `DXMT_USE_DEFAULT_METAL_CACHE`, `DXMT_CAPTURE_EXECUTABLE`, `DXMT_CAPTURE_FRAME`, `DXMT_LOG_PATH/LEVEL`, `DXMT_METALFX_SPATIAL_SWAPCHAIN` | | `dxmt-src/dxmt/src/...` | code | knowledge |
| X | NFS 2015 | rejected | DXVK via a Vulkan-preserving Wine variant; D3DMetal for game and client | superseded by DXMT / failures above | NFS2015.md §6 | rejected | knowledge |

## 3. x87 sidecar (Rosetta x87 helper)

| X | Game | Layer | Override | Why | Evidence | Status | Lives now |
|---|---|---|---|---|---|---|---|
| X | all 32-bit | env | `ROSETTA_X87_PATH=<pinned x87sidecar>` (Wine re-execs 32-bit processes through it); pinned sha256 `3ca9cc72…a628` | Rosetta runs x87 slowly | `D/x87sidecar/README.md:40-42`; `runtime-inputs.json:15-16` | verified (processes seen) | Swift `LaunchEnvironment.swift:62-64,92`; env scripts |
| X | CoD4 | env | default on; `COD4_X87=0` off | median 146.1 vs 79.2 FPS (windowed, uncontrolled) | `G/CoD4-tools/Play_CoD4.command:9-13` | observed | CoD4-tools, MW app |
| X | FC2, NFSMW, Morrowind | env | always on (`FARCRY2_X87=0` dev switch) | | `FC/.../LaunchEnvironment.swift:51`; `FC/tools/farcry2/Play_FarCry2.command:30`; `G/Morrowind-tools/Play_Morrowind.command:10` | code | Swift, scripts |
| X | NFS 2015 | env | off unless the player chooses (settings page) | 64-bit game, little benefit; NFS2015.md:289 says runs were without it while §7 says "stays in the bundle, not optional" (conflict) | `NFS2015SidecarView.swift:18` | code; doc conflict | Swift |
| X | BF3 | env | ON by default; `BF_SIDECAR=0` off | loading "much better" (not measured); **in-game sound missing with it on (suspect, unproven)**: A/B pending | BF3B/README.md "Defaults" | unverified | BF3B/lib/env.sh |
| X | RoN | env | not set; x87 negligible in game code; helps Wine audio (0.69 cores) | | `G/ron-tools/PERF.md:11,29` | measured idle | ron-tools |
| X | knobs | env | `X87_DISABLE_HOOK=1`, `X87_SAMPLE`, `X87_PROFILE`, `X87_FORCE_UNSUPPORTED`, `X87_ENABLE_FMA_CONTRACT` | baseline/profiling/tests | `D/x87sidecar/README.md:50,198-214,285,314` | code | x87sidecar |
| X | limit | — | one IPC round trip per cold-translated block; not full 80-bit equivalence | | README:139; docs/NFSMW.md:18 | known | x87sidecar |

## 4. Process environment (launcher-level, all games)

| X | Game | Layer | Override | Why | Evidence | Status | Lives now |
|---|---|---|---|---|---|---|---|
| X | all | env | `WINEDEBUG=-all` (BF: `BF_WINEDEBUG='err+all'`) | no debug overhead | `LaunchEnvironment.swift:49,84` | code | Swift; BF scripts |
| X | all | env | `WINEMSYNC=1` | msync (no measurable effect at idle in RoN) | `LaunchEnvironment.swift:86`; `ron-tools/env.sh` | code | Swift + scripts |
| X | all | env | `MTL_HUD_ENABLED=0` (setting/`BF_HUD=1` toggles) | | `LaunchEnvironment.swift:89` | code | Swift |
| X | all mtld3d | env | `RUST_LOG=warn,mtld3d::perf=off` (FC2 dev, CoD4 and Morrowind scripts use `info,…`) | mtld3d telemetry off | `LaunchEnvironment.swift:90` | code | Swift (dup in 3+ places) |
| X | all | env | sanitized launch environment: only `HOME`, `USER`, `LOGNAME`, `TMPDIR`, `PATH`, `LANG` are passed through | reproducible, private launches | `LaunchEnvironment.swift:77-83`; `G/bf4-run/env.sh:8-10` | code | Swift; scripts |
| X | all | dll-ovr | `mscoree,mshtml=` (no Mono/Gecko prompts). NFS 2015 with the managed runtime uses `IGOProxy32.exe=d;winemenubuilder.exe=d;mshtml=` (mscoree enabled for Wine-Mono, mshtml still disabled); only the BF3/BF4 scripts leave mshtml enabled (Gecko needed for `res://`) | | `APP/.../LaunchEnvironment.swift:20-26`; `G/bf4-run/env.sh:13-14` | code | Swift; scripts |
| X | all with clients | dll-ovr | `winemenubuilder.exe=d` (in Swift only for NFS 2015; also RoN and BF scripts) | keep host menus/file associations clean | NFS2015.md §5 | policy | Swift; scripts |
| X | all | bundle | reserved env prefixes `WINE`, `DYLD_`, `LD_`, `ROSETTA`, `MTL_` cannot be set by recipes | safety | `ExecutableEnvironment.swift:24` (no Python mirror) | code | Swift |
| X | all | prefix-reg | `HKCU\Software\Wine\Mac Driver RetinaMode=Y` (NFS 2015 via `prefixSettings`; display safety may record `RetinaMode=N` on some screens, NFS2015.md §3.4/§20.2; NFSMW uses `N`); `Version=win10` only in the CoD4, FC2 and NFSMW settings.reg (not NFS 2015) | native-resolution full screen (NFS2015 first-launch resolution §3.4) | `nfs2015.json:118-127`; `CoD4Defaults/settings.reg:4,7`; `FarCry2Defaults/settings.reg:4,7`; `MW/Packaging/settings.reg:50,53` | verified (NFS2015, CoD4) | recipe `prefixSettings`, settings.reg |
| X | NFS 2015 (any DS4 user) | prefix-reg | `WineBus\Devices\054C/05C4` and `054C/0CE6` `Hidraw=0` (`controllerDevices`) | present DualShock 4/DualSense through XInput | `nfs2015.json:48-51`; NFS2015.md §3.5 | verified | recipe |

## 5. EA client layer (NFS 2015, BF3, BF4)

| X | Game | Layer | Override | Why | Evidence | Status | Lives now |
|---|---|---|---|---|---|---|---|
| X | EA | launch | start `EADesktop.exe --in-process-gpu` **directly** (EALauncher does not forward the flag) | EA UI renders blank without it | NFS2015.md §5-6; `nfs2015.json:30-32`; `G/bf4-run/run-ea.sh:15` | verified | recipe `storeClient.clientArguments` |
| X | EA | launch | game start via `EALauncher.exe "origin2://game/launch/?offerIds=<id>"` (NFS 1024486; BF3 `DR:225064100`); recipe caps URL at 512 chars | the client starts the game; offer id from the install's activation log | `nfs2015.json:34-35`; `bf3/run-ea-bf3.sh:11` | verified (NFS, BF3) | recipe `storeClient` |
| X | BF4 | client | `offerID` list (20 ids), `launchChain` BFLauncher.exe -> BF4WebHelper.exe -> bf4.exe, `leaseTarget: bf4.exe`, `expectedPorts` 3215/3216, `rootFiles` | 64-bit helper-launched game | `G/bf4-tools/bf4-recipe-candidate.json:42-86,249-253`; `APP` branch `bf4-recipe-schema` b028857/e7e7a1b | schema in Python only; **Swift side not updated** (`ImportRules.swift:98` i386 only; `StoreClientPlan.swift:91` single offer); BF4 unverified | bf4-tools; nfs-release (local-only branch) |
| X | EA | dll-ovr | `IGOProxy32.exe=d` | EA's 32-bit overlay faults in the 32-bit wined3d/DXGI path (open Wine bug above) | NFS2015.md §5 | verified | Swift `LaunchEnvironment.swift:23-26` (dup in `tools/client-start-check.py:100`, `capture-client-layer.py:70`) |
| X | EA | prefix | Wine-Mono 10.4.1 MSI into `Addons/` (`managedRuntime`) | EA installer custom action fails with error 1603 | `nfs2015.json:174-183`; NFS2015.md §13.9 | verified | recipe |
| X | EA (BF3 Touchup/Game Explorer) | prefix + dll | keep mshtml enabled; Wine Gecko 2.47.4 x86+x86_64 (sha256 in BF3B/SOURCES.md); `res://` protocol handler key | Touchup registers Game Explorer, which loads GDF XML via `res://`, served only by mshtml | `G/bf4-run/env.sh:13`; `bf3/NOTES.md:16`; `G/bf4-run/gdf-test/*.c` | verified (finalize step succeeded) | bf4-run prefix; BF3B prefix |
| X | EA (BF3 web helper) | prefix-reg + dll | `CLSID_ShellWindows {9BA05972-…}` served by `shellwin.dll` (empty IShellWindows; i686 + x86_64) | ieframe lacks it; helper quits with `0x80040111` | `bf3/NOTES.md:11-14`; `bf3/shellwin/shellwin.c` | verified | `G/bf4-run/bf3/shellwin` (**not in git**); BF3B/docs/src |
| | BF3 | env | `BFWEBHELPER_ALWAYS_ACTIVATE=1` | forces ACTIVE state | `bf3/NOTES.md:17` | observed | bf4-run |
| X | EA (Battlelog) | launch/client | Battlelog in a Chromium browser with a **32-bit Windows User-Agent** and an in-bundle profile; page calls plain-HTTP `127.0.0.1:3215` (`/ping`, `/game/status`, `POST /game/launch`) | Battlelog rejects macOS and 64-bit browsers; Safari blocks the mixed content (https page -> http loopback) | `bf3/NOTES.md:23-44`; BF3B/bin/open-battlelog.sh, README "Verified" | verified on Mac A per BF3B/README.md "Verified there" (Chrome Canary with a Windows identity launched bf3.exe); `bf3/NOTES.md:23-24,44` alone only reports it from Linux users/inference: the reviewer could not re-check because the local BF3B copy was removed | BF3B/bin (mbp23) |
| X | EA | client | port 3215 = EA local HTTP service; **3216 = LSX plain XML, not TLS** (earlier "TLS alert" was a misread) | readiness checks / expectedPorts | `bf3/NOTES.md:33-35` | verified | knowledge, BF4 candidate |
| X | BF3 | launch | direct `bf3.exe -webMode SP -Origin_NoAppFocus` makes the DRM ask EA to relaunch | reproduces Play without clicks | `bf3/NOTES.md:61-62` | verified | knowledge |
| X | EA | client | `ClientUpdateDestaging`: launcher treats EA's self-update exit as a failed start and kills the session | | NFS2015.md:2280,2357; `G/ea-helper/DESIGN.md:104,193,223`; `G/bf4-tools/PLAN.md:57` | **open, not fixed** (needs a readiness rule) | ea-helper design |
| X | EA | client | client layer: a pre-installed, never-signed-in EA app layer; per-user/per-machine/account/host state removed (sign-in, browser cache, activation/licence files, logs, certs, device enumeration, font paths); gates `check_client_layer.py`, `check_authenticode.py` (EA installer 13.805.2.6319 sha256 pinned) | portable and privacy-safe client | NFS2015.md §15.2-15.4; `nfs2015.json:184-203`; BF3B README "Cleaned out"; `G/bf4-run/bundle-tools/clean_prefix.py` | verified (NFS gates); BF3 bundle cleaned but never started | recipe `clientLayer`; BF3 clean script (**not in git**) |
| X | EA | client | **do not re-activate**: never swap runtimes under a signed-in prefix (machine-bound activation recurs on any runtime change; EA reportedly 5 activations/24 h, unverified); BF4 keeps wine-0010, not 0011 | | NFS2015.md §9; `G/bf4-run/README-OWNER.md:4,32`; BF3B README | rule | docs only |
| X | EA | client | rejected: emulating, stubbing or forging EA services/tokens/activation; Wine 11.18 as EA host (no authCode, SSL/DirtySDK failures); `WINE_DISABLE_NX_COMPAT=0` | | NFS2015.md §6 | rejected | knowledge |
| X | BF3 | client | PunkBuster services PnkBstrA/B run in the prefix; PnkBstrB uses 50-70% of a core: `bin/stop.sh` stops the prefix wineserver | | `bf3/NOTES.md:20`; BF3B README | observed | BF3B/bin |
| | BF3 | launch | `run-ea-bf3.sh start` refuses if EA or game is already running | single-client guard | `bf3/run-ea-bf3.sh:9` | code | bf4-run |
| | BF3 | settings | `set-display.sh` / BF3B `bin/preset.sh windowed|fullscreen|perf` edits `PROF_SAVE_profile` | windowed 1920x1200@60 tested; fullscreen did not work (cause unknown); perf values guessed | `bf3/set-display.sh:5-9`; BF3B README | windowed verified; fullscreen open; perf unverified | bf4-run; BF3B |
| | BF3 | open | in-game sound missing (startup sound works) | sidecar suspected only | BF3B README | open | — |
| X | NFS 2015 | env | `WINE_RWX_WX_LOG=<preset window>` set automatically whenever W^X emulation is on | per-page diagnostics | `NFS2015WineExperiments.swift:9-11` | code | Swift |
| | BF4 | env | switches `BF4_RUNTIME` (default wine-0010), `BF4_WINEDEBUG`, `BF4_HUD`, `BF4_SIDECAR=0`, `BF4_RWX=1`, `BF4_DXGI` | | `G/bf4-run/env.sh:5,11,16,21,24,28-32` | code | bf4-run |
| | BF4 | all | env.sh mirrors NFS (TF on, RWX off, sidecar on, dxmt); install needs ~32.4 GiB + 45 GiB free; prefix-bf4 is an APFS clone (~4 MiB real) | | `G/bf4-run/README-OWNER.md:3,8-9,20,29` | unverified (DXMT never ran BF4) | bf4-run |

## 6. Steam layer (Rise of Nations; research only)

| X | Game | Layer | Override | Why | Evidence | Status | Lives now |
|---|---|---|---|---|---|---|---|
| X | RoN | client | none: `steam_api.dll` unmodified, `steam_appid.txt`=287450; `SteamAPI_Init` fails softly, single player continues without the client | | `G/ron-tools/INVESTIGATION.md:14` (logs/t9) | verified | knowledge |
| X | Steam | client | rejected: stub/emulator `steam_api.dll`, forged appmanifest | ToS/legal; not needed | `INVESTIGATION.md:15`; `FULL-REQUIREMENTS.md:65,82` | rejected | policy |
| X | Steam | client | steamwebhelper needs `dxgi=dxmt` instead of the built-in `gptk` rule | see section 1 | `FULL-REQUIREMENTS.md:70-73` | prototype | knowledge |
| X | Steam/RoN | prefix | prefix isolation: `users/crossover/*` symlinks to the macOS home (game/Steam could read Documents) | privacy | `FULL-REQUIREMENTS.md:29` | open (needs workaround) | knowledge |
| | RoN | launch | `explorer /desktop=ron,1280x960` virtual desktop | native fullscreen crashes: an uninitialised local in `riseofnations.exe` (VA 0x599700) read by `d3dgl SetDisplayMode` (`INVESTIGATION.md:24` has the superseded cause) | `FULL-REQUIREMENTS.md:52-54` | workaround verified | ron-tools |
| | RoN | prefix | i386 `winegstreamer.dll` E_NOTIMPL stub in `syswow64` | WM-reader movie crash | `G/ron-tools/diag/stub`; FULL-REQUIREMENTS.md:21,88 | verified tolerated (alternative: SkipIntroMovies) | ron-tools prefix |
| | RoN | settings | `rise2.ini`: `Fullscreen=0`, `SkipIntroMovies=1`, `VSync=1`, window 1024x768 (draft says 1280x960: conflict) | avoid movie load | FULL-REQUIREMENTS.md:7,87 | SkipIntroMovies verified | `AppData\Roaming\Microsoft Games\Rise of Nations` |
| | RoN | prefix | `patriots.exe` (expansion launcher) needs `mfc140` (VC++ 2015-2022 x86): c0000135 | not installed | FULL-REQUIREMENTS.md:24,26,89 | verified missing | — |

## 7. Per-game, non-EA specifics

| X | Game | Layer | Override | Why | Evidence | Status | Lives now |
|---|---|---|---|---|---|---|---|
| | NFSMW | dll-ovr | `dinput8=n,b` (ASI loader proxy) | loads the mods below | `MW/Sources/LauncherCore/LaunchEnvironment.swift:17`; `nfsmw.json:47-49` | verified (gameplay) | Swift |
| | NFSMW | game-file | `NFSMostWanted.WidescreenFix.asi/.ini/.tpk`, `NFS_XtendedInput.asi/.ini`, `Z_NFSMW_Rumble.asi`, `Z_NFSMW_Unlocks.asi`, `NFSMW_RumbleHelper.exe` (WidescreenFix input mapping off; camera deadzone 20.0) | widescreen, analog input, rumble, unlocks | `nfsmw.json:65-109`; `MW/docs/TUNING.md:27-29` | widescreen + XtendedInput verified; rumble partial | recipe `compatibility` |
| | NFSMW | bundle | `widescreen_compat.py` resolution-pattern replacement; gate `check_widescreen_compat.py` | max light-streak startup crash at 0x76ba6511 | `MW/docs/TUNING.md:20` | verified (owner) | Packaging |
| | NFSMW | prefix-reg | `settings.reg` `g_FSAALevel=2`, `g_VSyncOn=0`, `g_ShadowDetail=2`, `g_PerformanceLevel=5`, `g_RacingResolution`, `InstallDir=C:\NFSMW` | graphics defaults | `MW/Packaging/settings.reg` | code | Packaging |
| | NFSMW | settings | `SimRate` 120 | 120 Hz displays doubled sim ticks | `G/NFSMW-tools/TASK-NOTES.md:140` | doc | bundle |
| | CoD4 | launch | temporary `G:` drive to the private game folder | `fileSysCheck.cfg` not found (Wine fell back to `C:\windows`) | `MW/docs/COD4.md:38-42` | verified | Swift |
| | CoD4 | settings | `config.cfg` `r_fullscreen 1`, `r_aaSamples 4`, aniso 16, `r_picmip 0` … | max quality | `MW/Packaging/CoD4Defaults/config.cfg` | code | defaults |
| | CoD4 | bundle | gate `check_cod4_data.py`: payload excludes player state | | Packaging | code | Packaging |
| | FC2 | launch | `FarCry2.exe` args + `--startup` profile | | `FarCry2Session.swift:106-121` | code | Swift |
| | Morrowind | prefix | LAVFilters 0.83 splitter/decoder | music playback | `G/Morrowind-tools/README.md:15` | doc | Morrowind prefix |
| | Morrowind | settings | 1680x1050 fullscreen, pixel water, 6 shadows; `mtld3d.conf` beside Morrowind.exe (HDR off) | | README.md:9,13 | doc | prefix |
| | NFS 2015 | bundle | import edition (144 pinned files, `inventorySHA256`, `executableHashes`) vs bundled edition; gates `check_bundle_hygiene.py`, `check_game_data.py`, `check_nfs2015_settings.py` | data never redistributed in the public repo | NFS2015.md §7, §13 | verified (delivered -0010 apps) | recipe |

## 8. Packaging, disk and clone lessons (bundle layer)

| X | Lesson | Evidence | Status |
|---|---|---|---|
| X | Use APFS clones (`cp -c -R`) for prefixes/game copies; `du` overstates real use (bf4 prefix 23 GiB logical, ~4 MiB real) | `G/bf4-run/README-OWNER.md:3`; `G/wine-rebuild/HANDOFF.md:89`; `G/Store/README.md:3` | rule |
| X | Disk floor 15 GiB (watchdog); never clone a full install on this Mac; Wine build tree peaks 5.4 GiB | HANDOFF.md; `G/bf4-tools/PLAN.md:586` | rule (disk now 13 GiB free: **below the floor**) |
| X | Wine refuses prefixes in `/tmp`; a mistyped `WINEPREFIX` silently creates a new prefix | HANDOFF; `/Users/gc/Documents/NFS-backups/deleted-20261008.log` | verified |
| X | zsh does not split an unquoted `$cfg` for `env` (HANDOFF.md:373); mbp23 login shell is fish (use `/bin/bash -s`) | HANDOFF.md:373 | verified |
| X | `/Volumes/ExT2` is case-sensitive APFS: Wine falls back to slow case-insensitive lookups; copy bundles to the internal disk | BF3B README | verified |
| X | Quarantine: `xattr -dr com.apple.quarantine <bundle>` after AirDrop/download/USB; signing policy gate `check_signing_policy.py` (Developer ID, Wine exception scoped) | BF3B README; Packaging | verified |
| X | Strip optimisation must keep executable bytes (`check_runtime_optimization.py`); every NOTICE component has its licence (`check_notice_licences.py`); privacy usage strings (`check_privacy.py`) | Packaging | code |
| X | Pin everything: runtime file sha256 per profile (`runtime-inputs.json`), renderer DLL pins, sidecar sha256, DXMT licence sha256, EA installer sha256; **gap: Wine source archive `wine-nfs2015-source-0010.tar.gz` has no digest; runtimes have manifests only in `G/wine-rebuild/logs/runtime-000N-manifest-sha256.txt`** | `nfs2015.json:212`; runtime-inputs.json | gap |
| X | Stale comments to fix during migration: `LaunchEnvironment.swift:94-95` says NFS2015 uses D3DMetal; `check_nfs2015_recipe.py:67` says "Vulkan-backed DXGI" | recipes extraction | to fix |
