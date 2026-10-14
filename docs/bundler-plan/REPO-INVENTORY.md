# Repository, clone, runtime, prefix and data inventory (Wine / Windows-games effort)

Read-only survey, 2026-10-09. Nothing was changed. Sizes are **logical** (`du -sk`); APFS clones (`cp -c`) share blocks, so real use
and real space freed are lower and could not be measured (no allocation-level tool was run). "On GH" means verified with read-only
`gh api` against g-cqd/* (branch heads, or `commits/<sha>`; a sha found only via `commits/<sha>` but not at a branch head is
**unreferenced on GitHub**: it can be garbage-collected, so it counts as not preserved until a branch or tag points at it).

**Disk now: 13 GiB free on `/`, below the 15 GiB floor.** mbp23 `/Volumes/ExT2`: 381 GiB free; mbp23 `/`: 57 GiB free.

Classes: **A** fully redundant (proof given) · **B** regenerable but costly (time given) · **C** unique work/data: do not delete until
preserved (what and where) · **D** game data or EA/Steam session/owner data: explicit per-item approval only.
Path prefixes: `G/` = `/Users/gc/Developer/Games/`, `D/` = `/Users/gc/Developer/`.

## 0. Out of scope (other sessions; not inspected, never touch)
`D/rosetta3`, `D/rosetta3-target`, `D/rosetta3-targets`, `D/rosetta3-wt` (also holds `macos-app-host4k`, a worktree of `G/FarCry2-tools/macos-app`: do not prune that worktree from this side),
`D/claudetalk`, `D/skills`, `D/g-cqd/Atelier`, `D/g-cqd-push/*` (Atelier, arcleak, analyzerkit, dolly, deadwood), `D/g-cqd-work/*`, `D/xcode-themes`,
`D/exfit`, `D/gpsmerge` (fitness data), `G/fc2-dev/rosetta3`, `G/fc2-dev/r3-ml-data` remnants and `G/fc2-dev/rosetta-analysis` (kept on purpose by the rosetta3 session, `D/_archive/cleanup-20261008.md`),
`G/bump-tools` (2.50 GiB toolchains; explicitly kept by the rosetta3 session: shared, out of scope), `G/f2` and `G/Far Cry 2 - Authentic` (empty, used as working dirs by other sessions),
`/Users/gc/Documents/rosetta3-backups`, `Zwift`, `/private/tmp` entries `agora*`, `arcleak*`, `dolly*`, `atelier*`, `deadwood*`, `claudetalk*`, `analyzerkit*`, `rosetta3*`, `skills*`, and ~793 unclassified `/private/tmp` entries.
Also not ours to decide: `/Users/gc/Documents/Torrents` (6.9 GiB, owner's downloads), `/Applications/Wine Staging.app` (11.14, dated 2022).

## 1. Git repositories and worktrees

| Path | What | Size | Git state | Remote / pushed? | Unique content | Class |
|---|---|---|---|---|---|---|
| `G/nfs-release/macos-app` | **canonical recipe system** (Swift app + Packaging/recipes.py, 20 check_*.py gates, Recipes/*.json, runtime-inputs.json, docs/NFS2015.md 222 KB) | ~0.3 GiB of 1.14 | branch `bf4-recipe-schema` e7e7a1b, clean, 0 stashes; branches `nfs-firstrun`, `nfs-release-rebuilt` 9b6e8ed | origin = local path `nfs-firstrun`; all commits on g-cqd/nfs-macos **except b028857, e7e7a1b** (422 on GH) | the BF4 schema commits (x86_64, offerID lists, rootFiles, launchChain/leaseTarget/expectedPorts, gate `check_bf4_recipe_schema.py`) | **C**: push `bf4-recipe-schema` to g-cqd/nfs-macos (or git bundle to mbp23) |
| `G/publish/nfs-macos` | public clone of g-cqd/nfs-macos; extra remotes `fc2`, `host4k`, `nfsfinal`, `release` point at sibling clones | 0.83 GiB (incl. `.build`) | `main` 981aee6 = GH main; `game-store`, `land-0010` contained; clean | yes | none of its own (its object store also holds the FC2 local-only commits: a second copy, not a backup) | **A** (proof: every local head is a GH head or ancestor) |
| `G/NFSMW-tools/macos-app` | older app clone (NFSMW/CoD4 line) | 541 MiB | `refresh-runtimes-cod4-bundle` 71082c8; **4 dirty**: ` M Packaging/build.py` (+8/-8), ` M docs/BUNDLING.md` (+15/-1), `?? Packaging/app_archive.py`, `?? Packaging/check_app_archive.py` (both byte-identical to commit 99b98c1, on GH) | all 37 unpushed-by-tracking commits found on GH by sha; `archive/*` tips are ancestors of GH main | only ~6 lines of build.py are unique (ZIP64 wiring: `from app_archive import create_archive`, `create_archive(output, archive)` replacing `ditto` + `testzip`; `git log --all -S` finds them nowhere); BUNDLING.md edit is an older version (stale) | **C** (tiny): save `git diff` as a patch; then A |
| `G/FarCry2-tools/macos-app` | FC2 app clone; worktree also at `D/rosetta3-wt/macos-app-host4k` | 757 MiB | `integration-20261002` = `host-4k` = cfd2de9, clean | **5 commits local-only** (cfd2de9, 6832249, 9f3bbd0, 76267b8, a8f5da9: native arm64 Wine route, arm64 winehost helper app, entitlements, posix_spawn launcher with 4 KiB page size) | those 5 commits | **C**: push `integration-20261002` as a new branch name (GH's is at f4c3273) or bundle; also the only home of `docs/ARM64ROUTE.md`. Deleting this repo would orphan the worktree `D/rosetta3-wt/macos-app-host4k` (other session) |
| `G/nfs-firstrun/macos-app` | first-run app line | 6.2 MiB | `nfs-firstrun` 7b1bd8f, clean | origin local; tip is an ancestor of GH main; also in `~/Documents/NFS-backups/nfs-firstrun-20261008.bundle` | none | **A** |
| `G/wine-rebuild/src/wine` | Wine source used for runtimes 0005-0011 | 386 MiB | `wx-0011` 412fcd8; branches wx-0008..0011, `wx-experiment` 44974bf; clean | origin athei/wine; all 12 runtime commits **patch-id-equivalent** on g-cqd/wine (`nfs2015-runtime-0005/0010/0011`, tags `nfs2015-runtime-000N-20261008`); **`wx-experiment` 44974bf local-only** | wx-experiment (3 files, +41/-246) | **C** for wx-experiment only (bundle it); otherwise redundant **but still a live recipe input** (`nfs2015.json:58` `runtimeSourceTree`): keep until the recipe points elsewhere |
| `G/wine-rebuild/wine-build` | athei/wine-build clone (build scripts) | 0.5 MiB | detached 0813ba8, clean | upstream GitHub | none | **A** |
| `G/wine-rebuild/pkg` | clone of the packaging archive bundle | 5 MiB | `archive/nfs-complete-debug/nfs-complete-fix`, clean | origin = `~/Documents/NFS-backups/nfs-packaging-archive-20261007.bundle` | none | **A** |
| `G/wine-rebuild/ab/sidecar/src`, `src-12afdc2` | x87sidecar checkouts for A/B | small | detached c396937 / 12afdc2 | both on GH (c396937 = GH `integrate-fld-gap-fstp`) | none | **A** |
| `G/nfs-release/inputs/x87sidecar-src` | sidecar source pinned by runtime-inputs.json | 7.7 MiB | detached c396937 | on GH | none | **A** (but the recipe input path points here: re-clone before a build) |
| `G/NFSMW-tools/public-sources/wine` | g-cqd/wine clone (1.0 GiB) | ~1.0 GiB | `nfs2015-runtime-0011` 71133b5, clean; branches incl. `crash-context` ed16a3c, `crash-context-2` 0867f21 | heads on GH except `crash-context*` (found by sha but **no GH branch**) | none if crash-context refs are pushed | **C** until `crash-context`, `crash-context-2` are pushed as branches; then A |
| `G/NFSMW-tools/public-sources/mtld3d` | athei/mtld3d clone, branch `nfsmw-macos` | part of 1.0 GiB | ca187f6, clean, 4 unpushed | **ca187f6 not on GH at all** | 4 NFSMW mtld3d commits | **C** |
| `G/NFSMW-tools/public-sources/mtld3d-clean` | g-cqd/mtld3d clone | part | `nfsmw-upstream-update` 2513602, `nfsmw-macos` fce2a32 | both found on GH by sha, **no GH branch** | refs only | **C** (push the two branches) then A |
| `G/NFSMW-tools/public-sources/x87sidecar` | g-cqd/x87sidecar clone | part | `nfsmw-macos` f979c23 | found by sha, no GH branch | ref only | **C** (push) then A |
| `G/NFSMW-tools/diagnostics/{unlimiter-stock-reference, extra-options-src, save-editor-src, widescreen-reference(+external/hooking)}` | third-party NFSMW mod sources | ~0.1 GiB | clean except `widescreen-reference` **1 dirty** (`source/NFSMostWanted.WidescreenFix/Resolution.ixx`) | upstream GitHub (nlgxzef, ExOptsTeam, sprintstate, ThirteenAG) | the Resolution.ixx edit (basis of the light-streak crash analysis) | **A** except save that diff (**C**, tiny) |
| `G/mtld3d-test/dxmt-src/dxmt` | 3Shain/dxmt clone | 14 MiB | detached 589adb7 (= the v0.80 commit), clean | upstream | none | **A** |
| `D/mtld3d` | mtld3d main clone; worktree `D/mtld3d-wt-sync` | 36 MiB (+15) | `development` 7d108a4 = GH; clean | local-only: `test-fix-d3d8` 5c91c3d (also `upstream-prep/mtld3d/repo` `fix/d3d8-heldpages`), `archive/fc2-foliage/farcry2-nvidia-profile` df60ce0, `fc2-foliage` 0e995a6 (the last two are in `~/Documents/push-backups-20261008/mtld3d-localonly.bundle`) | 5c91c3d | **C** (5c91c3d not bundled anywhere) |
| `D/x87sidecar` | x87sidecar main clone | 28 MiB | `development` b947853 = GH; clean | local-only `archive/fc2-perf/fc2-x87-fuse` db61cb7, `-rebased` bd53e37 (both in `x87sidecar-localonly.bundle`) | covered by the local bundle (same disk) | **C-lite**: copy the bundle to mbp23, then A |
| `D/upstream-prep/x87sidecar` + 4 worktrees `x87sidecar-wt/*` | upstream-PR preparation | 30 + 89 MiB | `pr/ci-actions-majors` d1a71f8 (not verified), `pr/assembler-buffer-grow`, `pr/cache-invalidate-on-fallback`, `pr/fld-gap-fstp`, `pr/fyl2x-log2-domain`, `pr/native-boundary-fastpath`: **local-only** (422) | origin g-cqd/x87sidecar | 11 PR commits | **C** |
| `D/upstream-prep/mtld3d/repo` | mtld3d PR prep | 30 MiB | `pr/encoder-test-scheduling`, `pr/farcry2-profile`, `pr/ff-ternary-texture-ops`, `pr/perf-test-fixed-rate`, `pr/test-unit-perf-leg`, `fix/d3d8-heldpages`: local-only | g-cqd/mtld3d | 6 commits | **C** |
| `D/upstream-prep/swapchain/mtld3d` | swapchain PR prep | 30 MiB | `fix/swapchain-upstream` be03808 (+bdd87b1): local-only | g-cqd/mtld3d | 2 commits | **C** |
| `D/wine-arm64` (outer repo) + `src`, `src-wow64` (worktree) | native arm64 Wine + WoW64 experiment | 7.57 GiB (build 5.30, install 1.56, src 0.39, src-wow64 0.33) | outer `main` 0bf2d41, **no remote, 15 commits** (docs, patches, patches-ondev/-rebased/-wow64, probes, scripts, tests, SOURCES.md); `src` 6 branches, 98 local commits | `arm64-macos-onto-dev` 89a212b = GH `arm64-macos`; `wow64-cpu-onto-dev` c92ef79 = GH `wow64-cpu`; **`arm64-macos` a3433d0, `arm64-macos-rebased` b92f4ed, `wow64-cpu` cf90b43 (src-wow64 HEAD), `wow64-cpu-old` f3ebe29 not on GH** | outer repo entirely; 4 superseded-looking src branches | **C** (outer repo + 4 branches); `build`/`install` **B** (~1-2 h) |

Not git repos but holding source code (no copy in any repo): see `G/bf4-run`, `G/bf4-tools`, `G/ea-helper`, `G/bf4-bundle-stage/work` below.

## 2. Game working directories under `G/`

| Path | What | Size | Unique content | Preserved copies | Regenerable? | Class |
|---|---|---|---|---|---|---|
| `G/bf4-run` | BF3 bring-up and BF4 skeleton | 23.49 GiB | `bf3/` scripts (`env-bf3.sh`, `run-ea-bf3.sh`, `set-display.sh`, `dx/*.sh`), **`bf3/dx/interposer/d3d11_log.c` (+.def, built dll)**, **`bf3/shellwin/shellwin.c` (+.def, i686/x86_64 dlls)**, `bf3/system.reg.before-shellwin`, `gdf-test/*.c` + logs, `env.sh`, `run-ea.sh`, `README-OWNER.md`, `bf3/NOTES.md`, `bf3/dx/FINDINGS.md`, ~25 run logs (5.1 MiB) | NOTES/FINDINGS and the two C sources were byte-identical to the bundle's `docs/` (bundle now only on mbp23, copy in progress when listed); scripts, gdf-test and logs are **only here** | no (hand work) | **C** (sources, scripts, logs) |
| `G/bf4-run/prefix-bf4` | EA app prefix with **Battlefield 3 installed (~20 GB, `Program Files/EA Games/Battlefield 3`)** and the owner's **signed-in EA session** | 23.20 GiB (cloned from the NFS prefix; README says ~4 MiB real for the clone, the BF3 install is real data) | EA sign-in/activation state; BF3 game data | BF3 data also in the cleaned bundle on mbp23 (copy in progress when listed); **this is the only local copy now** | data: ~20 GB re-download; session: sign-in + one activation | **D** |
| `G/bf4-run/browser-profile` | Chromium profile used for Battlelog | 170 MiB | Battlelog/EA web session cookies (not read) | none | sign-in again | **D** |
| `G/bf4-run/downloads` | Wine Gecko 2.47.4 MSIs | 104 MiB | none (sha256 in BF3 SOURCES.md) | dl.winehq.org | minutes | **B** (cheap) |
| `G/bf4-tools` | BF4 plan, recipe candidate, Swift mirror spec | 132 KiB | `PLAN.md` (69 KB), `SUMMARY.md`, `SWIFT-MIRROR.md`, `bf4-recipe-candidate.json`, `-draft.json`, `make_candidate.py`: **not in git** | none | no | **C** |
| `G/ea-helper` | EA helper design | 44 KiB | `DESIGN.md`: not in git | none | no | **C** |
| `G/bf4-bundle-stage` (**gone**) | BF3 tuned bundle staging (24.45 GiB when measured at the start of this survey) | — | — | **removed by another worker during this survey**; the bundle now exists only at mbp23 `/Volumes/ExT2/Bundles/Battlefield3-Tuned-20261009` (5.7 GiB and growing when listed; verification status against its MANIFEST.sha256 unknown to this survey) | — | n/a: ask the bf3-bundle worker for its verification record |
| `G/bf4-run/bundle-tools/clean_prefix.py` | prefix-cleaning policy as code (moved here from the stage) | tiny | **not in git** | none | no | **C** |
| `G/bf4-run/tools/x87sidecar` | pinned sidecar binary (sha256 3ca9cc72…) | 560 KiB | none (pinned in runtime-inputs.json; source c396937 on GH) | NFS apps embed the same binary | minutes | **B** |
| `G/NFSMW-tools/ea-app-lab` | EA app + NFS 2015 lab | 16.4 GiB (Prefix 15.2 with EA Desktop + NFS16.exe; Wine 1.2) | prefix with NFS 2015 install and probably EA state (not opened); `SETUP.md`, Logs, Diagnostics | NFS 2015 data also in `G/Store/nfs-2015`, `~/Library/Application Support/NFS2015Mac`, mbp23 NFS Bundled app | prefix: hours + activation | **D** (prefix), **C** (SETUP.md, logs) |
| `G/NFSMW-tools/diagnostics` | NFS2015 context build/src/wine, mod sources | 1.7 GiB | context patch work in `nfs2015-context-src` (332 MiB) not verified against GH | — | build ~1 h | **B**; **C** for nfs2015-context-src until compared with g-cqd/wine `crash-context*` |
| `G/NFSMW-tools/build-env` | rustup 1.4, xwin 1.0, cargo | 2.7 GiB | none | upstream downloads | ~30 min download | **B** |
| `G/NFSMW-tools/wine-cursor-src` | Wine source tree (no .git) with the winemac cursor patch | 332 MiB | none: all 41 `dlls/winemac.drv/*` blobs hash-identical to g-cqd/wine `nfsmw-macos` f064add; dlls/include/libs/server/loader/programs/tools: 0 differences (Sonnet check) | g-cqd/wine `nfsmw-macos` | `git archive` | **A** |
| `G/NFSMW-tools/{mtld3d-v0.11.0, d9vk-macOS-async-v1.10.3-*}` | downloaded release archives | 20 MiB | none | upstream releases | minutes | **A/B** |
| `G/NFSMW-tools/*.md, *.reg, *.ixx, *.json, *.conf` (~20 loose files incl. `TASK-NOTES.md`) | NFSMW knowledge and references | <1 MiB | knowledge | partly in MW/docs | no | **C** |
| `G/wine-rebuild/runtime/wine-0005..wine-0011`, `wine` | built runtimes | 11.2 GiB (1.40 each, logical) | binaries only; manifests at `G/wine-rebuild/logs/runtime-000N-manifest-sha256.txt` | wine-0010 is embedded in the shipped NFS apps (mbp23 `Need for Speed Bundled 20261008-13d1f4f-0010.app`) and in the BF3 bundle; sources tagged on g-cqd/wine | ~1 h per full build (configure ~10 min, make ~50 min), minutes for a single-DLL respin | **B**; keep wine-0010 and wine-0011 (pinned / used by BF3) |
| `G/wine-rebuild/build` | Wine build tree | 5.35 GiB | none (HANDOFF: "kept as insurance") | — | ~1 h | **B** |
| `G/wine-rebuild/scratch-smc` | wine-wx build (W^X experiment runtime) | 1.4 GiB | built from `wx-experiment` (local-only branch) | — | ~1 h once the branch is preserved | **B** after wx-experiment is bundled |
| `G/wine-rebuild/source-archive` | `wine-nfs2015-source[-0005..-0011].tar.gz` | 410 MiB | **LGPL corresponding-source archives cited by shipped apps** (`nfs2015.json:212` names `wine-nfs2015-source-0010.tar.gz`, no digest) | regenerable with `git archive` from GH tags but must stay byte-stable for the shipped apps | minutes, not byte-identical | **C** for -0010 and -0011 (keep with a sha256), **B** for the others |
| `G/wine-rebuild/{toolchains, deps, downloads, cargo-home, sysroot}` | toolchain/deps (rust, wine-deps tarball, dxmt-v0.80-builtin.tar.gz, mtld3d.tar.xz) | ~0.8 GiB | none (pinned inputs) | upstream | ~30 min | **B** |
| `G/wine-rebuild/{HANDOFF.md, logs, ab, scratch, scratch-dsound, tests-wx, local}` | hand-off (46 KB), logs + runtime manifests, A/B harness, build scripts | ~50 MiB | **HANDOFF.md, run-env.sh/build-wine.sh in `local/`, runtime manifests, A/B harness: not in git** | none | no | **C** |
| `G/ron-tools` | Rise of Nations investigation | 16.85 GiB | docs (INVESTIGATION, FULL-REQUIREMENTS, PERF), `env.sh`, `run.sh`, **`pe_inventory.py`** (seed of the bundler's PE scanner), `pe-inventory.json`, `ron-recipe-draft.json`, `diag/stub` (winegstreamer stub), `perf/patches` (dsound patch: now in g-cqd/wine 0011), logs (2.2 + 114 MiB) | none | no | **C** (docs/tools/logs) |
| `G/ron-tools/prefix`, `full/prefix-full`, `full/prefix-dsound` | RoN prefixes (with game copies, maybe Steam client) | 3.9 + 5.6 + 5.6 GiB | none known beyond settings | game in `G/Store/rise-of-nations` and mbp23 Steam library | ~30 min each | **B** (D if a Steam login is in one: not checked) |
| `G/ron-tools/full/runtime-scratch` | runtime with the steamwebhelper dxmt prototype | 1.4 GiB | the prototype rule change (not in any repo) | none | — | **C** until the rule diff is captured |
| `G/Store/nfs-2015` | NFS 2015 game files (144 pinned files) | 13.6 GiB | owner's licensed data | also in `~/Library/Application Support/NFS2015Mac/Data/Prefix`, `ea-app-lab/Prefix`, mbp23 NFS Bundled app (15.2 GiB) | EA re-download | **D** |
| `G/Store/rise-of-nations` | RoN Steam files (12,410 files) | 2.6 GiB | none | mbp23 `ExT2/Steam/steamapps/common/Rise of Nations` (source, SHA-256-verified) | copy | **D** (owner data; redundant with mbp23) |
| `G/Store/{cod4, farcry2, nfs-mw, Morrowind}` + `README.md` | `MOVED.txt` pointers | tiny | restore commands | data on mbp23 `Backups/Store-20261008` (14.8 GiB) | — | keep |
| `G/Morrowind-tools` | Morrowind runtime and prefix | 3.05 GiB (prefix 1.39 **contains the only local game copy**, wine 1.2, diagnostics 0.3, renderer-snapshots 0.17) | game data in the prefix; README, `Play_Morrowind.command`, snapshots | mbp23 `Backups/Store-20261008/morrowind` | — | **D** (prefix), **C** (scripts, snapshots), **B** (wine) |
| `G/CoD4-tools` | CoD4 runtime and prefix | 2.66 GiB (prefix 1.27, wine 1.2, benchmark/diagnostics/performance ~0.2) | benchmark/perf evidence, `Play_CoD4.command`, README | game on mbp23 Store backup + CoD4 Bundled app | — | **C** (evidence, scripts), **B** (wine), **D** (prefix: player config) |
| `G/mtld3d-test` | mtld3d test env | 4.01 GiB (rustup 2.6, wine-sdk 1.2, cargo 0.25, dxmt-src) | none | upstream | ~30-60 min | **B** |
| `G/nfs-release/inputs` | recipe inputs: `client-layer` 828 MiB, `ea-payload` 242, `wine-mono` 82, `ea-installer` 2, `x87sidecar` 0.5, report | 1.2 GiB | the captured never-signed-in EA client layer (EA binaries: never redistributed) | pinned by sha in nfs2015.json; regenerable via the capture tools from the pinned EA installer | ~1 h + an EA download | **B** (keep while NFS recipes are built here) |
| `G/fc2-dev/{patches, build.sh, build-*.log}` | FC2 foliage patch + before/after PNGs, build logs | small | foliage evidence (patch also on GH `integrate-farcry2-profile`) | GH (patch) | — | **C** (PNGs/logs), patch A |
| `G/pe-inventory.json`, `G/.fc2-extract` | RoN PE inventory; extract marker | 32 KiB | inventory data | `G/ron-tools/pe-inventory.json` (likely same) | seconds | **A** after cmp |
| `G/NFS2015-game`, `CoD4`, `FarCry2`, `NFSMW`, `Morrowind` | symlinks into Store / Morrowind prefix | 0 | — | — | — | keep (recipes resolve through them) |

## 3. Developer-level files and records

| Path | What | Size | Class |
|---|---|---|---|
| `D/_archive` | cleanup records (2026-10-07/08), `.tgz` of dirty NFSMW clones, `records/*.json` delivery records | 4.1 MiB | **C** (records: keep forever) |
| `D/games.md`, `D/mtld3d-x87.md` | 2026-09-27 hand-offs (stale) | small | **C** (fold into docs, then archive) |
| `D/scripts`, `D/g-cqd-publish` | empty | 0 | **A** |

## 4. `/Users/gc/Documents`, `~/Library`, `~/.wine`

| Path | What | Size | Class |
|---|---|---|---|
| `~/Documents/NFS-backups/wine-patches` | patches 0001-0011 | 184 KiB | **A** (all on g-cqd/wine by patch-id) but keep as the archival copy (tiny) |
| `~/Documents/NFS-backups/*.bundle` (8) | git bundles: nfs-release-rebuilt 0005-0010, nfs-firstrun, nfs-packaging-archive | ~10 MiB | **preserved copies**: keep (and copy to mbp23) |
| `~/Documents/NFS-backups/evidence-20261007`, `deleted-20261008.log` | NFS backtraces, deletion log | 0.8 MiB | **C** |
| `~/Documents/push-backups-20261008/*.bundle` | mtld3d-localonly, x87sidecar-localonly, wine-development-candidate | 168 KiB | **preserved copies** (same disk only: copy to mbp23) |
| `~/Documents/My Games` (Far Cry 2, Rise of Nations), `~/Documents/Need For Speed` | game settings/saves/screenshots | 4.5 MiB | **D** |
| `~/Library/Application Support/NFS2015Mac` | the installed NFS 2015 app's live data: `Data/Prefix` with EA Desktop, EA state (`ProgramData/EA Desktop`, `Origin`, `AppData/Local/Electronic Arts`), NFS16.exe (14 GiB); session.lock, state json | 17.2 GiB | **D** (owner's signed-in EA session + game) |
| `~/Library/Application Support/NFSMW` | NFSMW app data: Versions 2.8, Prefix 0.98, Saves, RetainedSaves, Backups | 4.8 GiB | **D** (saves) |
| `~/Library/Caches/{nfs-bundle-smoke-*, nfs2015-tf-trace-root-*, metalfx-feasibility-*}` | scratch from NFS work | ~1 MiB | **C** (tf-trace is evidence) / A |
| `~/.wine` | stock default prefix (only Wine default folders), last touched 2026-10-03 | 0.99 GiB | **C** (purpose unknown: probably an accidental default prefix; ask) |
| `~/Desktop/Games-inventory-20261008.md`, `mtld3d-state-report-20261002.md` (206 KB), `x87sidecar-state-report-20261002.md`, `mtld3d-x87-developer-handoff-20260927.md`, ~18 screenshots (10-02..05) | reports and evidence (found by the review) | <1 MiB + screenshots | **C** (fold into docs/history) |
| `~/Downloads/EAappInstaller.exe`, `EAappInstaller-2.exe` | EA app installers (compare with the sha256 pinned in nfs2015.json before relying on them) | small | **B** (re-downloadable) |
| `~/Downloads/winehost_developer_id*.provisionprofile` | signing material for the arm64 winehost helper (not read) | tiny | **D** (owner credentials: never delete or copy without approval) |

## 5. `/private/tmp` (wiped at reboot: anything C here is at risk today)

| Path | What | Size | Class |
|---|---|---|---|
| `/private/tmp/dxmtfx` | DXMT FX / MetalFX investigation: `an.py`, `mbp23/` session and crash logs, `tb/v0.80` | 51 MiB | **C** (evidence for "MetalFX crashed NFS"): copy out |
| `/private/tmp/mtld3d-lic` | mtld3d clone at 7d108a4 (= GH development) + untracked `cargohome/` | 129 MiB | **A** |
| `/private/tmp/x87fid`, `x87cw`, `x87bcd`, `x87s_scratch`, `r3-cpp-x87` | x87 investigation scratch (may belong to the rosetta3 session) | ~14 MiB | **C / ask** (ownership unclear) |
| `/private/tmp/nfsrel` | scripts, mutation logs, `open-this-first.txt` | 1.1 MiB | **C** (small) |
| `/private/tmp/bf3.sample`, `wine_*.sample.txt`, `perf-*dsound*`, `ron-*.sha`, ~75 `nfs-*` logs, `mtld3d-*.log/json`, `gdv-bundle.log`, `bf4*.sh`, `bf3sp.pid` | samples, logs, verification lists, other workers' current scripts (10-09) | ~20 MiB | **A/B** (logs) except `bf4*.sh`/`gdv-bundle.log` (**belong to running workers: do not touch**) |

## 6. mbp23 (`mbp23.local`) preserved copies

| Path | What | Size |
|---|---|---|
| `/Volumes/ExT2/Backups/Store-20261008/{cod4, farcry2, nfs-mw, morrowind}` | game data moved off this Mac (rsync -c verified per README) | 14.8 GiB |
| `/Volumes/ExT2/Bundles/Need for Speed Bundled 20261008-13d1f4f-0010.app` | shipped NFS 2015 app (contains game data + wine-0010) | 15.2 GiB |
| `/Volumes/ExT2/Bundles/Call of Duty 4 Bundled 20261002-7d108a4.app`, `Far Cry 2 Bundled 20261002-845b6c9.app`, `Far Cry 2 Import …app`, `Most Wanted Bundled 20261002-7d108a4.app` | delivered apps | 6.7 / 3.8 / 0.6 / 3.4 GiB |
| `/Volumes/ExT2/Bundles/Battlefield3-Tuned-20261009` | BF3 bundle, **copy in progress** (other worker) | 5.7 GiB at survey time, target ~24 GiB |
| `/Volumes/ExT2/EA Games/Battlefield 4` | BF4 install (partial) | 1.1 GiB |
| `/Volumes/ExT2/Steam/...` | Steam library (RoN source) | not sized |

**Not preserved on mbp23:** any git bundle (no `*.bundle` found), the wine-patches, `bf4-run` sources/scripts, `bf4-tools`, `ea-helper`, `wine-rebuild/HANDOFF.md`/logs/manifests, ron-tools docs/tools, `wine-arm64`, the EA/Battlelog sessions, `~/Library/Application Support/NFS2015Mac`, `G/Store/nfs-2015` as a plain folder (only inside the NFS app).

## 7. Totals (logical)
Free space fell from 13 to 12 GiB during the survey (other workers active). In-scope under `G/` ~139 GiB at the start (≈115 GiB after the bundle stage was removed) + `D/` ~7.8 GiB + `~/Library` ~22 GiB + `~/.wine` 1 GiB + `/private/tmp` ~0.25 GiB. Largest: bf4-bundle-stage 24.45, bf4-run 23.49, NFSMW-tools 22.65,
wine-rebuild 19.57, ron-tools 16.85, Store 16.20, NFS2015Mac 17.2, wine-arm64 7.57. Real use is lower wherever prefixes and runtimes were cloned (bf4-run prefix,
bundle-stage prefix (likely), runtimes wine-0005..0011 (HANDOFF recommends `cp -cR`)); expected-real cannot be stated without an allocation-level measurement.
