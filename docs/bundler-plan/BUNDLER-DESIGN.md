# A generic bundler: design

Status: proposal for the owner (2026-10-09). Nothing has been built or moved. Inputs: OVERRIDES-MATRIX.md, REPO-INVENTORY.md, KNOWLEDGE-INDEX.md.

## 1. Goal and non-goals

**Goal:** "bundle anything": given a Windows game folder the owner already has (or a store install the owner signs in to), produce a macOS app or
folder that runs it on Apple silicon through the pinned Wine/DXMT/mtld3d/x87sidecar stack, with every override declared in one recipe, every
recipe checked by gates, and new games starting from overrides **proposed automatically** from what the executables look like.

**Non-goals (kept as hard rules):** no redistribution of game data or store-client binaries (the user brings their own; "Bundled" editions are
personal-use builds that never leave the owner's Macs); no emulating, stubbing or forging EA/Steam services, tokens, activation or DRM
(NFS2015.md §6; ron-tools INVESTIGATION.md:15); nothing that touches anti-cheat or online play; no secrets in recipes, logs or repos.

## 2. Where it lives, name, visibility, licence

- **Evolve the existing repo, do not start a parallel one.** `g-cqd/nfs-macos` (public, **no LICENSE file today**) already has the recipe loader
  (`Packaging/recipes.py`), 20 gates, runtime pins and the Swift launcher with 5 recipes and delivered-build records. Proposal: rename it on GitHub to
  **`g-cqd/macos-game-bundler`** (GitHub keeps redirects; history, tags and the byte-identical regression baseline survive), with
  `G/nfs-release/macos-app` as the working clone (it is the canonical tree: GH `main` + the local-only `bf4-recipe-schema` branch).
- **Split public/private:**
  - public `macos-game-bundler`: engine (CLI + library + launcher), schema, gates, knowledge *rules* expressed generically (imports, machine
    type, client kind), docs `runtime.md`, `renderers.md`, `x87sidecar.md`, `packaging.md`, `troubleshooting.md`, `disk-and-clones.md`,
    synthetic test fixtures only.
  - private **`g-cqd/macos-game-bundler-recipes`** (new): per-game recipes and docs that carry game-derived detail (executable hashes, file
    inventories, offer ids, crash RVAs/addresses, EA payload hashes, Battlelog specifics), evidence logs, delivery records. The engine loads
    recipes from `--recipes <dir>`.
  - Note for the owner: today's public nfs-macos already contains game-derived detail (NFS 2015 executable hashes, offer id 1024486, crash RVAs
    in docs/NFS2015.md). Decide whether to leave it (history is public anyway) or move it forward-only.
- **Licences:** the engine should get an explicit licence (MIT or Apache-2.0; owner decides). Bundles redistribute or embed: Wine (LGPL-2.1+:
  each bundle must carry or point to corresponding source: today `wine-nfs2015-source-0010.tar.gz` with **no recorded digest**: add one),
  DXMT **v0.80 = MIT** (upstream `main` relicensed LGPL on 2026-04-25: pin v0.80 or ship LGPL source if upgrading), mtld3d (Zlib),
  x87sidecar (MIT; LICENSE copyright line reads "Lifeisawful": confirm attribution), Wine Gecko (MPL), Wine-Mono (MIT/LGPL mix). Shims written
  for a bundle (d3d11 proxy, shellwin, winegstreamer stub) need a licence header (proposal: same as the engine). `check_notice_licences.py`
  already enforces NOTICE ↔ licence files; extend it to shims.

## 3. Architecture

```
bundler (Python 3, stdlib only)            launcher (Swift, inside each app)
  recipe load + validate (recipes.py v2)     reads Resources/launch-plan.json (no recipe logic)
  knowledge: pe-scan + rules -> proposals    applies env / dll overrides / compat rule / prefix settings
  resolve -> launch-plan.json                client layer driver (EA readiness, origin2 URL, browser launch)
  assemble (app | folder layout)             settings page / presets / sidecar toggle
  gates (check_*.py)                         first-run import, clones, verification
  verify / sign / transfer (mbp23)
```

