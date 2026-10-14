> Historical snapshot (2026-10-15): branch names and paths below reflect the state when written and may no longer exist.

# Game Hub: one shared prefix, data-driven fixes, one runner (design, 2026-10-11)

Status: approved by the orchestrator for Stage 2-3. Supersedes per-game wrappers for new work (wrappers keep running as-is).
Principle (user): no scripts for running or fixing; fixes, runtime patches and games are DATA; one typed runner (HubCore) used by
the app and a `gamehub` CLI; nothing per-game in Swift (`GameKind` stays only as a shim for the legacy wrappers).

## 1. Decisions and evidence

| # | Decision | Evidence (seen 2026-10-11) |
|---|---|---|
| D1 | Shared prefix = the relocated BF3 prefix (promoted, not rebuilt). | EA signed in there; BF3 (`C:\Program Files\EA Games\Battlefield 3`), BF4 + Crysis 3 (`E:\EA Games\BF4\...`) registered under `Software\Wow6432Node\{EA Games,Crytek,Origin Games}`; no host paths (`/Users`, `BF3Mac`, `/Volumes`) in its .reg files; only `dosdevices/e:` -> `/Volumes/ExT2/GameHub` and `z:` -> `/` are absolute. A fresh prefix would need a new EA activation now; plan P7 (fresh prefix on the superset runtime) stays the long-term generation 1. |
| D2 | Runtime `hub-0` = byte clone of the BF3 bundle's `SharedSupport/Wine` at `/Volumes/ExT2/GameHub/Runtimes/hub-0`. | `cp -c -R`; 1,791 files, 1 symlink, sha256 + link + exec-bit manifests identical; manifest `hub-0.manifest` sha256 `278e1d9d...6a6f9f`; `wine.inf` mtime 1791413930 == prefix `.update-timestamp` (no wineboot update will run); dsound = wine-0011's (bf3-tuned). Same bytes the EA app was activated on: not a runtime swap. |
| D3 | Sidecar kept OUTSIDE the runtime: `Runtimes/hub-0-helpers/x87sidecar`, enabled per session via `ROSETTA_X87_PATH`. | Wine auto-enables `bin/x87sidecar` if present (plan P2 fact), which would remove the off switch. The bundle helper's sha256 `43ab085a...` differs from the pin `3ca9cc72...` in `runtime-inputs.json` (flagged, not fixed here). |
| D4 | Providers adopted IN PLACE first (no moves): Steam runs as `Z:\Volumes\ExT2\Steam\steam.exe`, Ubisoft as `Z:\Volumes\ExT2\Ubisoft Game Launcher\UbisoftConnect.exe`; Epic must be installed (no launcher on ExT2, only `EpicGamesStore/GTAV`). | Steam's own library record says `Z:\Volumes\ExT2\Steam` (3 `.acf`: 228980, 243470, 1359090); `z:` -> `/` exists in the prefix. The P8 rename + symlink remains an option, behind the dry-run gate. |
| D5 | Canonical prefix path `/Volumes/ExT2/GameHub/Prefix` reached by a gated same-volume rename + symlink at the old `Relocated/...` path; until approved, `hub.json` points at `Relocated/BF3Mac/Data/Prefix`. | Rename keeps the directory inode, so the wineserver socket (`/tmp/.wine-<uid>/server-<dev>-<ino>`) and the BF3 wrapper's symlink chain keep working. |
| D6 | `EACefSubProcess.exe` = wined3d (explicit rule); `EADesktop.exe` = DXMT. | STATUS-20261010: DXMT gives "cross-process swapchain not supported yet" (blank webview); the working `start-ea.sh` leaves it on the wined3d default. `Packaging/Recipes/bf3.json` still says dxmt (stale; recorded as a rejected fix). |
| D7 | Session environment is per provider start; games inherit it. A game whose session needs differ (NFS 2015: RWX on; BF: RWX off) requires a provider restart, offered, never automatic. | Unix env propagates to children (TF emulation reaches NFS16 via the EA app; OVERRIDES-MATRIX §5). |
| D8 | EA sign-in state is read from EA's own log (`DesktopFSM[...]: state changed: X -> Y`), never assumed and never from the telemetry `authenticated` flag; needsSignIn only when `-> awaitingAuthentication` is the latest transition for >= 20 s. | 09:55 UTC Crysis 3 failure: after `LaunchFailed (9)` EADesktop went to `awaitingAuthentication` (`authenticated:false`) 10 min after the wrapper showed "Signed in"; review: `awaitingAuthentication` is also a ~2 s startup transient and recovered by itself after 30 s; telemetry says `authenticated:false` even while the FSM is authenticated. |
| D10 | The compiled WINE_COMPATDB always ends with the total default `exe=*;d3d9=mtld3d;dxgi=dxmt`; explicit wined3d exceptions only for `EACefSubProcess.exe` and `EAGEP.exe`; every backend directory a rule names must exist in the pinned runtime (doctor + pre-launch check). | 2026-10-11 BF4: "Invalid license. Reason code = Missing DLL: [dxgi.dll] Error: 0x7E": the wrapper's rules had no default, so bf4.exe resolved dxgi to `lib/wine/dxgi/gptk`, absent in this runtime. With the generic dxmt default + the two exceptions BF4 passed the licence check (quote reported by the user from a dialog; not found in any log) and ran a ~77 s session (EA log game.sess.strt 10:00:59Z, game.sess.exit 10:02:16Z; exit cause unknown). |
| D9 | EA provider pre-warms `EAGEP.exe` and waits for `Client connected [EAGEP.exe]` before any EA game Play. | `EABackgroundService.log`: EAGEP started 09:55:34.7, "EAGEP didn't respond in time" 09:55:38.2, connected 09:55:39.1 (~1 s late). Review: 2 more timeouts (09:56:54, 10:00:49 never connected; EAGEP.exe.mdmp at 10:00:50Z, under wined3d), so pre-warm is experimental, bounded, fail-closed. |

