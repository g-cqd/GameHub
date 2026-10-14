# Knowledge index: where the knowledge lives, what is canonical, what is duplicated or stale

Survey 2026-10-09 (read-only). About 586 candidate docs under `Games/` after pruning vendored trees; the ones below carry the knowledge.
Prefixes as in the other files (`G/`, `D/`, `APP/` = `G/nfs-release/macos-app/`, `MW/`, `FC/`, `BF3B/`).

## 1. Canonical documents per topic

| Topic | Canonical doc | Size / date | Also in | Notes |
|---|---|---|---|---|
| NFS 2015 (root causes, settings, rejected approaches, editions, client layer, settings page, MetalFX) | `APP/docs/NFS2015.md` | 222 KB, 10-08 | g-cqd/nfs-macos `main` (`G/publish/nfs-macos/docs`), older copies in `FC/docs`, `MW/docs` (differ) | the single richest doc; §5 "Every setting, and why" and §6 "Tried and rejected" are the model for every game doc |
| NFS 2015 recipe | `APP/docs/NFS2015-RECIPE.md`, `NFS2015-HANDOFF.md` | 10-08 | publish, FC | |
| EA app layer | `APP/docs/EA-APP.md` + NFS2015.md §13.9-15 + `G/ea-helper/DESIGN.md` (**not in git**) + `G/bf4-tools/PLAN.md` (69 KB, **not in git**) | 10-08/09 | EA-APP.md copies in FC, MW (differ) | ClientUpdateDestaging, readiness, activation rule, offer ids |
| Wine runtime build and patch series | `G/wine-rebuild/HANDOFF.md` (46 KB, **not in git**) + `APP/Packaging/NFS2015Runtime/BUILD.md`, `NOTICE.md`, `patches/` | 10-08 | patch copies in rosetta3-wt (other session), pkg, publish | HANDOFF is the only place with build timings, pitfalls and per-runtime deltas |
| Runtime pins | `APP/Packaging/runtime-inputs.json`, `G/wine-rebuild/logs/runtime-000N-manifest-sha256.txt` | 10-08 | — | manifests not in git |
| Packaging / bundling | `APP/docs/BUNDLING.md`, `VERIFICATION.md`, `UPSTREAMS.md`, `DEVELOPER-HANDOFF.md`, `WORK-PLAN.md` | 10-08 | FC, MW copies (differ; MW has an uncommitted BUNDLING.md edit) | |
| BF3 | `G/bf4-run/bf3/NOTES.md`, `G/bf4-run/bf3/dx/FINDINGS.md`, `BF3B/README.md`, `BF3B/SOURCES.md` | 10-09 | NOTES = `BF3B/docs/NOTES-bf3-bringup.md`, FINDINGS = `BF3B/docs/FINDINGS-dxmt.md` (byte-identical) | BF3B/README.md is the most complete and newest; none is in git; **BF3B now exists only on mbp23** (`/Volumes/ExT2/Bundles/Battlefield3-Tuned-20261009`): the local stage was removed during this survey |
| Reports outside the repos | `~/Desktop/Games-inventory-20261008.md`, `mtld3d-state-report-20261002.md` (206 KB), `x87sidecar-state-report-20261002.md`, `mtld3d-x87-developer-handoff-20260927.md` | 09-27..10-08 | — | not in git; move to `docs/history/` |
| BF4 | `G/bf4-tools/PLAN.md`, `SUMMARY.md`, `SWIFT-MIRROR.md`, `G/bf4-run/README-OWNER.md` | 10-09 | — | not in git |
| CoD4 | `APP/docs/COD4.md`, `COD4-PLAN.md`, `G/CoD4-tools/README.md` | | FC, MW copies | |
| Far Cry 2 | `APP/docs/FARCRY2.md`; arm64 route `FC/docs/ARM64ROUTE.md` (**only in FarCry2-tools local-only commits**) | | FC | |
| NFS Most Wanted | `APP/docs/TUNING.md`, `G/NFSMW-tools/TASK-NOTES.md`, `MACOS-APP-PLAN.md`, `PERFORMANCE-INVESTIGATION.md`, `RENDERER-PLAN.md`, `XtendedInput.README.md`; `D/mtld3d/docs/NFSMW.md`, `D/x87sidecar/docs/NFSMW.md` | 09-26 | | NFSMW-tools docs are not in git |
| NFS 2015 EA lab | `G/NFSMW-tools/ea-app-lab/SETUP.md`, `PORTABLE-SETUP.md` | | | not in git |
| Morrowind | `G/Morrowind-tools/README.md`, `D/mtld3d-x87.md` §Morrowind | | | not in git |
| Rise of Nations / Steam layer | `G/ron-tools/INVESTIGATION.md`, `FULL-REQUIREMENTS.md`, `PERF.md` | 10-08 | — | not in git; FULL-REQUIREMENTS still mentions older runtimes |
| mtld3d | `D/mtld3d/README.md`, `docs/STATUS.md`, `GAMES.md`, `ARCHITECTURE.md`, `mtld3d.conf` (commented knob reference) | 10-02 | g-cqd/mtld3d | canonical (in git) |
| x87sidecar | `D/x87sidecar/README.md`, `docs/internals.md`, `docs/investigations` | 10-08 | g-cqd/x87sidecar | canonical (in git) |
| DXMT | upstream 3Shain/dxmt v0.80 (`G/mtld3d-test/dxmt-src/dxmt`), `APP/docs/METALFX-ROADMAP.md`, NFS2015.md §17, `BF3B/docs/FINDINGS-dxmt.md` | | | no consolidated DXMT doc exists |
| arm64-native Wine | `D/wine-arm64/docs/BRINGUP.md`, `SOURCES.md` | 10-08 | — | **no remote at all** |
| Cleanup history | `D/_archive/cleanup-20261008.md` (+ .jsonl), `D/_archive/records/*.json`, `~/Documents/NFS-backups/deleted-20261008.log` | 10-08 | — | keep as records |
| Early hand-offs | `D/games.md`, `D/mtld3d-x87.md` | 09-27 | — | **stale**: superseded by the docs above; still the only narrative of the first CoD4/Morrowind steps |