**Python for the bundler, Swift for the launcher**, because: the 20 gates, `recipes.py`, `build.py`, `runtime_inputs.py`, `nfs2015_metalfx.py`
and `pe_inventory.py` are Python today and run with no Xcode; the shipped launcher is Swift and must stay (it is the app). The defect today is
that **knowledge is duplicated between the two** (11 duplications listed in KNOWLEDGE-INDEX.md §2, two already diverged: `x86_64` import and
offer lists). Fix: the bundler compiles a recipe into a small, fully resolved `launch-plan.json` (per executable: env, WINEDLLOVERRIDES,
WINE_COMPATDB string, sidecar on/off, arguments, working dir, drive mappings; plus client-layer steps). The Swift launcher only parses and
applies it (one `Codable` struct, validated against `schema/launch-plan.schema.json`). `LaunchEnvironment.swift`'s per-game switch and
`GameKind.swift` denials move into recipes/knowledge. Swift keeps validation only for what the player can change at runtime (settings page,
MetalFX factor, sidecar toggle) using the same allow-lists exported by the bundler into the plan.

## 4. Recipe schema v2 (extends `Packaging/recipes.py`; additive, `schemaVersion: 2`, v1 recipes still load)

Kept as is (v1, `recipes.py:442-599`): `gameID`, `launcher`, `session`, `displayName`, `bundleIdentifier`, `bundleVersion`, `minimumMacOS`,
`category`, `runtimeProfile`, `supportsSP/MP`, `shaderCache`, `inputs` (with `{project}/{tools}/{games}/{home}/{store}`), `compatibility`, `defaults`,
`originalFiles`, `originalDirectories`, `executableHashes`, `inventorySHA256`, `editions`, `importRules`, `requiredRuntimeCapabilities`,
`runtimeRetention`, `vendorRuntimePaths`, `thirdPartyLicenses`, `runtimeTuning`, `referencesInstallation`, `storeClient`, `controllerDevices`,
`prefixSettings`, `bundledPrefixSettings`, `renderers`, `managedRuntime`, `clientLayer`, `runtimeSource`, `gameExecutable`, `deniedBackends`.
Merged from branch `bf4-recipe-schema` (b028857, e7e7a1b): `machine: x86_64`, `rootFiles`, `offerID` as list, `launchChain`, `leaseTarget`,
`expectedPorts` (the branch is currently checked out in `G/nfs-release/macos-app`) — **plus their Swift mirrors**, which the branch lacks
(`Sources/LauncherCore/ImportRules.swift:98` maps only `i386`; `StoreClientPlan.swift:91` accepts one decimal offer id; both confirmed).

New or generalised fields (every entry carries `reason`, `status` (`verified|unverified|experimental|rejected`), `evidence` (path or doc anchor)):