## 2. Layout (H = /Volumes/ExT2/GameHub)

- `H/Hub/hub.json` (prefix path, runtime id, generation), `H/Hub/State/{session.json, leases/{game,provider-<id>}.json, ledger.jsonl, settings/<target>.json, runs/<target>.jsonl}`,
  `H/Hub/Logs/<target>-<yyyyMMdd-HHmmss>.log`, `H/Hub/Home/Player` (HOME; USER=Player as today), `H/Hub/Temp` (TMPDIR), `H/Hub/Knowledge/proposed/`.
- `H/Runtimes/hub-0{,.manifest,.manifest.links}`, `H/Runtimes/hub-0-helpers/x87sidecar`.
- Prefix (today `H/Relocated/BF3Mac/Data/Prefix`): `drive_c/Program Files/Electronic Arts/EA Desktop/<version folder>/EA Desktop/` (alias `13.805.99.0` kept),
  `E:` = H (EA library `E:\EA Games\...`), Steam/Ubisoft via `Z:` (D4), Epic to `C:\Program Files (x86)\Epic Games` when installed.
- Knowledge (in git, SwiftPM resource of HubCore): `Sources/HubCore/Knowledge/{knobs.json, capabilities.json, patches.json, runtimes/*.json, fixes/*.json, recipes/{providers,games}/*.json, rules/*.json, prerequisites.json}`.
  User-local additions/proposals only under `H/Hub/Knowledge` (never overrides a verified entry of the same id).

## 3. Data model (JSON, `schemaVersion: 1`, unknown keys rejected)