## 2. Duplicates

- Byte-identical: `G/bf4-run/bf3/NOTES.md` = `BF3B/docs/NOTES-bf3-bringup.md`; `G/bf4-run/bf3/dx/FINDINGS.md` = `BF3B/docs/FINDINGS-dxmt.md`; `G/publish/nfs-macos/README.md` = `G/wine-rebuild/pkg/README.md`.
- Same name, diverged content (6 macos-app trees: nfs-release, publish, FarCry2-tools, NFSMW-tools, nfs-firstrun, pkg): `BUNDLING.md`, `NFS2015.md`, `EA-APP.md`, `COD4.md`, `TUNING.md`, … Canonical = g-cqd/nfs-macos `main` (= `G/publish/nfs-macos`, = nfs-release minus the BF4 schema branch). The FC and MW copies are older forks of the same files, except `FC/docs/ARM64ROUTE.md` (unique).
- Knowledge duplicated **in code** (must collapse to one source in the bundler): NFS 2015 `WINEDLLOVERRIDES` (Swift + 2 Python tools), FC2 overrides (Swift + `Play_FarCry2.command`), `RUST_LOG` (3 places, 2 values), `gptk` denial (recipes.py + GameKind.swift, different wording), `WINE_TF_*` allow-list (4 places), MetalFX variable set (Swift + Python + gate), `WINE_RWX_WX_*`/`WINE_ROSETTA_*` names (2 Swift files + patch 0010), registry validation (recipes.py mirrors Swift RegistrySetting), import rules (recipes.py vs ImportRules.swift: already diverged on x86_64), store client (recipes.py vs StoreClientPlan.swift: diverged on offer lists).

## 3. Stale or conflicting statements to resolve during consolidation