| Field | Shape | Replaces / generalises | Example |
|---|---|---|---|
| `runtimeProfile` | id in `runtime-inputs.json` (per-file sha256 pins; add `sourceTag` = g-cqd/wine tag, `sourceArchiveSHA256`) | v1 string | `nfs2015-tf-cx11-rebuild-0010-20261008`; new `wine-0010+dsound-0011` for BF3 |
| `renderers` | `[{exe, d3d8?, d3d9?, dxgi?, reason, status}]` compiled to `WINE_COMPATDB` | v1 renderers + `deniedBackends` + Swift default rule | `{exe:"bf3.exe", dxgi:"dxmt"}` |
| `environment` | `[{name, value, exe?, scope: process|prefixMachineEnv, reason, status}]`; names checked against the knob allow-list (`knowledge/knobs.json`), reserved prefixes need an allow-list entry | `runtimeTuning`, Swift `LaunchEnvironment`, BF `tune.sh` (machine env, because EA starts games with a clean env) | `WINE_TF_EMULATION=1`; `DXMT_CONFIG=…` scope prefixMachineEnv |
| `dllOverrides` | `[{dll, mode: "n,b"|"b"|"d"|"", exe?, reason}]` (compiled to WINEDLLOVERRIDES or AppDefaults registry) | Swift strings, BF3 AppDefaults reg | `dinput8=n,b`; `IGOProxy32.exe=d`; `d3d11=native,builtin` for bf3.exe |
| `shims` | `[{name, dest, arch: i686|x86_64, source: {repo, path, commit}, build: {toolchain: "llvm-mingw-<ver>", cmd}, sha256, licence, registry?: [...], disable: {env}}]` | ad-hoc files in bf4-run | d3d11 buffer-RTV proxy (`BF3_RTV_NOSHIM`), `shellwin.dll` + CLSID key, RoN `winegstreamer` stub |
| `sidecar` | `{default: on|off, playerSelectable, envOff}` | Swift per-kind logic, `COD4_X87`, `BF_SIDECAR` | NFS 2015 off/selectable; 32-bit games on |
| `clientLayer` | `{kind: none|ea|steam, install: {...managedRuntime, gecko}, start: {exe, args}, readiness: {ports, probes, tolerate: ["ClientUpdateDestaging"]}, session: {location: player, neverBundled: true}, activation: {neverSwapRuntimeUnderSession: true}}` | v1 `storeClient` + `clientLayer` + `managedRuntime` | EA: `EADesktop.exe --in-process-gpu`, ports 3215/3216 |
| `launch` | `{method: direct|storeURL|browser|helperChain, exe?, args?, url?, browser?: {kind: chromium, userAgent: "windows-x86", profile: "bundle"}, chain?: [...], leaseTarget?, virtualDesktop?: "1280x960", drives?: {"G:": "{game}"}}` | Swift sessions, `run-ea-bf3.sh`, `open-battlelog.sh`, RoN `explorer /desktop`, CoD4 G: drive | BF3: browser (Battlelog) -> `POST 127.0.0.1:3215/game/launch` |
| `presets` | `[{name: windowed|fullscreen|perf|…, file, format: ini|xml|reg|cfg|bf-profile, edits, needsGameClosed, status}]` | `settings.reg`, `config.cfg`, `GamerProfile.xml`, `rise2.ini`, `preset.sh` | BF3 `windowed` verified, `fullscreen` known-broken |
| `layout` | `app` (default) or `folder` (BF3-style self-contained folder with `bin/`, `lib/env.sh`, `prefix/`) | BF3 Tuned bundle | |
| `gates` | list of gate ids that must pass | implicit today | `["recipes","runtime_inputs","bundle_hygiene","client_layer"]` |
| `sources` | `[{component, licence, url, revision, sha256}]` emitted as SOURCES.md | BF3B/SOURCES.md, NOTICE.md | |
| `knowledge` | `{applied: [ruleId], suppressed: [{ruleId, reason}]}` | — | keeps proposals auditable |

Import vs bundled is unchanged: `editions` + `importRules` (+ `rootFiles`) describe what the user's own folder must contain; `originalFiles` /
`executableHashes` / `inventorySHA256` pin known builds; bundled editions are flagged `personalUseOnly: true` and `check_bundle_hygiene.py`
refuses to emit them into any publish path.

## 5. Knowledge layer (compatdb-like proposals)

`bundler scan <game-folder>` generalises `ron-tools/pe_inventory.py`: for every PE: machine (i386/AMD64), subsystem, imports (d3d8, d3d9,
d3d10*, d3d11, dxgi, dsound, xaudio2, dinput8, xinput, mfc*/msvcp*/vcruntime*, d3dx9_*, steam_api(64), EA/Origin DLLs, gstreamer/WM reader),
section names/entropy/size (UPX, `.bind` (Steam stub), very large high-entropy code + TLS callbacks = "protected", Denuvo-like), presence of
`steam_appid.txt`, `__Installer/installerdata.xml`, `Core/ActivationUI.exe`, PunkBuster, launcher/helper chains (strings). Output: `scan.json`.

`knowledge/rules/*.json` (in the public repo, generic): `{id, when: {predicates}, propose: {recipe fragment}, reason, status, evidence}`. Seed rules from the matrix:

| Rule | When | Proposes |
|---|---|---|
| `d3d9-mtld3d` | imports d3d9 | `renderers d3d9=mtld3d`, `WINEDLLPATH` mtld3d, mtld3d.conf defaults |
| `d3d8-mtld3d` | imports d3d8 | `dllOverrides d3d8=n,b` (Morrowind) |
| `d3d11-dxmt` | imports d3d11/dxgi | `renderers dxgi=dxmt`; `deniedBackends gptk` only with evidence |
| `d3d10-to-d3d9` | imports d3d10* and has a d3d9 path | disable d3d10*/dxgi, set game profile to d3d9 (FC2) |
| `x87-32bit` | machine i386 | `sidecar default on` |
| `amd64-nosidecar` | machine AMD64 | `sidecar off, selectable` |
| `debugreg-protection` | "protected" heuristic | runtime capability `tf-emulation`, `WINE_TF_*` = 0 budgets; `WINE_RWX_WX_EMULATION` as an experiment |
| `dsound-heavy` | imports dsound, 32-bit | runtime with patch 0011 |
| `ea-client` | EA installer data / ActivationUI | `clientLayer.kind=ea`, Wine-Mono, `--in-process-gpu`, `IGOProxy32.exe=d`, `winemenubuilder.exe=d`, EADesktop/EACefSubProcess dxmt, activation rule |
| `battlelog` | BF3/BF4 web-launch markers (`-webMode`, BFWebHelper) | `launch.method=browser`, Windows-x86 UA, Gecko + `res://`, ShellWindows shim |
| `steam-api-softfail` | imports steam_api | no stub; note soft-fail; optional `clientLayer.kind=steam` with steamwebhelper `dxgi=dxmt` |
| `wm-reader-movies` | imports WM reader / gstreamer paths | winegstreamer stub shim or skip-intro preset |
| `vc-redist` | imports mfc140/msvcp140 not in Wine | `managedRuntime` VC++ x86 (owner-supplied) |
| `mixed-content-loopback` | client uses http://127.0.0.1 from https | Chromium browser, not Safari |

Proposals are written to a **draft** recipe with `status: unverified`; nothing proposed is promoted without a recorded run. Rules never inspect or
store game content beyond headers/imports; `scan.json` stays in the private repo or the user's machine.

## 6. Bundle layout spec

`app` layout: `<Name>.app/Contents/{MacOS/<launcher>, Resources/{launch-plan.json, recipe.resolved.json, runtime/wine (pinned profile),
runtime/renderers, sidecar/x87sidecar, shims/, defaults/, licences/, SOURCES.md, NOTICE.md, MANIFEST.sha256}}`; player state under
`~/Library/Application Support/<bundle id>/{Data/Prefix, Saves, Logs, RuntimeHome}` (as the NFS apps do today); game data imported from the
user's folder by APFS clone, never copied into the signed app for import editions.
`folder` layout (EA/Battlelog games, as BF3B): `bin/{start-*.sh, open-*.sh, preset.sh, tune.sh, stop.sh, status.sh}`, `lib/env.sh` (generated from
the launch plan), `runtime/`, `prefix/` (cleaned by the client-layer policy: no sign-in, activation, browser cache, host certs, device enumeration,
fonts paths, saves), `browser-profile/` (created empty), `docs/` (README, SOURCES, licences, shim sources), `MANIFEST.sha256`,
`MANIFEST-DATA.txt` (+ top-N hashed), `MANIFEST-LINKS.txt`, `DIFF-vs-<runtime>.txt`.

## 7. Verification steps (bundler `verify`)

1. Runtime files vs `runtime-inputs.json` profile (sha256 per file) and `DIFF-vs-<profile>.txt` empty or explained.
2. `MANIFEST.sha256` over every non-game file; data manifest (size+path) and hashed sample; links manifest.
3. Gates listed in the recipe plus the always-on set (`check_recipes`, `check_runtime_inputs`, `check_bundle_hygiene`, `check_privacy`,
   `check_notice_licences`, `check_signing_policy`, `check_client_layer` when `kind != none`).
4. `codesign --verify --deep --strict` (Developer ID or ad hoc; Wine exception scoped as `check_signing_policy.py`), `spctl -a` where signed.
5. Quarantine: report `xattr -p com.apple.quarantine`; the README carries `xattr -dr com.apple.quarantine <bundle>`.
6. Secrets scan of everything that is not game data (tokens, AuthCode, cookies) — fail on hit.

## 8. mbp23 transfer helper (`bundler transfer`)