```
Capability   closed enum; names of the bundles' runtime-provenance.json kept: trapFlagEmulation, rosettaRwxWxEmulation, rosettaRwxWxPageLog,
             crashContextBlock, crashContextCodeWindows, rosettaPageExperiments, x87Sidecar, dxmtDXGI; added: compatdb, wined3dDXGI,
             mtld3dD3D9, mtld3dD3D8, dsoundSSE2, caseFoldCache, exeListSwitches (capabilities.json documents each)
RuntimeManifest { id, title, wineVersion, source:{origin, revision?, patchSeries:[patchId]}, manifestSHA256,
             keyFiles:{relPath: sha256}, capabilities:[{id, evidence:"file:<relPath>"|"knob:<NAME>"|"doc:<ref>"}], helpers:{x87sidecar:{path, sha256}} }
Patch        { id:"0001".., title, capability, branch|tag, commit?, status }                   (patches.json: the fork's series as data)
Predicate    { all:[Cond] } | { any:[Cond] };  Cond = { kind, value }, kind ∈ exe | exeSHA256 | machine(i386|x86_64) | imports(dll base name) |
             subsystem(gui|console) | marker(relative path under game root) | provider(ea|steam|epic|ubisoft|none) | runtimeHas(Capability) | target(id)
Action       (closed vocabulary, each validated against allow-lists; never shell text)
  env          { name, value, scope: session|prefixMachine }       name ∈ knobs.json; reserved prefixes WINE/DYLD_/LD_/ROSETTA/MTL_ need an explicit knob entry
  renderer     { exe, api: d3d8|d3d9|d3d10core|d3d11|dxgi, backend: dxmt|wined3d|mtld3d }   -> one WINE_COMPATDB rule (RendererSelection validates)
  dllOverride  { exe?, dll, mode: native,builtin|builtin|native|builtin,native|disabled }   exe -> HKCU AppDefaults\<exe>\DllOverrides; none -> WINEDLLOVERRIDES
  registry     { hive: user|machine, key, name, type: string|dword, value }   value may use placeholders; owner recorded in the ledger
  file         { asset (Knowledge-relative), destination ("{gameRoot}/mtld3d.conf"), sha256 }
  ini          { file ("{gameRoot}/x.ini"), section, key, value }                                (ConfigText)
  drive        { letter (d..y), target ("{hubRoot}"|"{gameRoot}") }
  arguments    { exe, append:[String] }      sidecar { enabled }      window { mode: virtualDesktop|retina, size?, enabled? }
  prerequisite { id }   id ∈ prerequisites.json (url, sha256, kind msi|exe, arch) e.g. wine-mono-10.4.1, wine-gecko-2.47.4
  companion    { exe, after: ready, readiness: Readiness }   (start a helper of the provider, e.g. EAGEP pre-warm)
Placeholders {prefix} {hubRoot} {gameRoot} {providerRoot} {eaClientDir} {offerIDs} {appID} — closed set, resolved by the plan compiler.
Fix          { id, title, reason, status: verified|experimental|rejected, evidence:[String], appliesWhen: Predicate, requires:[Capability],
               actions:[Action], parameters:[{ id, title, type: bool|choice|int|float, default, choices?, range?, binds: "actions[i].<field>" }] }
Readiness    { log (prefix-relative), startMarker?, events:[{ state, contains }], ports:[Int], timeoutSeconds }
Recipe       { id, kind: game|provider, title, status: verified|unverified|proposed, evidence:[String],
               provider?: ea|steam|epic|ubisoft|none, ids?: { eaOfferIDs:[String], steamAppID, epicAppName, ubisoftID },
               location: { windowsPath } | { registry:{ hive, key, name } } | { hostPath },
               executable, architecture: i386|x86_64, processes:[String], leaseTarget?, launchChain?:[String],
               launch: { method: direct|provider|browser|wrapper, executable?, arguments:[String], urlTemplate? },
               stop?: { arguments?:[String], taskkill:[String] }, readiness?: Readiness, fixes:[fixId], settings:[Setting],
               install?: { url, page, checksum: { policy: pinned|authenticode+record, sha256?, signer? }, command:[String] },
               legacyWrapper?: String }
Setting      { id, title, group, store: hub|ini|registry, file?, section?, key?, type, default, choices?, range? }  (hub = Hub launch setting)
LaunchPlan   (compiled, Codable, deterministic, printable by `gamehub plan <id> --json`)
             { target, runtime, prefix, executable (Windows path), arguments, environment:[String:String], compatdb, sessionProfile:[name:value],
               pendingActions:[Action+owner], warnings:[String], refusals:[String] }
Status       { target, state: notInstalled|stopped|starting|needsSignIn|ready|launching|running|stopping|failed|blocked, reason?, pid?, since?, log?, ports:{Int:Bool} }
Ledger line  { time, fix, target, action, before?, after, backup? }        (jsonl, append-only; revert replays `before`)
```

## 4. Runtime capabilities and patches