| Statement | Where | Correct (per newer source) |
|---|---|---|
| "NFS2015 is served by D3DMetal" | `APP/Sources/LauncherCore/LaunchEnvironment.swift:94-95` (comment) | DXMT (`nfs2015.json:154-173`) |
| "Vulkan-backed DXGI" | `APP/Packaging/check_nfs2015_recipe.py:67` | DXMT (Metal) |
| x87 sidecar for NFS 2015: "stays in the bundle, not optional" vs "runs were without the sidecar" vs default off | NFS2015.md §7 (:289) vs Swift `NFS2015SidecarView.swift:18` | ships in the bundle, **off by default**, player-selectable |
| RoN window size 1024x768 vs 1280x960 | FULL-REQUIREMENTS.md:7 vs `ron-recipe-draft.json:33` | decide one (virtual desktop is 1280x960 in env) |
| Far Cry 2 Bundled app kept vs deleted | `phase2-manifest.md:33,40-41` vs `D/_archive/records/deleted.log:11-18` | mbp23 has `Far Cry 2 Bundled 20261002-845b6c9.app` (3.8 GiB): the app exists there |
| wine-0005..0008 described as current | NFS2015.md/BUNDLING.md (publish, nfs-release), HANDOFF.md, FULL-REQUIREMENTS.md, bf4-tools/PLAN.md | wine-0010 is the shipped pin; wine-0011 adds dsound only |
| BF3 dsound override "active" | early bf4-run notes | rejected (not mapped); BF3B replaces dsound in the runtime |
| Battlelog Windows-UA "unverified" | `bf4-run/bf3/NOTES.md:23-24` | verified later on Mac A (BF3B/README.md "Verified") |

## 4. Proposed single docs tree for the bundler

```
docs/
  README.md                 what the bundler is, the user-brings-own-data rule, how to read the rest
  runtime.md                Wine fork, patch series 0001-0011 (what/why/which game), runtime profiles + pins, build (from HANDOFF), known open Wine bugs
  renderers.md              DXMT / mtld3d / wined3d / D3DMetal: when each, knobs, known limits, MetalFX status
  x87sidecar.md             what it does, defaults per game class, knobs, the BF3 sound A/B open item
  ea-layer.md               EA app: install (Wine-Mono 1603), --in-process-gpu, origin2 URLs, offer ids, ports 3215/3216 (LSX),
                            readiness + ClientUpdateDestaging, Battlelog (Windows UA, Chromium, mixed content), Gecko/res://, ShellWindows,
                            client-layer cleaning policy, activation rule ("never swap runtimes under a signed-in prefix")
  steam-layer.md            RoN findings: steam_api soft-fail, steamwebhelper renderer rule, prefix isolation, what is refused (emulators, forged manifests)
  packaging.md              recipe schema reference (generated from the schema), gates, signing/quarantine, bundle layout, mbp23 transfer
  troubleshooting.md        symptom -> cause -> fix table (from every "tried and rejected" section)
  disk-and-clones.md        APFS clone rules, 15 GiB floor, /tmp is wiped, case-sensitive ExT2, Wine refuses /tmp prefixes
  games/
    nfs2015.md  nfsmw.md  cod4.md  farcry2.md  morrowind.md  rise-of-nations.md  battlefield3.md  battlefield4.md
                            each: status, recipe link, "every setting and why" table, "tried and rejected" table, open items, evidence index
  history/                  dated hand-offs kept verbatim (HANDOFF.md, games.md, mtld3d-x87.md, NOTES-bf3-bringup.md, cleanup records)
```

Rules: one fact in one place; game docs link to `runtime.md`/`ea-layer.md` for shared items instead of repeating them; every claim carries a status
(`verified`/`unverified`/`rejected`) and an evidence pointer; per-game docs that contain game-derived detail (offsets, hashes of game files, offer ids,
crash addresses) live in the **private** repo; the public repo carries only the generic layers (runtime, renderers, sidecar, packaging, troubleshooting).