`rsync -a --partial --info=progress2` to `mbp23.local:/Volumes/ExT2/Bundles/<name>` (remote commands through `ssh mbp23.local '/bin/bash -s'`:
the login shell is fish); pre-check remote free space ≥ size × 1.1 (ExT2 has 381 GiB free; mbp23 `/` only 57 GiB); after copy, run
`shasum -a 256 -c MANIFEST.sha256` remotely and compare `MANIFEST-DATA.txt` sizes; warn that ExT2 is case-sensitive (copy to the internal disk to
play); never deletes on the remote; writes `transfer.log` with the verification result. The same helper with `--backup` copies preservation
sets to `/Volumes/ExT2/Backups/<date>-<name>` (used in DELETION-PROPOSAL stage 0).

## 9. Existing games -> recipes

| Game | Recipe today | Missing fields for v2 |
|---|---|---|
| NFS 2015 | `APP/Packaging/Recipes/nfs2015.json` (shipped) | `environment` (IGOProxy32/winemenubuilder now in Swift; RWX default-on in `NFS2015WineExperiments.swift`), `sidecar` (off, selectable), MetalFX knobs as `environment` with `status: experimental`, `clientLayer.readiness.tolerate ClientUpdateDestaging`, `runtimeSource` digest; optional wine-0011 profile |
| NFS Most Wanted | `nfsmw.json` (shipped) | `dllOverrides dinput8=n,b`, runtime profile `nfsmw-cursor` with its source tag, `presets` (settings.reg, SimRate 120), `mtld3d.conf` source path (currently from the built app) |
| CoD4 | `cod4.json` (shipped) | `launch.drives {"G:"}`, `sidecar` (on, `COD4_X87`), `presets` (config.cfg) |
| Far Cry 2 | `farcry2.json` (import), `farcry2-bundled.json` | `dllOverrides` d3d10*/dxgi disabled, `presets` (GamerProfile.xml d3d9), `launch.args --startup`; a gate for the bundled recipe |
| Morrowind | none (`Play_Morrowind.command`) | whole recipe: `dllOverrides d3d8=n,b`, mtld3d profile (4:3, DISCARD), LAVFilters as `managedRuntime`, presets |
| Rise of Nations | `G/ron-tools/ron-recipe-draft.json` (draft) | `launch.virtualDesktop`, `shims` winegstreamer stub (or preset SkipIntroMovies), `presets rise2.ini`, runtime with 0011, `clientLayer.kind` none (steam optional), prefix isolation of `users/crossover` symlinks |
| Battlefield 3 | none (scripts in `G/bf4-run/bf3`, `BF3B/bin`) | whole recipe: `layout folder`, EA `clientLayer`, `launch.method browser` (Battlelog), offer `DR:225064100`, `shims` d3d11 proxy + shellwin, Gecko 2.47.4 + `res://` key, runtime `wine-0010+dsound-0011`, `environment` (TF on, RWX off), `presets`, `tune.sh` as prefixMachineEnv |
| Battlefield 4 | `G/bf4-tools/bf4-recipe-candidate.json` | needs the v2 schema (offer list, launchChain, leaseTarget, expectedPorts, rootFiles, x86_64) + Swift mirror, ClientUpdateDestaging readiness, a first run |

## 10. Migration plan from the current repos (effort in working days)

| Phase | Work | Days |
|---|---|---|
| 0 | Preservation (DELETION-PROPOSAL stage 0): push/bundle local-only branches, copy unique non-git work to a git repo or mbp23 | 0.5 |
| 1 | Land `bf4-recipe-schema` + Swift mirrors; add `schemaVersion 2` loader (v1 compatible); JSON Schema generated from `recipes.py`; golden validation tests for the 5 shipped recipes | 2-3 |
| 2 | Launch-plan compiler; move LaunchEnvironment/GameKind/RuntimeTuning knowledge into recipes + `knowledge/knobs.json`; Swift reads `launch-plan.json`; golden test: compiled plans equal today's Swift-computed environments for all 5 recipes | 3-4 |
| 3 | `bundler scan` (from pe_inventory.py) + rules engine + seed rules; draft-recipe generator | 3 |
| 4 | Client layers: EA driver (readiness, ports, ClientUpdateDestaging, activation rule; from ea-helper DESIGN.md), Battlelog browser launch, Steam soft layer | 4-5 |
| 5 | Shims: sources into the private recipes repo (or public if generic), llvm-mingw build recipes, reproducible sha256 | 1-2 |
| 6 | `folder` layout, presets engine, verify, transfer helper | 2 |
| 7 | Port Morrowind, RoN, BF3 recipes; BF4 when the game runs | 3-4 |
| 8 | Docs consolidation into the tree in KNOWLEDGE-INDEX.md §4 | 2 |
| 9 | Deletion stages 1-3 with owner approval | 0.5 + owner time |
| | **Total** | **~21-26** |