`hub-0` declares only what file or knob evidence shows (checked on load), seen 2026-10-11: trapFlagEmulation (knob WINE_TF_EMULATION in
ntdll.so + wineserver), rosettaRwxWxEmulation / rosettaRwxWxPageLog (WINE_RWX_WX_EMULATION / _LOG in ntdll.so), crashContextBlock,
crashContextCodeWindows, rosettaPageExperiments (provenance list), x87Sidecar (ROSETTA_X87_PATH in ntdll.so; helper outside the tree, D3),
compatdb (`lib/wine/x86_64-unix/compatdb.so`), dxmtDXGI (`lib/wine/dxgi/dxmt/*`, DXMT v0.80, also reads DXMT_METALFX_SPATIAL_SWAPCHAIN),
wined3dDXGI (`lib/wine/dxgi/wined3d/*`), mtld3dD3D9 (`lib/wine/d3d9/mtld3d/*`, reads MTLD3D_CONFIG), dsoundSSE2 (dsound.dll == wine-0011's).
Absent: mtld3dD3D8 (only Wine's builtin d3d8.dll), caseFoldCache, exeListSwitches (no WINE_X87_SIDECAR_EXCLUDE / WINE_FILE_ACCESS_LOG).
Patch series as data (patches.json): 0001-0004 = g-cqd/wine `development` 8ae3878, b9092a7, c2b2655, f7f4dfe; 0005-0010 = branch
`nfs2015-runtime-0010` (source archive HEAD be47ba54, provenance wine f064add9); 0011 = `nfs2015-runtime-0011` 71133b5 (dsound only).
A Fix whose `requires` is missing -> plan refusal for
`verified` fixes the target needs, warning for `experimental`. Runtime identity guard: the prefix records its runtime manifest digest in `hub.json`;
starting with any other digest is refused (EA activation rule). Key-file hashes are checked at every start; the full manifest by `gamehub doctor`.

## 5. Fix catalog (initial, all data)

ea-client-dxmt (EADesktop.exe dxgi=dxmt, verified) · ea-cef-wined3d (verified; supersedes bf3.json rule) · ea-helpers-dxmt (BF3WebHelper, EALaunchHelper
dxgi=dxmt, verified) · ea-gep-wined3d (EAGEP.exe dxgi=wined3d; experimental: starts faster, D9/D10) · ea-igoproxy-off (`IGOProxy32.exe` disabled, verified) · no-menubuilder (`winemenubuilder.exe` disabled, policy) ·
ea-in-process-gpu (arguments `--in-process-gpu`, verified) · tf-emulation (env WINE_TF_EMULATION=1, MAX_STEPS=0, MAX_NS=0; requires trapFlagEmulation) ·
rwx-emulation (env WINE_RWX_WX_EMULATION=1; target nfs2015; requires rosettaRwxWxEmulation; experimental) · x87-sidecar (sidecar on when machine=i386; parameter) ·
dx-games-dxmt (imports d3d11|dxgi|d3d10core -> dxgi=dxmt) · default-renderers (total default `exe=*;d3d9=mtld3d;dxgi=dxmt`, always last, D10) · bf3-d3d11-proxy (AppDefaults
bf3.exe d3d11=native,builtin + file shim, verified) · retina (window retina, prefix-wide, parameter) · metalfx-spatial (env DXMT_METALFX_SPATIAL_SWAPCHAIN,
DXMT_CONFIG factor parameter; experimental; "known to crash NFS16") · steamwebhelper-dxmt (experimental; RoN prototype) ·
ea-gep-prewarm (companion EAGEP.exe after ready, readiness `EABackgroundService.log` contains `Client connected [EAGEP.exe]`; experimental; evidence D9) ·
ea-client-paths-after-update (registry ClientPath/DesktopAppPath/ErrorReporterPath under `HKLM\Software\Electronic Arts\EA Desktop` and the
`origin2`/`link2ea` open commands -> `{eaClientDir}`; experimental; evidence "Failed to update registry keys, this may cause launch issues if there
was a recent update" in EADesktop.log; offline apply only, user-confirmed) · rejected: ea-cef-dxmt, d3dmetal-nfs16, steam-api-stub (kept as data, never applied).

## 6. Providers (recipes/providers/*.json)

| | EA app | Steam | Epic Games Launcher | Ubisoft Connect |
|---|---|---|---|---|
| Executable | registry `ClientPath` if the file exists, else newest real `<ver>\EA Desktop\EADesktop.exe` (`PreparedPrefixGame.isClientVersionFolder`) | `Z:\Volumes\ExT2\Steam\steam.exe` | `C:\Program Files (x86)\Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe` | `Z:\Volumes\ExT2\Ubisoft Game Launcher\UbisoftConnect.exe` |
| Arguments | `--in-process-gpu` | none | none | none |
| Game launch | `EALauncher.exe "origin2://game/launch/?offerIds={offerIDs}"` | `steam.exe steam://rungameid/{appID}` | `EpicGamesLauncher.exe "com.epicgames.launcher://apps/{appID}?action=launch&silent=true"` | `UbisoftConnect.exe uplay://launch/{appID}/0` |
| Readiness log | `ProgramData/EA Desktop/Logs/EADesktop.log` (+ EABackgroundService.log) | `<Steam>/logs/bootstrap_log.txt`, `connection_log.txt` | `users/crossover/AppData/Local/EpicGamesLauncher/Saved/Logs/EpicGamesLauncher.log` | `<Ubisoft>/logs/launcher_log.txt` |
| States | `[STARTUP]` -> starting; `login`, `client.boot.ready` -> ready; `awaitingAuthentication` -> needsSignIn; `LaunchFailed` -> failed | markers unverified (Stage 4 first run records them) | unverified | unverified |
| Ports | 3215 (HTTP), 3216 (LSX) | none required | none | none |
| Stop | `taskkill` EADesktop.exe, EACefSubProcess.exe, EABackgroundService.exe, EAGEP.exe; last provider -> `wineserver -k` | `steam.exe -shutdown`, then taskkill | taskkill | taskkill |
| Renderer | fixes above | steamwebhelper.exe dxgi=dxmt (experimental) | default | default |
| Install | present (pinned EA 13.805.2.6319 policy) | present (in place) | official MSI, Stage 4 | present; official installer re-run in place if registry absent (Stage 4) |

Offer IDs come from data: BF3 `70619,71067` (bf3.json, verified), NFS 2015 `1024486` (nfs2015.json, verified), BF4 `1007968` and Crysis 3 from
`Software\Wow6432Node\Origin Games\<id>` (discovered, unverified). EA games are discovered from `Software\Wow6432Node\{EA Games,Crytek}\<title>\Install Dir`.

## 7. HubCore types (new; Swift 6, Sendable values, typed throws `HubError`)

`HubPaths` (H, hub.json, state, logs, home, temp) · `SharedPrefix` (locate: resolve the symlink chain with lstat, every hop must stay under an allowed
root (`/Volumes/ExT2/GameHub`, `~/Library/Application Support/{BF3Mac,NFS2015Mac}`), owner = current uid, contains system.reg, user.reg, drive_c,
dosdevices; volume missing -> `.volumeMissing`, never creates directories; verify -> [Problem]; repair -> only recreates `dosdevices/c:` and declared
drive links, after a dry-run list) · `RuntimeManifest`/`RuntimeVerifier` · `Knowledge` (loads + validates all JSON, cross-references ids) ·
`Predicate`/`TargetFacts` · `Fix`/`FixAction` · `Recipe` · `PEScan` (bounded parser for untrusted bytes: machine, subsystem, sections, import DLL
names; markers) · `RecipeProposer` (rules -> draft recipe, status proposed) · `LaunchPlanCompiler` (recipe + fixes + runtime + settings -> LaunchPlan;
pure) · `CompatDB.render` (reuses `RendererSelection.validate/rule`; total default rule always last; <= 32 rules; backend dirs checked against the runtime) · `OverlayLedger`/`FixApplier` (FileTransaction,
offline registry via `RegistryHiveText.merged`, refuses while the wineserver runs, conflict = same key/name from two owners) · `Session` (one runner for
providers and games: `ProcessCommand`, leases, `SessionLock`, log tail readiness, port probes, Status) · `ProviderSession` = Session + provider rules.

## 8. Process model

One prefix, one runtime (hub-0), one wineserver. `session.json` records {runtime digest, sessionProfile, started providers}. A running wineserver
with no Hub `session.json` (e.g. the BF3 wrapper) -> every Start is `blocked("prefix in use by another app")`. Leases: one game per prefix
(`GameLease`), one per provider; a second game is refused. Environment = the sanitised set of `LaunchEnvironment.make` (HOME, USER=Player, LOGNAME,
TMPDIR, PATH, LANG, WINEPREFIX, WINEDEBUG=-all, WINEMSYNC=1, MTL_HUD_ENABLED=0, RUST_LOG) + WINEDLLOVERRIDES + WINE_COMPATDB (prefix-wide, all known
targets) + session env + optional ROSETTA_X87_PATH; nothing inherited from the Hub process. Golden test: the EA plan equals `start-ea.sh` (as of 2026-10-11) modulo
paths and RUST_LOG. Pre-launch: each rule's backend directory (`lib/wine/dxgi/<b>/{i386,x86_64}-windows`, `lib/wine/d3d9/<b>/...`) must exist in the runtime, else refusal. Children run detached from the app; logs go to `H/Hub/Logs`. All file and process work off the main actor.

## 9. Settings model

The settings page of a target (game or provider) is generated: Hub settings (renderer per exe from the backends its imports and the runtime allow;
x87 sidecar only when machine=i386; Retina (prefix-wide, says so); MetalFX only when runtime has dxmtDXGI and the exe imports dxgi) + fix
parameters + recipe file settings (ini/registry; first subset: NFS 2015 display settings once NFS is in the shared prefix). Values live in
`State/settings/<target>.json`; env/compatdb ones apply at next start ("restart provider to apply"); file/registry ones apply via FixApplier
(backups, ledger, offline only). Remaining wrapper pages (CoD4, Far Cry 2, Most Wanted full catalogs) are listed, not ported, in Stage 3.

## 10. CLI `gamehub` (product, shares HubCore; JSON with `--json`)

`status` · `plan <target>` · `run <target>` · `stop <target>|--all` · `fix list [--target]` · `fix apply|revert <id> --target <t>` ·
`scan <folder>` (PE scan + proposal) · `recipe list|show|promote <id>` (promote needs a recorded ok run) · `doctor` (prefix, symlinks, runtime
manifest, capabilities, knowledge validation, foreign wineserver) · `adopt --dry-run` (Stage 4). Replaces `GameHub/bin/start-ea.sh` (= `run ea`)
and `wine-query.sh` (= `doctor`/`status`); those scripts are retired (left in place, not used by anything).

## 11. Onboarding and NFS 2015

`scan <folder>` -> facts (PE + markers) -> rules -> draft recipe in `H/Hub/Knowledge/proposed` (status proposed); promotion to verified needs a
`runs/<id>.jsonl` record with outcome ok. NFS 2015 joins the EA app by: (gated) `cp -c -R` of its game folder from the NFS2015Mac prefix to
`H/EA Games/Need for Speed`, then the USER clicks "Locate game" in the EA app (an NFS activation for this prefix identity is expected).

## 12. Approval gates and user actions

Gated (dry run first): prefix rename to `H/Prefix`; NFS clone; any registry write to the signed-in prefix (`fix apply` of registry/AppDefaults
actions); installer runs (Epic, Ubisoft re-install, Steam bootstrap); P8 renames. User only: every sign-in, "Locate game", the first EA start
from the Hub on hub-0 (watch for an activation prompt).

## 13. Acceptance tests

Offline (Stage 5): all products build; `swift test` green; Knowledge validates; golden recipe test per existing game (CoD4, Most Wanted, Far Cry 2,
NFS 2015, BF3, BF4, Crysis 3, Morrowind, Rise of Nations, Steam/Epic/Ubisoft titles) compiles a plan with no refusal and no per-game Swift; golden
`plan ea|steam|epic|ubisoft` env + compatdb; validator mutation tests (each field corrupted -> rejected); PE fixtures (synthetic headers) for
scan rules; SharedPrefix: symlink chain ok, escaping symlink refused, loop refused, missing volume -> volumeMissing with no directory created;
foreign wineserver -> blocked (FakeWineServer); every compiled compatdb ends with the total default and names only backend dirs present in hub-0; second game refused; ledger revert restores bytes; `gamehub doctor --json` on the real Hub read-only.
With the user: EA start from Hub (no re-activation), EAGEP pre-warm then BF4 / Crysis 3 Play, needsSignIn shown after a session drop, Steam/Ubisoft
first start and sign-in, Epic install, NFS locate + 10 min drive, wrapper still working after the rename.

## 14. Risks

EA activation on any identity change (mitigated: identical runtime bytes, gated rename); EA session drops (D8); case-sensitive ExT2 lookups
(unmeasured, plan P1); Steam/Ubisoft first start in a new prefix self-updates their folders; z: exposes `/` to Windows programs; GTAV/BF1 anti-cheat
(recorded, never bypassed); sidecar pin mismatch (D3); compatdb rule-count limit unknown (capped at 32).

## 15. Review corrections (Sonnet, 2026-10-11) and the EA launch state machine

- Runtime identity: the BF3 wrapper/start-ea.sh run the bundle Wine on the same prefix; doctor checks bundle Wine manifest == hub-0 manifest, and the
  Hub refuses to start while a wineserver it did not start serves the prefix.
- Unplugged drive: pre-start check that every `dosdevices` target resolves; repair never creates a drive whose target is missing or on an unmounted volume;
  `driveUnreachable` is reported only. The resolved prefix must lie under the primary root `/Volumes/ExT2/GameHub`; `Prefix.internal-old-*` is never a target.
- DLL overrides: exe-less overrides only disable programs (`IGOProxy32.exe`, `winemenubuilder.exe`); everything else is `AppDefaults\<exe>` (Far Cry 2's
  dxgi/d3d10 disable can no longer leak into the EA session). New actions: `xmlAttribute` (FC2 GamerProfile.xml), `drive.lifetime` (CoD4 G: torn down at stop),
  per-exe `window.virtualDesktop` (RoN via AppDefaults Explorer). All file/registry/drive writes are offline-only (no wineserver running) and user-confirmed.
- Not yet expressible / deferred: NFSMW ASI bundle (assets not in this repo), RoN winegstreamer stub (SkipIntroMovies preferred), BF3 Battlelog browser block
  (BF3 uses the verified origin2 launch), Morrowind (refused until a runtime has mtld3dD3D8; Wine's builtin d3d8 is the experimental fallback).
  `Packaging/Recipes/bf3.json` (wrapper) is not edited; the conflict is recorded as the rejected fix `ea-cef-dxmt`.
- EA launch = data-driven `launchStages`, each with pass/fail probes, run by the one Session and printed by `gamehub doctor`:
  1 client: EADesktop.log `[STARTUP]`; 2 signedIn: `-> authenticated` latest (fail: `-> awaitingAuthentication` held 20 s => needsSignIn);
  3 services: ports 3215 and 3216 answer; 4 gep: EABackgroundService.log `Client connected [EAGEP.exe]` (only for EAGEP-launched games, bounded 30 s);
  5 launch: origin2 URL sent through EALauncher.exe with the client running and signed in (as StoreClientPlan does);
  6 session: `game.sess.strt` appears (fail: `LaunchFailed`, or process `ActivationUI.exe` present without the leaseTarget => "EA licence layer got no
  auth code", 2026-10-11 BF4 BFLauncher -> Core\ActivationUI.exe -> EALauncher/EALaunchHelper, no bf4.exe); 7 running: leaseTarget process present.
  Telemetry `criticalOffline:true` / `authenticated:false` on game-session events is recorded as a signal, never used to pass or fail. Never fake,
  stub or bypass EA's licence flow.

## 16. Layout update (2026-10-11, datastore reorganisation)

- D5 is done: the prefix is at `/Volumes/ExT2/GameHub/Prefix` and `Hub/hub.json` is written.
- D4 paths are now Steam `Z:\Volumes\ExT2\GameHub\Library\Steam\steam.exe` and Ubisoft `Z:\Volumes\ExT2\GameHub\Library\Ubisoft\UbisoftConnect.exe`. The old `Z:\Volumes\ExT2\...` paths still resolve through links; launch from the new ones. Epic GTAV is at `Library/Epic/GTAV`.
- §2 runtime: installed as `~/Applications/GameHub Runtime hub-0.app` (`Contents/SharedSupport/Wine` + `Contents/Helpers/x87sidecar`), located through the Hub settings (data store root + runtime app; Mac-local `settings.json`). See `docs/datastore-plan-20261011.md`.