## 11. Test strategy

- **Golden recipes:** the 5 shipped recipes + BF3/RoN/Morrowind drafts validate; mutation tests (already the style of `check_farcry2_recipe.py`) for every new field.
- **Precondition found in this survey:** `cod4.json:14-18` and `farcry2-bundled.json:17-21` read inputs from `{games}/release-build/…` and
  `{games}/tools-integrate/…`, which were deleted on 2026-10-07; `cod4.json:13` reads from `{home}/Library/Mobile Documents` (iCloud). Phase 1 must
  first re-create these inputs from the pins (renderer 7d108a4/845b6c9 builds, sidecar c396937) into a bundler-owned input cache, or the regression
  below is impossible for CoD4 and FC2-bundled.
- **Byte-identical regression for shipped NFS recipes:** rebuild NFS 2015 (-0010), NFSMW, CoD4, FC2 from the same pinned inputs and compare the
  resulting `MANIFEST.sha256` (excluding signature and timestamp files) with the delivered records in `D/_archive/records/*.json` and
  `release-build-delivered-manifest.json`; any byte change must be explained by a recipe diff.
- **Launch-plan snapshots:** compiled `launch-plan.json` per recipe checked in; diffs reviewed.
- **Knowledge rules:** synthetic PE fixtures (generated headers/import tables, no game bytes) for each predicate; scan of owned games runs locally only.
- **Smoke:** disposable prefix + test programs (the Wine fixture in patch 0004, dsound tests); **never** an EA sign-in or activation in tests.

## 12. What needs Wine/DXMT changes vs bundler only

Wine/runtime level: steamwebhelper renderer rule (`builtin.rs` gptk -> dxmt); 32-bit wined3d/DXGI fault at `ntdll+0x1123d`; ARM64 hardware
breakpoints (durable replacement for TF emulation); pin a 0011-based runtime profile (dsound) for every game; arm64-native route (wine-arm64)
remains a research branch. DXMT level: buffer render-target views (remove the BF3 proxy); MetalFX crash with NFS 2015; BF3 fullscreen (cause
unknown). Everything else (env, overrides, registry, shims, client handling, presets, layout, verification, transfer) is bundler-level.

## 13. Risks

EA activation burn on runtime swaps (rule enforced by the launcher: refuse to change the runtime of a prefix with a session unless confirmed);
Swift/Python drift (removed by the launch plan, guarded by snapshots); disk (13 GiB free now, builds need ~6 GiB; clones only); licence gaps
(no LICENSE on nfs-macos; Wine source archive without digest; DXMT relicensing); public leakage of game-derived data; EA client updates
(ClientUpdateDestaging) changing behaviour; BF3 bundle unverified on a fresh machine; heuristics misfiring (proposals only).

## 14. Owner decisions needed

1. Home: evolve/rename `g-cqd/nfs-macos` (recommended) vs new repo; name; licence for the engine.
2. Private recipes repo yes/no, and whether existing public game-derived detail stays.
3. Python bundler + Swift launcher with a compiled launch plan (recommended) vs all-Swift.
4. Runtime policy: move every recipe to a 0011-based profile (needs a new activation for EA games) or keep 0010 for EA games.
5. BF3 defaults: sidecar on (sound missing) vs off.
6. Which runtimes/prefixes to keep locally after preservation (see DELETION-PROPOSAL).
7. Whether "Bundled" (data-included) editions remain part of the tool (personal use) or only Import editions.
