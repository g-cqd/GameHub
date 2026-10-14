# Battlefield 4 on Apple Silicon: feasibility and plan

Planning document. Written 2026-10-09 by a read-only investigation session. **Nothing was
downloaded, installed, launched or signed into.** No EA account was touched. Every claim below is
labelled **[verified]** (with the file path or URL that proves it), **[inferred]** (a conclusion I
drew from verified facts) or **[unknown]** (needs an experiment or a public source I could not find).

**How to read the citations.** There are **two checkouts of the same docs/packaging tree** and they
are not the same working copy. Paths written bare — `Packaging/…`, `Sources/…`, `docs/NFS2015.md`,
`Package.swift`, `Evidence/…` — are relative to
**`/Users/gc/Developer/Games/nfs-release/macos-app/`**. Paths written with the `publish/nfs-macos/`
prefix are relative to **`/Users/gc/Developer/Games/`** and live in the public-repo clone, which
contains some files `nfs-release` does not (for example `docs/ROSETTA-SMC.md` and `docs/ARM64ROUTE.md`
exist only there). `Games/Store/…` and `Games/…` are relative to `/Users/gc/Developer/Games/`.
When the two trees hold the same file, they agreed everywhere I compared them.

Scope: reuse the Need for Speed (2015) wrapping method — a macOS `.app` that owns a Wine prefix,
installs the genuine EA app into it, lets the owner sign in once with their own account, and
launches the game the EA app installed — for Battlefield 4.

---

## 0. The one-line answer

The **EA client layer, the app skeleton, the recipe system and the packaging gates transfer almost
unchanged**. What does not transfer is everything below the client: BF4's main executable is
**x86_64** where every shipped recipe assumes i386, its renderer is **D3D11.1 through DXMT** where
NFS16 is the only D3D11 precedent and that one needed a custom Wine patch series, and its
multiplayer path runs through a **localhost HTTP helper** (`BF4WebHelper.exe`) that has no analogue
in any existing recipe. And before any of it: **there is no usable BF4 data anywhere** — the owner
must download ~32 GiB through their own EA account.

**Two facts set the odds.** In favour: BF4 is **ProtonDB Gold, trending Platinum, 347 reports** — the
game, the EA app and the DRM demonstrably all work under Wine on Linux, including multiplayer.
Against: every one of those reports runs the renderer through **DXVK/Vulkan**, while CodeWeavers'
own database rates BF4 **"Installs, Will Not Run"** on macOS. **The renderer is the one variable that
differs, and it is exactly the part of our stack with no evidence either way.** Everything else in
this plan is engineering; that one question is the project.

---

## (a) Map of every NFS2015 mechanism, and whether it transfers

| Mechanism | Where it lives | Transfers to BF4? |
|---|---|---|
| **App skeleton** (`Contents/MacOS/<launcher>`, `Helpers/<session>`, `Helpers/x87sidecar`, `Helpers/Rosetta Request.app`, `SharedSupport/Wine/`, `Resources/Game/`, `Resources/game-manifest.json`, `Resources/runtime-provenance.json`, `Resources/Defaults|Sources|Licenses/`) | `publish/nfs-macos/docs/BUNDLING.md` **[verified]** | **As is.** Nothing in the layout is game-specific. Wine must stay under `SharedSupport` (signing treats PE DLLs under `Frameworks` as native bundles) — same constraint. |
| **Immutable app + writable generations** (`~/Library/Application Support/<name>/Data/Versions`, `Data/Current` atomic pointer, `Data/Prefix`, `Data/Saves`; guest drive isolation, not App Sandbox) | `docs/BUNDLING.md` **[verified]** | **As is.** BF4 writes profile data under `Documents/Battlefield 4` on Windows **[unknown — not confirmed]**; the `Data/Saves` slot exists for it. |
| **Process lease + PID/kernel-start lock** (survives launcher exit) | `Sources/LauncherCore/GameLease.swift`, `GameLease+Active.swift`, `SessionLock.swift`, `ProcessIdentity.swift` **[verified]** | **As is**, but see the launch-chain change: BF4 is a three-process chain, so the lease must track the right PID (below). |
| **Swift target split**: `LauncherCore` (shared) → `<Game>Core` → `<Game>Launcher` + `<Game>Session` | `Package.swift` **[verified]**: products `NFS2015Launcher`/`NFS2015Session`, `CoD4*`, `FarCry2*`, `NFSMW*` | **With changes.** New `BF4Core`, `BF4Launcher`, `BF4Session` targets; everything in `LauncherCore` (57 files incl. `ClientLayer*.swift`, `StoreClientPlan.swift`, `GameInstaller.swift`, `ImportRules.swift`, `PortableExecutable.swift`, `RegistrySetting.swift`, `RendererSelection.swift`, `WineRuntime.swift`) is reusable. |
| **Settings** (a declarative catalog of keys → defaults, written into the game's own config) | `Sources/NFS2015Core/NFS2015Catalog.swift`, `NFS2015Catalog+Controls.swift`, `NFS2015Settings*.swift`, `NFS2015SettingsStore.swift`; gate `Packaging/check_nfs2015_settings.py` **[verified]** | **Pattern transfers, content does not.** NFS's 33 keys (`render.resolution` = `1920x1080`, `quality.texture` = `3`, `input.deadZoneSteering` = `0`, …) are NFS-specific. BF4's equivalent is its `PROFSAVE_profile` / `settings.ini` and the `GstRender.*` / `RenderDevice.*` console variables. The exact BF4 key names are **[unknown]**. |
| **Recipe/profile system** (`Packaging/Recipes/*.json`, schemaVersion 1; validated by `Packaging/recipes.py`, gated by `check_recipes.py`) | `Packaging/recipes.py` **[verified]** | **With changes** — see §(b) for the two schema blockers. The full key list is reproduced in `bf4-recipe-draft.json`. |
| **Runtime profile selection** (`runtimeProfile` string → `Packaging/runtime-inputs.json`, looked up by `runtime_inputs.verify_inputs`; refuses an unknown name, a `pending` profile, a profile pinning fewer than 5 artifacts, or a profile missing a `requiredRuntimeCapabilities` entry) | `Packaging/runtime_inputs.py:45-57`, `Packaging/runtime-inputs.json` **[verified]**. Names in use: `nfs2015-tf-cx11-rebuild-20261008`, then the `0005`, `0007`, `0008`, `0009`, `0010` variants (**there is no `0006` profile**, though `runtime/wine-0006` exists on disk); current recipe pins `nfs2015-tf-cx11-rebuild-0010-20261008`. Runtimes on disk: `wine-rebuild/runtime/{wine,wine-0005..wine-0011}` **[verified]** | **As is mechanically.** A **new** profile must be built and pinned (`bf4-…-00NN-YYYYMMDD`). Capabilities are a closed set: `{trapFlagEmulation, d3dmetalDXGI, dxmtDXGI, x87Sidecar}`. BF4 certainly needs `dxmtDXGI` **[inferred from its import table]**; whether it needs `trapFlagEmulation` is **[unknown]**. |
| **EA client layer — install into the prefix** | `Packaging/client_layer.py`: `CANONICAL_PACKAGE = 'windows/Installer/eaapp.msi'`, `EA_PROGRAMS = 'Program Files/Electronic Arts'`, `GAME_ROOT = 'Program Files/EA Games'`; capture tool `publish/nfs-macos/tools/capture-client-layer.py` (runs the signed EA installer with `/layout` to fetch the MSI offline, then `/quiet /norestart` with network denied); verifier `Packaging/check_client_layer.py`; Authenticode gate `Packaging/check_authenticode.py`; recipe block `clientLayer` pins `EAappInstaller.exe` + `EAapp-13.805.2.6319-15940128.msi` by SHA-256 and signer `Electronic Arts, Inc.` **[verified]** | **As is.** This layer is a property of the EA app, not of NFS. The same captured layer serves BF4. Re-capture only if the pinned client version is too old to see the BF4 entitlement **[unknown]**. |
| **Client layer classification** (keep/drop rules over files and registry so the packaged layer carries no account state): `F13`/`F15` keep rules, registry rule `R05` keeps the URL protocol handlers `eaconnect.microsoft|ealink|epic2ea|link2ea|luna2ea|origin|origin2|steam2ea`, `R08`/`R09`/`R12` keep the Installer product records, `R13`/`U02` drop Internet Settings and Wintrust | `Packaging/client_layer.py:99-149`, `Sources/LauncherCore/ClientLayerPolicy.swift:54,62-64` **[verified]**; gates `check_client_layer.py`, `check_bundle_hygiene.py` ("A bundled store-client edition packages exactly its pinned files and carries no account state") | **As is.** Unchanged by the game. |
| **Login handling / readiness detection** | `storeClient.readinessLog` = `ProgramData/EA Desktop/Logs/EADesktop.log`, `startMarker` = `[STARTUP]`, `readyEvents` = `["login","client.boot.ready"]`, `readinessSeconds` = 180, `signInEvidence` = `AppData/Local/Electronic Arts/EA Desktop`; reader `Sources/NFS2015Core/EAClientLog.swift`, `ClientInstaller.swift`; probe `publish/nfs-macos/tools/client-start-check.py` (also looks for `app.strt.ready`, `user.lgin.ckld`, `Login page load succeeded`, `Network service crashed`, `app.strt.fatal`, `offline`, `crash`) **[verified]** | **As is.** `EAClientLog.swift` should move from `NFS2015Core` into `LauncherCore` so `BF4Core` can use it without duplication. |
| **Session keep** (the client must stay alive while the game runs) | `storeClient` + `Sources/NFS2015Core/NFS2015Session.swift`, `NFS2015GameActivity.swift`; the client is a **hard dependency**: launched with no EA process, NFS16 exits `170` and spawns `Core/ActivationUI.exe` plus `EALauncher.exe` with an **empty** `authCode` | `docs/NFS2015.md:32`, `docs/NFS2015-RECIPE.md:12` **[verified]** | **Transfers in shape, details [unknown].** BF4 ships the *same* activation layer: `Core/Activation.dll`, `Core/Activation64.dll`, `Core/ActivationUI.exe` plus Qt 4 **[verified by `ls` on mbp23]**. So the same "client must be running" contract is very likely, but BF4's exit code and spawn behaviour are unmeasured. |
| **Client-update destaging loop — the known-broken one** | `docs/NFS2015.md:2279-2280, 2357-2358`, `publish/nfs-macos/docs/ROSETTA-SMC.md:101` **[verified]**: "the launcher treats the EA app's exit for `ClientUpdateDestaging` as a failed start and kills the session… it needs a new readiness rule with log fixtures and an unverified assumption (that `EADestager.exe` completes under this Wine)". Board item `wine-rebuild-028`. | **Transfers as the same open bug.** It is a client-layer defect, so BF4 inherits it. Fixing it once helps both. This is on the critical path for BF4 because a fresh BF4 download *starts* with a client that may want to self-update. |
| **ActivationUI** | recipe pins `Core/ActivationUI.exe` by hash; `check_nfs2015_recipe.py:25-26` requires it in the pinned set; it is `PE32 Intel 80386` for NFS (`docs/NFS2015.md:308`) **[verified]** | **As is.** BF4's `Core/ActivationUI.exe` is `i386 PE32` too **[verified]** — so the 32-bit path (and therefore possibly the x87 sidecar) is still needed even though the game is 64-bit. |
| **Launch via `origin2://` URL vs direct exe** | `storeClient.launchURL = "origin2://game/launch/?offerIds={offer}"`, `offerID = "1024486"`; validator requires the URL to contain `{offer}` and start with `origin2://` or `link2ea://` (`Packaging/recipes.py:127`); substitution in `Sources/LauncherCore/StoreClientPlan.swift:62` (`replacingOccurrences(of: "{offer}", with: offerID)`), prefix check at `:86` **[verified]**. NFS's own id `1024486` was read from `ProgramData/Origin/Logs/NFS16_1024486_OnlineActivation_Log.html` **[verified in `docs/NFS2015-RECIPE.md:43-44`]** | **Mechanism as is. The value is now strongly corroborated — see the box below.** A `{offer}` slot of 20 ids will blow the validator's `offerID` rule (1–20 **digits**), so `recipes.py` needs a list-valued `offerID` or a longer bound. |
| **Direct-exe launch path** | `tools/client-start-check.py:103-106` launches `wine explorer /desktop=EA,900x700 <exe> --in-process-gpu` **[verified]** | **With a change.** NFS16 is launched by the EA app. For BF4 the manifest's two launchers are `BFLauncher.exe` (x64) and `BFLauncher_x86.exe`, resolved through `[HKLM\SOFTWARE\EA Games\Battlefield 4\Install Dir]`, with **empty `<parameters>`** **[verified from `installerdata.xml`]** — so the EA app runs `BFLauncher.exe`, not `bf4.exe`. The launch chain is three deep (below). |
| **Import vs Bundled** | `EDITIONS = {'bundled','import'}` (`Packaging/recipes.py:18`); `editions` must be a non-empty subset; CLI `build.py --game-data {bundled,import}`; `referencesInstallation: true` means the import edition ships **no game bytes** and declares recognition/launch rules instead, copied into `game-manifest.json`; the bundled edition must pin the executable, `inventorySHA256` and the `game` input, and writes `bundledPrefixSettings`; selection logic `Packaging/game_data.py:20-29`, `assemble.py:46-51`; gates `check_game_data.py`, `check_assembly.py`, `check_bundle_hygiene.py` **[verified]** | **As is.** Start **import-only** for BF4 (like `farcry2.json`). A 32 GiB bundled edition is a separate decision. |
| **`{store}` placeholder** | `Games/Store/README.md`: "Recipes read it through the `{store}` placeholder (default `<Games>/Store`, override with `NFS_MACOS_STORE`)"; ids `nfs-2015`, `nfs-mw`, `cod4`, `farcry2`, `morrowind`, `rise-of-nations`; old paths are symlinks into it **[verified]** | **As is.** Add a `bf4` row (§c). Note `cod4`, `farcry2`, `nfs-mw`, `Morrowind` are currently **moved to mbp23** and hold only `MOVED.txt` **[verified]** — the store is already short of space. |
| **host-4k display rule** | There is **no literal `host-4k`** anywhere in `Packaging/` or `Sources/` **[verified by grep]**. The mechanism is `Sources/NFS2015Core/NFS2015DisplayFacts.swift`, `NFS2015DisplaySafety.swift`, `NFS2015SystemDisplay.swift`, `NFS2015FirstRunOptions.swift` plus the `prefixSettings` entry `HKCU\Software\Wine\Mac Driver\RetinaMode = "Y"`. The rule (`docs/NFS2015.md:1791-1805`): cap at 3840x2160, and for a 4K screen pick 2560x1440 with full-screen **off**. | **Pattern transfers, numbers do not.** BF4 has its own resolution list and its own full-screen behaviour; the RetinaMode registry entry and the "advertise the native panel" reasoning carry over **[inferred]**. |
| **Crash-report parsers** | `Sources/NFS2015Core/`: `NFS2015CrashReport.swift`, `NFS2015CrashBlock.swift`, `NFS2015CrashBlock+Report.swift`, `NFS2015CrashPages.swift`, `NFS2015CrashReportStore.swift`, `NFS2015FaultAnalysis.swift`, `NFS2015LogDigest.swift`, `NFS2015RwxLog.swift`, `NFS2015RwxPageLog*.swift`, and `Sources/NFS2015Session/NFS2015CrashMonitor.swift`. Types: `NFS2015CrashContext`, `NFS2015CrashBlockReader`, `NFS2015FaultLine.parse()`, `NFS2015FaultFinding`, `NFS2015CrashNotice`, `NFS2015CrashPages.{Query,Info,Checksum,ReturnCandidate,CodeRow,UnreadableRange,CodeWindow}` **[verified]** | **Mostly transfers, with work.** The Wine fault-line parser, the crash-block reader and the store are generic and should move to `LauncherCore`. But `NFS2015CrashBlock.Architecture` and the RWX/W^X page logging exist because NFS16 is a 32-bit self-modifying binary needing trap-flag emulation. A 64-bit BF4 crash has a different register set and probably no W^X story **[inferred]**. |
| **Gates / audit / clean-room scripts** | `Packaging/audit.py` + 19 `check_*.py` (full list with purposes below) **[verified]** | **Mostly as is.** Generic: `audit`, `check_app_archive`, `check_assembly`, `check_authenticode`, `check_bundle_hygiene`, `check_client_layer`, `check_game_data`, `check_notice_licences`, `check_privacy`, `check_recipes`, `check_runtime_inputs`, `check_runtime_optimization`, `check_shader_cache`, `check_signing_policy`. Game-specific, need BF4 analogues: `check_nfs2015_recipe`, `check_nfs2015_settings`, `check_nfs2015_metalfx`, `check_cod4_data`, `check_farcry2_recipe`, `check_widescreen_compat`. |
| **Privacy / signing policy** | `check_privacy.py` ("Every app declares the privacy usage Wine can trigger"), `check_signing_policy.py` ("Distribution signing accepts Developer ID and scopes Wine's memory exception"), `Evidence/signing-nfs2015.json` **[verified]** | **As is.** BF4 additionally wants **network server** behaviour (`BF4WebHelper` binds a socket) and a microphone (VOIP) — the privacy declaration may need entries NFS did not **[inferred]**. |
| **MetalFX** | `Packaging/nfs2015_metalfx.py`, `check_nfs2015_metalfx.py` ("can emit only options DXMT documents, and only for the game"), `Sources/NFS2015Core/NFS2015MetalFX*.swift`; roadmap `docs/METALFX-ROADMAP.md` | **Transfers in principle** — it is a DXMT feature, scoped per executable. Needs a BF4-scoped gate. **[inferred]** |
| **x87 sidecar / Rosetta request** | `Helpers/x87sidecar`, `Helpers/Rosetta Request.app`, `Packaging/rosetta_request.py`, `Sources/SharedLauncher/Rosetta*.swift`, `docs/ROSETTA-SMC.md`; `docs/NFS2015.md:1993` names `ActivationUI.exe` as one of the programs the sidecar exists for | **Keep it.** Even with a 64-bit game, BF4's `ActivationUI.exe`, `BF4WebHelper.exe`, `BFLauncher_x86.exe` and `bf4_x86.exe` are all i386 **[verified]**. |
| **Wine version reporting** | `"Version"="win10"` in `Packaging/settings.reg:53`, `CoD4Defaults/settings.reg:7`, `FarCry2Defaults/settings.reg:7`, and the client-layer fixtures `check_client_layer.py:20-21` **[verified]**; the rebuilt runtime reports `Microsoft Windows 10.0.19045` (`wine-rebuild/HANDOFF.md`) **[verified]** | **As is, probably.** BF4's manifest declares `osMinVersion="6.0"` (Windows Vista) and `osReqs64Bit="false"` **[verified]**, so win10 is comfortably above the floor. No BF4-specific winver requirement is known **[unknown]**. |

### Full gate list (from each script's docstring) **[verified]**

`audit.py` verify the relocated artifact without launching · `check_app_archive` ZIP64 retains bytes/modes/links · `check_assembly` import mode retains compatibility files, never mutates input · `check_authenticode` accepts the genuine EA installer, rejects tampered input · `check_bundle_hygiene` bundled store-client edition ships exactly its pinned files and no account state · `check_client_layer` classification, determinism, tamper detection, registry merge · `check_cod4_data` payload excludes player state · `check_farcry2_recipe` import-only, ships no game bytes · `check_game_data` runtime-only package keeps fixes and complete import inventory · `check_nfs2015_metalfx` only DXMT-documented options, only for the game · `check_nfs2015_recipe` import ships no game bytes; bundled pinned file by file · `check_nfs2015_settings` settings page cannot reach the binary options blob · `check_notice_licences` every NOTICE.md component has its licence file · `check_privacy` every app declares the privacy usage Wine can trigger · `check_recipes` rejects unsafe paths, duplicate destinations, ambiguous payloads · `check_runtime_inputs` rejects unpinned artifacts, records source revisions · `check_runtime_optimization` stripping preserves bytes/dirs/Wine marker · `check_shader_cache` cache key tracks mtld3d emitter inputs, only for opted-in recipes · `check_signing_policy` Developer ID, scoped Wine memory exception · `check_widescreen_compat` light streaks must not invalidate the resolution hook.

---

## (b) What BF4 needs that NFS16 did not

All binary facts in this section were read **read-only** from `/Volumes/ExT2/EA Games/Battlefield 4`
on mbp23. **Important correction to the earlier finding:** the `.cas` data files are sparse zeros,
but **the executables are real, complete PE images** — `bf4.exe_DiP_Staged` begins `4d 5a 90 00`
(`MZ`) and occupies 39,476 KiB of its 40,419,608 logical bytes. So the binaries could be inspected;
the game data could not. Totals re-measured: **3,165 files, ~1.14 GiB allocated** (`du -sk`), against
~32.4 GiB logical.

### b.1 The main executable is 64-bit — and the schema forbids that

| Binary | Machine | Imports (from its import directory) |
|---|---|---|
| `bf4.exe` (40,419,608 B) | **x86_64, PE32+** | `d3d11.dll`, `dxgi.dll`, `DINPUT8.dll`, `XINPUT9_1_0.dll`, `MSVCR110.dll`, `MSVCP110.dll`, `nvapi64.dll` |
| `bf4_x86.exe` (31,265,048 B) | i386, PE32 | same, with `nvapi.dll` |
| `BFLauncher.exe` (183,576 B) | x86_64, PE32+ | only `MSVCR110.dll`, `MSVCP110.dll` |
| `BFLauncher_x86.exe` (181,528 B) | i386, PE32 | same |
| `BF4WebHelper.exe` (624,408 B) | **i386, PE32** | — |
| `BF4X86WebHelper.exe` (624,408 B) | i386, PE32 | — |
| `EAWebKit64.dll` (13,232,920 B) | x86_64, PE32+ | `EAWebkit.dll` |
| `d3dcompiler_46.dll` (3,864,344 B) | x86_64, PE32+ | `d3d10.dll`, `D3DCOMPILER_46.dll` |
| `Core/ActivationUI.exe` (2,022,408 B) | i386, PE32 | (EA activation UI, as in NFS) |

All **[verified]** by reading the PE headers and scanning for import-table DLL names.

**Blocker 1 — `importRules.machine`.** `Packaging/recipes.py` validates `machine` against the single
literal `'i386'` **[verified]**. `farcry2.json` sets `"machine": "i386"` for `bin/FarCry2.exe`. BF4's
import executable is x86_64. `recipes.py` must be extended to accept `'x86_64'`, and
`Sources/LauncherCore/PortableExecutable.swift` + `ImportRules.swift` must agree. This is a small,
well-scoped code change, but it is a **hard blocker**: no BF4 import recipe can validate without it.

**Blocker 2 — `GAME_EXECUTABLES` and `DENIED_BACKENDS`** in `recipes.py` are keyed `{'nfs2015': …}`
only **[verified]**; both need a `bf4` entry.

**`bf4_x86.exe` is a real but degraded configuration.** The manifest declares a full second launcher
(`uid 2-2`, `requires64BitOS 0`) **[verified]**, and Origin exposed an architecture toggle under the
game's properties. But community reports say the 32-bit build **locks or limits in-game graphics
options** and performs markedly worse —
<https://forums.tomshardware.com/threads/battlefield-4-x86.1547383/>,
<https://steamcommunity.com/app/1238860/discussions/0/2798376797407289632/> (**forum anecdote**).
So it is a **fallback, not a co-equal target**: it keeps the project alive if the 64-bit path fails,
at a real cost in quality. Same renderer, so **the same DXMT questions still apply** — it buys
32-bit tooling compatibility, not an easier renderer. (One low-quality file-ID aggregator labels
`bf4_x86.exe` as "Battlelog Web Plugins"; that is almost certainly a VERSIONINFO product-grouping
string, and I could not corroborate it — **disregard**.)

> ### The offer id is very probably already in hand
> The Lutris issue tracker records BF4's working EA app launch URL as
> `origin2://game/launch/?offerIds=1007968,1011575,1011576,1011577,1010268,1010269,1010270,1010271,1010958,1010959,1010960,1010961,1007077,1016751,1016757,1016754,1015365,1015364,1015363,1015362`
> — <https://github.com/lutris/lutris/issues/4996>. **That is character-for-character the same
> 20-item list, in the same order, as the `<contentIDs>` block I read out of the owner's own
> `__Installer/installerdata.xml` on mbp23.** Two wholly independent sources agreeing on 20
> nine-digit numbers in one order is not coincidence.
> **[inferred, strongly corroborated — not verified]**: for BF4 the manifest's `contentID`s are very
> probably the `offerIds`, and the whole comma-joined list is passed, not just the base id `1007968`.
> Two independent sources agreeing is strong evidence about the *ids*; it is **not** a confirmed
> observation of the EA app's own behaviour, which only E2 can give.
> EA forum guidance also says to read `__Installer\installerdata.xml` to find a game's ids
> (<https://forums.ea.com/discussions/ea-play-general-discussion-en/launch-ea-game-using-command/7575680>,
> community reliability). Still confirm against the owner's own EA app log in E2 — the owner may not
> own all 19 DLC entitlements, and passing an unowned id may fail.
> **Caveat**: an EA community rep stated the scheme "doesn't seem to be a feature that is supported by
> the EA app at the moment" (<https://forums.ea.com/discussions/ea-app-general-discussion-en/ea-app-launch-urls/7547106>,
> EA-staff forum reply) — unsupported, not non-functional. Our NFS recipe uses it successfully.

### b.2 The launch chain is three processes, not one

**[verified]** from the shipped binaries and `installerdata.xml`:

```
EA app  --(origin2:// offerId)-->  BFLauncher.exe          (x86_64)
                                     | ShellExecuteExA, strings: "-forceBattlelog",
                                     |   "BF4WebHelper.exe", "EALaunchEnv"
                                     v
                                   BF4WebHelper.exe        (i386)  <-- a local HTTP SERVER
                                     | strings: "http::server::server::server",
                                     |   full HTTP/1.0 status-line table,
                                     |   "Access-Control-Allow-Origin",
                                     |   "CreateIoCompletionPort", "bf4.exe"
                                     |   PDB: C:\programming\work\webplugins\esnlaunch\Release\BF4WebHelper.pdb
                                     |   env: BFWEBHELPER_{DEBUG,TEST_MODE,SHOW_MESSAGE,
                                     |        ALWAYS_ACTIVATE,IGNORE_ORIGIN_HEADER,WAIT_ON_EXIT}
                                     v
                                   bf4.exe                 (x86_64)
                                     strings: "-webmode sparta -requestState State_Sparta",
                                     "Client.ServerIp", "receive.keeper.battlelog.com"
```

This is the **single biggest structural difference from NFS2015**, which is a one-process launch.
Consequences:

- The **process lease** must decide which PID it owns. `BFLauncher.exe` almost certainly exits
  immediately after `ShellExecuteExA` **[inferred]**, so the lease must follow to `bf4.exe`.
  `GameLease+Active.swift` currently expects one stable PID.
- `BF4WebHelper.exe` **binds a TCP socket**. Which port, and whether it binds `127.0.0.1` only, is
  **[unknown]** — needs an experiment (E5).
- The helper is the **modern replacement for the dead NPAPI browser plugin**: the browser's
  JavaScript does a cross-origin HTTP request to the local helper, which launches the game. That is
  why `Access-Control-Allow-Origin` and `BFWEBHELPER_IGNORE_ORIGIN_HEADER` exist **[inferred, but
  strongly supported by the string evidence]**.
- `__Installer/customcomponent/webplugin/battlelog-web-plugins.exe` (3,819,328 B) **[verified]** is a
  separate browser-plugin installer. Its strings show only `GetFileVersionInfo*`, `GetVersion`,
  `VERSION.dll`, `Software\Microsoft\Windows\CurrentVersion` — a version-checking stub. Whether it is
  needed at all in 2026 is **[unknown]**, and probably not (see b.5).

### b.3 Prerequisites `__Installer` declares, and what Wine must supply

`__Installer/installerdata.xml` (268 lines, `DiPManifest version="4.0"`, generated by
`EAInstaller-4.05.02.00`, `gameVersion 1.8.2.48475`) **[verified]**:

| Component | Files | Status under Wine |
|---|---|---|
| **VC++ 2012 Update 3** (`-Req:vc2012Update3`, declared installedSize 39,636,173) | `__Installer/vc/vc2012Update3/redist/vcredist_x64.exe` (7,185,000 B), `vcredist_x86.exe` (6,552,288 B) | **Hard requirement**: `bf4.exe` imports `MSVCR110.dll` + `MSVCP110.dll`. Must be installed into the prefix (Wine does not ship MSVC runtimes). **[verified requirement, [unknown] whether the redist installer runs under this Wine]** |
| **DirectX June 2010 redist** (`-Req:directx`, installedSize 144,378,352) | `__Installer/directx/redist/DXSETUP.exe` (517,976 B) + `DSETUP.dll` + `dsetup32.dll` + **159 `.cab`** | Supplies D3DX/XAudio2/XACT/X3DAudio. `d3dcompiler_46.dll` already ships in the game folder. **[unknown]** whether BF4 needs any of the redist at runtime given it imports neither D3DX nor XAudio directly — but `DXSETUP` is what EA's Touchup runs. |
| **PunkBuster — OPTIONAL** (`-Opt:InstallPB`) | `__Installer/punkbuster/redist/pbsvc.exe` (3,894,632 B), self-described `PunkBuster Service Installation Program` | **Verbatim from the manifest:** "Punkbuster is an anti-cheat system required by ranked servers" / cancel warning "You need to have PunkBuster installed in order to play online on ranked servers. Are you sure you want to skip installation of PunkBuster?" So it is **skippable**, at the cost of ranked servers. **[verified]** |
| **GDFBinary** | `__Installer/GDFBinary_en_US.dll`, `GDFBinary_en_US_64.dll` (339,224 B each) | Windows Games Explorer metadata. **Cosmetic**; Wine has no Games Explorer. **[inferred]** |
| **Touchup** | `__Installer/touchup.exe` (937,952 B) + `Touchup.dat` | Invoked by the manifest as `install -locale {locale} -installPath "{installLocation}" -autologging`; update variant adds `-update`, repair variant adds `-repair`. `featureFlags` set `forceTouchupInstallerAfterUpdate="1"` and `treatUpdatesAsMandatory="1"`. **[verified]** — so Touchup **will** run, and it must survive Wine. NFS's recipe already pins `__Installer/Touchup.exe` and `docs/NFS2015.md:486` records "a successful touchup" for NFS, which is encouraging **[verified]**. |
| **Cleanup** | `__Installer/Cleanup.exe` (935,904 B) + `Cleanup.dat` | Uninstall path; not needed. |

Manifest facts worth keeping: `requirements osMinVersion="6.0" osReqs64Bit="false"`;
`featureFlags … enableOriginInGameAPI="0" autoUpdateEnabled="1" enableDifferentialUpdate="1"
dynamicContentSupportEnabled="0" allowMultipleInstances="0"`; uninstall GUID
`{ABADE36E-EC37-413B-8179-B432AD3FACE7}`; 20 `contentID`s (base `1007968`, plus 19 DLC/expansion ids);
install manifest at `/Support/mnfst.txt`; 12 locales. All **[verified]**.
`enableOriginInGameAPI="0"` is good news: **no Origin overlay to fight** **[inferred]**.

### b.4 EAWebKit inside the game

BF4 ships **both** `EAWebKit.dll` (9,676,568 B, i386) and `EAWebKit64.dll` (13,232,920 B, x86_64,
which forwards to `EAWebkit.dll`), plus `Extension.Twinkle.Codec_Win{32,64}_retail.dll` and
`Extension.Twinkle.JavaScriptCore_Win64_retail.dll` (2,293,016 B) **[verified]**. NFS2015 ships only
`EAWebKit64.dll` and the recipe pins it **[verified in `nfs2015.json`]** — so **an EAWebKit in-game
browser already works under this Wine for NFS**, which is the strongest single positive signal for
BF4's in-game UI. It is **not Chromium**: it is EA's own WebKit fork with a separate JavaScriptCore.
Note it is *not* CEF, so the `EACefSubProcess.exe` renderer entry in `nfs2015.json` is about the EA
*client*, not the game. **[verified distinction]**

### b.5 Battlelog, the in-game server browser, and anti-cheat

**Battlelog.** BF4's "in-game server browser" is **Battlelog 2.0 rendered as an in-game overlay**,
not an independent native browser — DICE embedded Battlelog in the game rather than replacing it
(<https://www.pcgamer.com/battlefield-4-details-new-battlelog-including-in-game-overlay-and-user-made-missions/>,
**games press covering an official reveal; the primary DICE release was not located**). That is what
`EAWebKit64.dll` + `Extension.Twinkle.JavaScriptCore_Win64_retail.dll` in the game folder are for
**[inferred, consistent with the shipped files]**. Status:

- EA staff on EA's own forums, April 2025: *"Battlelog is no longer supported in Battlefield 4… you
  can still log in to Battlelog manually through a browser"*, and separately *"Battlelog is not
  supported anymore, but it works fine for Battlefield 3 and Battlefield 4"* —
  <https://forums.ea.com/discussions/battlefield-franchise-discussion-en/cant-connect-to-battlelog-in-game-april-2025/12124503>,
  <https://forums.ea.com/discussions/battlefield-franchise-discussion-en/is-ea-closing-the-battlelog-for-servers/12110616>.
  **Reliability: EA-staff forum replies — semi-official, and the most recent dated EA statement
  found.** No 2026 statement exists. **[This is a real risk: "no longer supported" plus an in-game
  UI that *is* Battlelog means EA could switch it off and break BF4 multiplayer independently of
  anything we do.]**
- EA shipped **"Plugin-Free Game Launching"** when Chrome dropped NPAPI —
  <https://answers.ea.com/t5/Battlefield-4/INFO-Plugin-Free-Game-Launching-Required-in-Chrome-supports-IE/td-p/4761597>
  (**official EA announcement thread; could not be fetched directly, 403 — title/index only**).
  The mechanism is almost certainly the Origin/EA client's **own local HTTP API on
  `127.0.0.1:3215`** (endpoints `/ping`, `/ping/gameservers`, `/status`, `/game/launch`, `/killgame`;
  parameters `masterTitleId`, `offerIds`, `ipAddrList`, `cmdParams`; requires an `Origin` request
  header of `http://battlelog.battlefield.com`) — <https://pastebin.com/xbb5q4wa>
  (**community notes of an unofficial/internal API; unofficial but internally consistent and matches
  observed behaviour**). **[inferred]** So there are *two* loopback servers in play: the EA client's
  `:3215` and the game folder's own `BF4WebHelper.exe`. Which one a 2026 Battlelog page actually
  calls is **[unknown]** — E5/E6.
- PS3/Xbox 360 online ended **2024-11-07** after a 2024-07-31 delisting; **PC, PS4 and Xbox One were
  explicitly unaffected** — <https://www.techradar.com/gaming/consoles-pc/ea-is-delisting-battlefield-3-4-and-hardline-on-older-platforms-at-the-end-of-the-month>
  (**press quoting EA's help site; help.ea.com itself would not load**).
- **Consequence:** the `battlelog-web-plugins.exe` NPAPI-era installer is almost certainly dead
  weight. But **do not assume multiplayer needs no web layer** — it needs Battlelog, just rendered
  in-game. E6 is the decisive experiment.

**Anti-cheat.** Two systems, and the public evidence openly conflicts:

| Source | Says | Reliability |
|---|---|---|
| **ProtonDB** app 1238860: tier **Gold**, best/trending **Platinum**, 347 reports, confidence "Strong" (0.79) — <https://www.protondb.com/app/1238860> | BF4 is routinely played on Linux, multiplayer included | **community database, large n — the strongest positive signal in this whole document** |
| Valve Proton issue **#3994** — <https://github.com/ValveSoftware/Proton/issues/3994> | PunkBuster kicks after ~5 minutes **unless** `pbsetup.exe` is run inside the prefix to pull current PB files; also the scoreboard shows **dash/missing ping**, which trips some servers' anti-"no-ping" auto-kick plugins (`setcap cap_net_raw+eip` on the Wine binaries helped only partly) | **user report on Valve's own tracker, labelled "Game compatibility – Unofficial"** |
| **CodeWeavers' own tip page**, "Game is Using Anti Cheat PunkBuster": the game "won't launch because Punkbuster AC prevents it from booting" — <https://www.codeweavers.com/compatibility/crossover/tips/battlefield-4/game-is-using-anti-cheat-punkbuster> | PB blocks launch entirely | **vendor database — but fetched only via a search summary (403/Cloudflare on direct fetch)** |
| **PCGamingWiki** PunkBuster article — <https://www.pcgamingwiki.com/wiki/PunkBuster> | PB is "not compatible with Wine" due to "harsh API entry signature checks" | **community wiki; 403 on direct fetch, search summary only** |
| **WineHQ AppDB** PunkBuster (iAppId 3896) — <https://appdb.winehq.org/appview.php?iAppId=3896> | PBSetup install/update works; "PB in MultiPlayer Mode" often fails — "Unknown Windows API Function", "Disallowed Program/Driver", "Service Communication Failure", tied to the `PnkBstrB.exe` kernel-mode driver component | **community database; access denied on direct fetch, search summary only** |
| **WineHQ Bugzilla #27075** — <https://bugs.winehq.org/show_bug.cgi?id=27075> | *Battlefield Heroes* PB fixed in Wine 1.3.20 by stubbing `ntoskrnl.exe.PsLookupProcessByProcessId` | **official WineHQ tracker — but a different title.** No BF4-specific WineHQ bug exists **[NOT FOUND]** |

**Reading the conflict [inferred]:** PunkBuster probably *does not* prevent `bf4.exe` from booting —
347 ProtonDB reports at Gold/Platinum would be impossible if it did; the CodeWeavers tip more likely
describes a CrossOver-specific failure or an older state. The realistic shape is: **single-player and
unranked play fine; ranked play needs PB working, which Proton users achieve only by manually running
`pbsetup.exe` in the prefix.** That is a legitimate operation — installing the vendor's own
anti-cheat updater — not a bypass.

**FairFight is entirely server-side** (statistical anomaly flagging, DICE staff review flags before
banning) — <https://www.pcgamer.com/battlefield-4-anti-cheating-measures-detailed/>,
<https://battlefield.fandom.com/wiki/FairFight> (**games press / community wiki**). It is invisible to
our client but it is the system that could flag an unusual environment.

**EA's official position on PB bans:** PunkBuster "is not owned or operated by EA… designed and
maintained by Even Balance", so EA cannot overturn PB bans —
<https://help.ea.com/en/articles/technical-issues/punkbuster-troubleshooting/> (**official EA Help,
but the live page timed out; search-summary sourced**). **Practical meaning: a PB ban is not
appealable through EA.** Weigh that against R6.

**I did not and will not investigate any method of bypassing PunkBuster, FairFight, or EA
authentication.** If ranked play needs an anti-cheat that will not run under Wine, the correct outcome
is "unranked servers only" — which is exactly the choice EA's own installer offers via `-Opt:InstallPB`.

### b.6 D3D11 / DXMT coverage for Frostbite 3

**[verified]** from `bf4.exe`'s strings: the renderer has **three** shader permutation sets — `Dx10`,
`Dx10_1`, `Dx11` — plus `D3D11CreateDevice`, `D3D10_ERROR_FILE_NOT_FOUND`,
`D3D10_ERROR_TOO_MANY_UNIQUE_STATE_OBJECTS`, and named Dx11 compute passes
(`Dx11/HorizonBasedAO_BlurCS`, `Dx11/DeferredOutdoorLightTile_key=1`,
`Dx11/HairSoftAlphaTestBlur_msaa`). It also contains **Mantle** code paths
("DirectX Mantle", "… Mantle doesn't support stream out …") and GNM (console) strings. The Havok and
Frostbite build paths place it at `Frostbite 2012_2_0`.

Corroborated by public sources:
- **BF4 uses DirectX 11.1.** DICE Technical Director **Johan Andersson**: *"We use DX11.1, there are
  some optimizations in it (constant buffer offsets, dynamic buffers as SRVs) that we got in to the
  API that improves CPU performance in our rendering when one runs with DX11.1. This will be in
  BF4."* — <https://www.guru3d.com/news-story/battlefield-4-gets-dx11-1-dx11-1-will-improve-cpu-performance.html>
  (**a named DICE engineer's own forum statement, widely re-reported — high confidence in the fact,
  informal in form**). **DXMT's coverage of D3D11.1 constant-buffer offsets
  (`VSSetConstantBuffers1` etc.) and dynamic buffers as SRVs is the specific thing to check.**
- **Compute shaders are central, not incidental.** DICE's own conference decks document Frostbite 3's
  tile-based deferred lighting as **three sequential compute passes** over the z/g-buffer writing an
  HDR UAV, plus HBAO and blur compute passes, run as **async compute** —
  <https://www.slideshare.net/DICEStudio/rendering-battlefield-4-with-mantle>,
  <https://www.slideshare.net/DICEStudio/battlefield-4-frostbite-3-mantle> (**official DICE slides —
  the most authoritative renderer source available**). This matches the `Dx11/…CS` strings in the
  binary exactly.
- **Minimum spec is D3D10-class hardware**: GeForce 8800 GT / Radeon HD 3870 (recommended GTX 660 /
  HD 7870) — <https://store.steampowered.com/app/1238860/Battlefield_4/> (**official
  publisher-supplied store listing, fetched directly; it shows no explicit DirectX field**). An
  8800 GT is feature level 10_0. **So the `Dx10` path is a real, shipped, playable configuration**,
  and it is a genuine fallback if DXMT's 11_1 coverage is short.
- **Tiled Resources**: no DICE or GDC statement says BF4 uses the D3D11.2 tiled-resources *feature*
  **[NOT FOUND]**. Do not confuse it with the tile-based *lighting* technique above.
- **Mantle**: an officially supported alternative low-level path on AMD GCN, irrelevant to us but it
  explains the Mantle strings in the binary.

Remaining renderer risk **[inferred]**:
- `nvapi64.dll` is imported. Under Wine that import must resolve to a stub or be absent —
  a missing `nvapi64.dll` can abort process load. **[unknown]** whether it is a delay-load. **This is
  experiment E3 and it is cheap.**
- MSAA (`Dx11/HairSoftAlphaTestBlur_msaa`) and async compute are the two DXMT features with the least
  evidence behind them in this project.

**Public status of BF4 under Wine/CrossOver/GPTK:**
- **CodeWeavers' own compatibility database** rates BF4 on **Mac: "Installs, Will Not Run"**, last
  tested CrossOver 26.2.0 — <https://www.codeweavers.com/compatibility/crossover/battlefield-4>.
  **Reliability: vendor database, high for the rating itself** (it is CodeWeavers' own testing),
  though a rating can lag.
- **AppleGamingWiki** rates it "Perfect" under CrossOver, with the note that since Origin's shutdown
  a CXPatcher DXVK patch is needed to launch, and rates plain Wine "Unknown" and Parallels "Playable"
  (tested M1 Max, 4K/ultra, stutters, a volumetric-light bug on Zeebrugge) —
  <https://www.applegamingwiki.com/wiki/Battlefield_4>. **Reliability: community wiki, medium** —
  single-reporter entries, and it contradicts CodeWeavers.
- The AppleGamingWiki route relies on **DXVK** (D3D11 → Vulkan → MoltenVK → Metal), not DXMT. Our
  project's stack is DXMT (D3D11 → Metal directly). **So the one public success report does not
  validate our renderer.** The contradiction between the two sources is itself a finding: **BF4 under
  a Metal-translating D3D11 layer is unproven.**
- CrossOver 26 is based on Wine 11 and ships D3DMetal 3.0, DXMT v0.72, Wine Mono 10.4.1, vkd3d 1.18;
  EA app support landed in CrossOver 23 — <https://alternativeto.net/news/2023/8/crossover-23-has-been-released-with-directx-12-support--uninstall-feature-and-ea-app-support-on-linux>.
  **Reliability: secondary news aggregation, medium.** Our runtime is Wine 11.0 from the `athei/wine`
  `cx-26-patched` base with DXMT v0.80 **[verified in `nfs2015.json` and `wine-rebuild/HANDOFF.md`]**,
  i.e. **ahead of** CrossOver 26's DXMT.
- **ProtonDB (Linux): tier Gold, best and trending Platinum, 347 reports, confidence "Strong"** —
  <https://www.protondb.com/app/1238860>. **Reliability: community database with large n — this is
  the single strongest positive signal available.** But it is **DXVK → Vulkan**, not DXMT → Metal.
  It proves the *game*, the *EA app* and the *DRM* all work fine under Wine. It proves nothing about
  our renderer.
- CrossOver forum reports (2025) describe BF4 launching via the EA app in a bottle but freezing a few
  seconds after the first screen, with intermittent "EA App crashed" — and one poster says CrossOver
  24 with DXVK + ESync via CXPatcher had worked flawlessly, implying an EA-app-update regression —
  <https://www.codeweavers.com/compatibility/crossover/forum/battlefield-4>. **Reliability:
  forum anecdote.**
- AppleGamingWiki lists plain **Wine as "Unknown"** and Parallels as "Playable". One small tracker
  reports a Mac mini M4 black-screen hang on CrossOver 25.1.0 with the EA app launcher —
  <https://macgamers.org/games/battlefield-4>. **Reliability: single anecdote, low.**
- **Whisky is no longer maintained** and its project page points users to CrossOver instead
  (**widely repeated; not verified by direct fetch**). Not a route.
- I found **no** report of BF4 under Apple's Game Porting Toolkit directly, or under DXMT
  specifically. **[NOT FOUND]** Note `nfs2015.json`'s `DENIED_BACKENDS` already records that
  D3DMetal/GPTK "does not implement the D3D11 timestamp queries this engine uses" **[verified]** —
  Frostbite is a sibling of that engine family, so **GPTK is a poor bet for BF4 too [inferred]**.

**The decisive gap, stated plainly:** every public success runs BF4's D3D11 through **DXVK/Vulkan**.
Every public attempt through a **Metal-translating D3D11 layer** (D3DMetal in CrossOver, and DXMT by
absence of any report) is either unreported or reports failure. **Our stack is the unproven axis.**
This is why E7 is the project's real gate, and it is also the argument for keeping an eye on whether
DXVK-over-MoltenVK is an acceptable alternative renderer for this one title — a renderer choice, not
a DRM question, and `renderers[]` in the recipe is already per-executable and per-API.

### b.7 Expected performance risks

1. **D3D11 compute + MSAA through DXMT** — the named `*CS` passes are the likeliest source of
   missing-feature aborts or wrong output.
2. **CPU**: BF4 multiplayer is heavily multithreaded. Running an x86_64 PE under Rosetta on Apple
   Silicon, through Wine's syscall layer, with 64 players of network and simulation load, is a far
   harder CPU target than NFS's single-player racing. **Expect multiplayer to be the performance
   wall, not the renderer** **[inferred]**.
3. **Working set**: `nvapi64.dll` absence, `XINPUT9_1_0.dll`, and `DINPUT8.dll` all need Wine stubs.
4. **Shader compilation**: three permutation sets and a large shader database mean a long first-run
   compile. `check_shader_cache.py` exists but its cache key tracks **mtld3d** emitter inputs
   **[verified]** — it does not cover DXMT, so BF4 gets no persistent shader cache without new work.
5. **x87 sidecar** remains relevant because four shipped BF4 binaries are i386.

---

## (c) Disk and logistics

### The numbers **[verified]**

| | Value |
|---|---|
| mbp23 `ExT2` free | 387 GiB (`df -h`) |
| mbp23 internal free | 48 GiB |
| This Mac free **right now** | **27–29 GiB** (`df -g /`, drifting during the session) — floor is 15 GiB |
| BF4 skeleton, logical | ~32.4 GiB (prior finding) |
| BF4 skeleton, allocated | **1.14 GiB** (`du -sk`), 3,165 files |
| `Update/Patch/Data` allocated | 220 MiB (sparse `.cas` set of 11 files) |
| `Games/Store` today | `nfs-2015` 14 GiB, `rise-of-nations` 2.6 GiB; `cod4`/`farcry2`/`nfs-mw`/`Morrowind` already evacuated to mbp23 |

### Decision: **download on mbp23, onto `ExT2`**

This Mac cannot hold BF4. 27 GiB free against a ~32.4 GiB install is already impossible, and another
session is holding 197 GiB in `/private/tmp/agora-m6` (**do not touch**). mbp23's `ExT2` has 387 GiB
and **already holds the partial skeleton at the exact path the EA app wrote**. mbp23 is also the
machine with the 4K screen that NFS was re-verified on (`docs/NFS2015.md:2193`) **[verified]**.

### Can the EA app resume/repair into `/Volumes/ExT2/EA Games/Battlefield 4`?

**[unknown] — and this is the most consequential unknown in the logistics plan.** What is known:

- The folder is a genuine EA Download-in-Place staging tree: every file carries the `_DiP_Staged`
  suffix, meaning EA's installer had written placeholder/partial files and had not yet renamed them
  **[verified]**.
- The data is **not there**: every `.cas` sampled is zeros, 1.14 GiB allocated of 32.4 GiB logical.
  So "resume" would have to re-download essentially everything regardless **[verified]**.
- The manifest declares a repair path: `touchup.exe install -repair -locale … -installPath …`
  **[verified]**, and `enableDifferentialUpdate="1"`.
- **EA documents a Repair feature**: Library → the game tile's three-dot menu → **Repair**, which
  "synchronizes the installation files with the files on the EA server and repairs faulty or missing
  files" without a full reinstall, DLC included —
  <https://forums.ea.com/kb/ea-app-tutorials-and-guides-en/infoguide-how-to-repair-a-game-on-the-ea-app/11894905>,
  <https://help.ea.com/en/articles/orders-and-rewards/ea-app-game-download-installation-loading-not-working/>.
  **Reliability: official EA-authored content, but both pages returned HTTP 403 to automated fetch —
  sourced from search-engine excerpts, not pages I read. Treat the wording as reported.**
- **EA's own documented fix for a "Create Folder Error" is a pause/copy/resume dance**: start the
  install, pause it after ~30 seconds, copy an existing folder's contents into the new target, then
  resume. **Reliability: official EA KB, same 403 caveat.** This shows the client *can* adopt
  pre-existing bytes in a folder it is itself installing into.
- The `_DiP_Staged` → rename mechanism is confirmed from a BF3 install log quoted on a forum
  (`bf3.exe_DiP_STAGED` → `bf3.exe`, `__Installer\Touchup.exe_DiP_STAGED` → `Touchup.exe`) —
  <https://hardforum.com/threads/help-me-get-bf3-to-work.1648214/>. **Reliability: community
  quoting the client's own log output. EA never uses the term "DiP" publicly.**
- **But** EA's documented workflow is "copy into a folder the EA app is *already installing into*",
  **not** "point Repair at a folder the EA app did not create". Whether the EA app *inside a Wine
  prefix* will adopt this folder through a Wine drive mapping is **[not documented either way]**.

**Recommendation:** treat the skeleton as **evidence, not as a resumable install**. Keep it read-only
as the reference for file names, sizes and the manifest (it has already paid for itself — every
binary fact in §b came from it). Point the EA app at a **fresh, empty folder**, e.g.
`/Volumes/ExT2/EA Games/Battlefield 4 (fresh)`. If a resume works, that is a bonus, not a plan.
Experiment E1 settles it.

### The owner's one-time sign-in and download

Exactly these steps, and no others, require the owner:

1. On mbp23, open the BF4 wrapper app's first-run screen. It installs the **pinned, Authenticode-
   verified** EA app MSI into a fresh prefix (`Packaging/client_layer.py`, `check_authenticode.py`).
   *No credentials are ever asked for, typed, logged or stored by our code.*
2. The EA app's own login window appears **inside the prefix**. The owner signs in **there**,
   directly to EA, exactly as on Windows. Our side only watches `ProgramData/EA Desktop/Logs/EADesktop.log`
   for `login` / `client.boot.ready` **[verified mechanism]**.
3. The owner selects Battlefield 4 in their own EA library and chooses the install folder on `ExT2`.
4. The owner starts the download (~32.4 GiB + the 220 MiB `Update` patch) and leaves it.
5. When it finishes, the owner reports the final folder path. Everything after that is automatable.

### Proposed `Games/Store` layout

Follow the `rise-of-nations` precedent exactly (**verified** from `rise-of-nations.PROVENANCE.txt`):
a store folder plus a `<id>.PROVENANCE.txt` recording source, date, file count, byte count and the
fact that account state was not copied.

```
Games/Store/bf4/                      # the game files, read-only (chmod a-w), or a MOVED.txt
Games/Store/bf4.PROVENANCE.txt        # source, date, counts, SHA-256 verification statement
```

Because the Mac cannot hold 32 GiB, `Games/Store/bf4/` will in practice start life as a `MOVED.txt`
pointing at mbp23, exactly like `cod4`/`farcry2` today **[verified pattern]**. Proposed README row,
to be appended to the table in `Games/Store/README.md`:

```
| bf4 | bf4 | Battlefield 4 (EA app / Origin SKU, build 179547, gameVersion 1.8.2.48475). Downloaded through the owner's own EA account on mbp23 to `ExT2`; not held on this Mac for space. No EA account data copied. |
```

And a second row under the "Moved to mbp23" section naming the restore command, in the same form as
`Store/cod4/MOVED.txt`.

### New working folder

`Games/bf4-tools/` (this folder) mirrors `ron-tools`, `CoD4-tools`, `FarCry2-tools`, `NFSMW-tools`
**[verified pattern]**. It holds `PLAN.md`, `bf4-recipe-draft.json`, `SUMMARY.md`, and later
`diag/`, `logs/`, `inputs/`.

---

## (d) Legal and terms-of-service statement

This plan concerns running a copy of Battlefield 4 that **the owner has bought and owns**, on
hardware **the owner owns**, through the **genuine, unmodified EA app**, downloaded with **the
owner's own EA account credentials, entered by the owner directly into EA's own sign-in window**.

Within that frame:

- **No circumvention.** No Origin or EA emulator, no crack, no "no-DRM" executable, no patched or
  replacement `Activation.dll`/`Activation64.dll`, no bypass of EA authentication, PunkBuster or
  FairFight. If a component cannot run under Wine, the answer is to **do without the feature** — for
  example, unranked servers if PunkBuster will not run — never to work around it. The optional
  nature of PunkBuster is EA's own design (`-Opt:InstallPB` in `installerdata.xml`), not a loophole.
- **Wine is a clean-room reimplementation**, not Windows. Using it is not circumvention. EA's
  installers and the game's own binaries are run **unmodified**, with their Authenticode signatures
  verified before use (`Packaging/check_authenticode.py`).
- **No credentials anywhere.** No code in this project asks for, transmits, logs or stores an EA
  password or session token. The client-layer classifier exists precisely to **strip** account state
  from anything packaged (`Packaging/client_layer.py`, `check_bundle_hygiene.py`,
  `check_client_layer.py`) **[verified]**.
- **Redistribution.** An `import`-edition app ships **no EA bytes** and is therefore
  distributable in the same way the Far Cry 2 recipe is. A `bundled` edition would embed ~32 GiB of
  EA's copyrighted game data; **that is a redistribution question the owner must answer, and this
  plan recommends import-only** unless the owner has a specific reason otherwise and keeps the result
  private.
- **EA's User Agreement** is between EA and the owner. This plan does not interpret it. Two points
  the owner should be aware of and decide on: (i) EA's terms address modifying the game and
  interfering with anti-cheat — this plan does neither; (ii) running an EA title on an unsupported
  platform is not a supported configuration, and **EA support will not help, and an anti-cheat false
  positive leading to an account action is a real, non-zero risk the owner accepts**. That risk is
  about an unusual execution environment, not about wrongdoing. **If the owner is not willing to
  accept any account risk, do not attempt multiplayer at all** — single-player/campaign carries no
  anti-cheat exposure.
- **LGPL.** The Wine fork is LGPL; the corresponding-source obligation is already handled by
  `runtimeSource` in the recipe and the `source-archive` in `wine-rebuild`
  (`wine-rebuild/HANDOFF.md` §7) **[verified]**. Extend it, do not reinvent it.
- **Third-party licences.** `thirdPartyLicenses` + `check_notice_licences.py` already enforce that
  every shipped component's licence travels with it **[verified]**.

---

## (e) Ordered step list, with day estimates

Days are working days of focused effort, excluding download time. The owner's own actions are marked
**OWNER** — there are only four of them, and the first two are the gate for everything else.

| # | Step | Who | Est. | Depends on |
|---|---|---|---|---|
| 1 | **OWNER: decide 64-bit-first or 32-bit-first** (see §0 and the decision box below). | OWNER | 0 | — |
| 2 | Lift `EAClientLog.swift` and the generic crash/fault parsers from `NFS2015Core` into `LauncherCore`; add `BF4Core`/`BF4Launcher`/`BF4Session` skeleton targets that compile and do nothing. | — | 1 | — |
| 3 | Extend `recipes.py` `importRules.machine` to accept `x86_64`; add `bf4` to `GAME_EXECUTABLES`; add `check_bf4_recipe.py`. Run `check_recipes.py` green. | — | 1 | 2 |
| 4 | **Fix the `ClientUpdateDestaging` readiness bug** (board `wine-rebuild-028`): add the readiness rule with log fixtures. Do this *before* the owner's download, because a fresh client will want to self-update. | — | 1–2 | 2 |
| 5 | Build and pin a BF4 runtime profile in `runtime-inputs.json` from `wine-0011`, capabilities `[dxmtDXGI]`. No new Wine patches yet. | — | 0.5 | — |
| 5b | **E11, today, free**: load `battlelog.battlefield.com` in a browser. If Battlelog's backend is gone, multiplayer is off the table and the whole plan shrinks to the campaign. | — | 0.05 | — |
| 6 | Dry-run experiments **E3, E4** (and E1's planning) on mbp23 against the **existing read-only skeleton** — no download needed: prefix creation, `nvapi64` load behaviour, VC++ 2012 redist install, a `wine` PE-load smoke test of `bf4.exe` expecting an immediate *data* failure rather than a *loader* failure. **Note:** the skeleton's files carry the `_DiP_Staged` suffix, so a smoke test needs a renamed copy on scratch space (mbp23 is read-only to this session; the owner or a future session with write rights must make it). | — | 1 | 4, 5 |
| 7 | **OWNER: install the EA app into the prefix on mbp23 and sign in once.** | OWNER | 0.25 | 4, 6 |
| 8 | **OWNER: start the BF4 download to a fresh folder on `ExT2`** and let it run. Record whether the EA app offered to resume/repair the old folder (**E1**). | OWNER | 0.1 + wait | 7 |
| 9 | Confirm the **offer id list** (E2 — mostly already known, see §b.1); read the real file inventory, sizes and SHA-256s; fill every `TODO` in `bf4-recipe-draft.json`; compute `inventorySHA256`. Extend `recipes.py` so `offerID` can hold the 20-id list. | — | 1 | 8 |
| 10 | **E5 / E6**: first launch attempt. `BFLauncher.exe` → `BF4WebHelper.exe` → `bf4.exe`. Capture the helper's bound port, the argv handed to `bf4.exe`, and whether the in-game server browser appears. | — | 1–2 | 9 |
| 11 | **E7**: renderer. DXMT at the three permutation sets. Expect iteration here; this is where a new Wine patch series is most likely needed. | — | 3–10 | 10 |
| 12 | Settings catalog, display rule, crash parsing, MetalFX gate, privacy declaration for the listening socket. | — | 3 | 11 |
| 13 | **OWNER: one multiplayer session**, unranked, accepting the account risk in §(d). Then E12 (`pbsetup.exe` in the prefix) if ranked play is wanted. | OWNER | 0.25 | 11 |
| 14 | Packaging, signing, audit, `Store/bf4.PROVENANCE.txt` and the README rows. | — | 2 | 12 |

**Realistic total: 15–25 working days** if the renderer cooperates; **open-ended** if it does not.
Steps 1–6 are ~4.5 days and need **nothing from the owner but step 1**, so they are the right place
to start.

> ### The single decision the owner must make first
> **Target `bf4.exe` (x86_64) or `bf4_x86.exe` (i386)?**
> - **x86_64** is the real, supported, better-performing game — but it needs a schema change, a new
>   64-bit crash-analysis path, and it is the architecture our stack has the *least* evidence for.
> - **i386** is the architecture every existing recipe, the x87 sidecar, the trap-flag work and all
>   the crash tooling already target — the entire NFS2015 investment applies directly — but it is a
>   second-class configuration of the game and will be tighter on memory.
>
> My recommendation: **x86_64 first**, because it is what the owner actually wants to play and because
> EA's own manifest makes it the primary launcher. But **do the cheap E3 check (does `bf4.exe` even
> load under Wine, given `nvapi64.dll`) before committing** — it costs an hour and it can flip the
> answer.

---

## (f) Risk register

| # | Risk | Likelihood | Impact | Mitigation / decision point |
|---|---|---|---|---|
| R1 | DXMT cannot serve BF4's D3D11.1 compute/MSAA passes | **Medium–high** | Fatal to the project | E7. Fallbacks in order: BF4's own `Dx10`/`Dx10_1` paths; DXVK-over-MoltenVK for this one title; `bf4_x86.exe`; abandon. CodeWeavers' own DB says "Installs, Will Not Run" on Mac, while ProtonDB (DXVK) says Gold/Platinum over 347 reports — **the renderer is the variable that differs**. |
| R13 | EA switches Battlelog off; BF4's in-game multiplayer UI *is* Battlelog | Low–medium, and **entirely outside our control** | Multiplayer dies | None available. EA staff already call it "no longer supported" (April 2025). Campaign is unaffected. Factor this into whether multiplayer is worth the effort at all. |
| R14 | Missing/dash ping in the scoreboard trips servers' anti-"no-ping" auto-kick plugins (reported under Proton; `setcap cap_net_raw+eip` only partly helped) | Medium | Kicked from some servers | Proton issue #3994. Raw-socket access on macOS differs from Linux; expect to need investigation. Not fixable by us on the server side. |
| R2 | Download fails, stalls, or cannot resume; 32 GiB re-downloaded repeatedly | Medium | Days of wall time | Download to `ExT2` (387 GiB), fresh folder, keep the skeleton as a reference. E1. |
| R3 | `ClientUpdateDestaging` kills every session before the game starts | **High** (it is a *known* current bug) | Blocks all launches | Step 4, before the owner's time is spent. |
| R4 | `BF4WebHelper`'s socket does not work under Wine, or the browser cannot reach it | Medium | Blocks Battlelog joins only | The in-game server browser probably makes this optional (b.5). E6 decides. |
| R5 | PunkBuster will not run under Wine | **Medium** (ProtonDB's 347 reports suggest it is workable after running EA/Even Balance's own `pbsetup.exe` in the prefix; PCGamingWiki and a CodeWeavers tip say otherwise) | No ranked servers | Run the vendor's own `pbsetup.exe` inside the prefix, as Proton users do — that is using the anti-cheat, not bypassing it. If it still fails: accept unranked only. It is optional by EA's own design (`-Opt:InstallPB`). **Do not work around it.** |
| R6 | Anti-cheat false positive → account action | Low but non-zero | Loss of the owner's EA library | **Owner's decision in §(d).** Single-player only is the zero-risk option. |
| R7 | Multiplayer CPU cost makes it unplayable even if it renders | Medium | Feature loss | Measure early (step 13); campaign may still be fine. |
| R8 | The 64-bit path needs a new Wine patch series like NFS's trap-flag work | Medium | +1–3 weeks | Budget for it. `wine-rebuild` already has the machinery (patches 0005–0011). |
| R9 | `nvapi64.dll` import aborts process load | Low–medium | Blocks launch | **E3, one hour, do it first.** |
| R10 | This Mac's 29 GiB free shrinks below the 15 GiB floor | Medium | Blocks local work | Keep all BF4 bytes on mbp23. Never clone the install here. |
| R11 | The pinned EA app version (13.805.2.6319) is too old to see the BF4 entitlement | Low | Re-capture the client layer | `capture-client-layer.py` already automates it. |
| R12 | `Store/bf4` can never live on this Mac, breaking the `{store}` convention | Certain | Cosmetic | Use the `MOVED.txt` pattern already established for `cod4`/`farcry2`. |

## Open questions, each with its experiment

| ID | Question | How to run it | What the result decides |
|---|---|---|---|
| **E1** | Will the EA app resume/repair into the existing `/Volumes/ExT2/EA Games/Battlefield 4` DiP tree? | During step 8, before choosing a folder, point the EA app's install dialog at the existing path and read what it offers. Do **not** let it write until the answer is recorded. | Whether ~1.14 GiB and the manifest are reusable, or the folder stays read-only evidence. Low stakes either way. |
| **E2** | Confirm the **offer id list**, and which of the 19 DLC ids the owner actually owns. | After sign-in, look for `ProgramData/Origin/Logs/*_OnlineActivation_Log.html` (that is where NFS's `1024486` came from) and read the ids the client itself passes. Compare against the 20-item list in §b.1's box. | Fills `storeClient.offerID`. **Largely answered already** (manifest ↔ Lutris agreement); E2 is confirmation plus trimming unowned DLC ids. |
| **E11** | Does BF4's multiplayer UI reach Battlelog's backend at all in 2026? | After a successful launch, open multiplayer. Also simply load `battlelog.battlefield.com` in a host browser first — a **zero-cost pre-check that can be done today, before any download**. | Whether multiplayer is worth planning for at all (R13). **Cheapest high-value check in the plan — do it alongside E3.** |
| **E12** | Does `pbsetup.exe` install and update PunkBuster inside the prefix? | Run EA/Even Balance's own `pbsetup.exe` against the prefix, as Proton users do (issue #3994). Check for `PnkBstrA`/`PnkBstrB`. | Ranked servers, yes or no. Resolves the ProtonDB-vs-CodeWeavers conflict for our stack. |
| **E3** | Does `bf4.exe` load at all under `wine-0011`, given its `nvapi64.dll` import? | `wine bf4.exe` in a throwaway prefix with no game data. Expect a *data* failure, not a *loader* failure. If the loader fails on `nvapi64`, add a Wine stub or a DLL override. | **Do this first.** A loader failure here flips the architecture decision toward `bf4_x86.exe`. One hour. |
| **E4** | Does `vcredist_x64.exe` (VC++ 2012 U3) install into the prefix under this Wine? | Run it `/quiet /norestart` in a throwaway prefix; check for `MSVCR110.dll`/`MSVCP110.dll` in `system32`. | Whether the prerequisite is automatable or needs a different route. |
| **E5** | Which TCP port does `BF4WebHelper.exe` bind, and does it bind `127.0.0.1` only? | Run the helper alone in the prefix; `lsof -nP -iTCP -sTCP:LISTEN` on the host. | The privacy declaration, and whether a host browser can reach it. |
| **E6** | Does BF4's **in-game** server browser work, making the Battlelog/browser path optional? | After a successful launch (step 10), open multiplayer from the game's own UI. | **The highest-leverage question in the whole plan.** Yes → drop `battlelog-web-plugins.exe`, the host-browser integration and most of R4. |
| **E7** | Which DXMT gaps does BF4 hit, and does the `Dx10_1` path avoid them? | Launch with DXMT logging; collect the first failure; then force the lower feature level if BF4 exposes a setting or console variable for it. | Whether the project is viable, and at which feature level. |
| **E8** | Does BF4 need `trapFlagEmulation` (the NFS16 Wine patch series)? | Run with `WINE_TF_EMULATION` unset; if it faults the way NFS16 did, turn it on. | Whether the BF4 runtime profile needs the capability, and therefore which `wine-00NN` it pins. |
| **E9** | Where does BF4 store its settings and profile, and what are the key names? | After first launch, diff the prefix's user tree. | The Settings catalog in step 12. |
| **E10** | Does `__Installer/touchup.exe` complete under Wine? (`forceTouchupInstallerAfterUpdate="1"` means it will be run.) | Observe during step 8's download/finalise. NFS recorded "a successful touchup" (`docs/NFS2015.md:486`), so the precedent is good. | Whether the install can ever reach a finalised, non-`_DiP_Staged` state. |

### Things I could not determine

- **No official EA documentation exists for the `origin2://` scheme at all.** Every syntax in
  circulation (`?offerIds=`, `&autoDownload=1`, `&cmdParams=`) is community-reverse-engineered, and an
  EA rep called it unsupported. Our own NFS recipe is the best evidence it works.
- Whether PunkBuster's `PnkBstrA`/`PnkBstrB` run under *this* Wine, and whether `PnkBstrB`'s
  kernel-mode component is reachable. Public evidence **directly conflicts** (table in §b.5).
  **[E12]**
- Any report of BF4 under Apple's GPTK directly, or under DXMT. **[NOT FOUND]** — this is the gap
  the whole project sits in.
- BF4's exact minimum D3D **feature level** as an official number. Best available: the official
  minimum GPU is a D3D10-class 8800 GT, and DICE confirmed DX11.1 is used for optimisations — so
  10_0 is the floor and 11_1 is the preferred path. **[inferred from two sources]**
- Whether Battlelog will stay reachable. Best source is an April 2025 EA-staff forum reply saying it
  is unsupported but working. **No 2026 statement exists.** **[E11]**
- The exact size of BF4's cumulative `Update`/patch content. **[NOT FOUND]** Official system
  requirements say **30 GB** for the base game
  (<https://www.vortez.net/ea_announce_the_official_system_requirements_for_battlefield_4/>,
  <https://wccftech.com/battlefield-4-pc-system-requirements-officially-revealed-quad-core-cpu-gtx-660hd-7870-recommended-max-settings/>
  — **tech press reporting EA's announcement, widely corroborated; the primary EA page was not
  located**), consistent with the ~32.4 GiB logical skeleton. Community commentary suggests
  budgeting **~20 GB more** if all DLC is installed — **anecdotal, not an EA figure**. Plan for
  **~55 GiB on `ExT2` to be safe**; it has 387 GiB.
- Whether EA's Repair will adopt a folder it did not create. **[not documented either way] [E1]**
- Several official pages (`help.ea.com` PunkBuster, EA's Repair KB, CodeWeavers' compatibility and
  tip pages, PCGamingWiki, WineHQ AppDB) returned **403 / Cloudflare / timeout** to automated fetch.
  Facts drawn from them are **search-summary sourced, not pages anyone here read**, and are flagged
  as such inline. **If any single one of them is load-bearing for a decision, open it manually.**

---

## Provenance note

Every binary and manifest fact in §(b) was read **read-only over SSH** from
`/Volumes/ExT2/EA Games/Battlefield 4` on mbp23. Nothing on mbp23 was written, moved or deleted.
Nothing was downloaded, installed or launched; no EA account was touched; no credential was
requested, typed or stored. This Mac's free space was 29 GiB before and after (floor 15 GiB), and
`/private/tmp/agora-m6` was not touched.

One correction to the brief's established finding, for the record: the file count is **3,165**, not
633, and **the executables are complete, real PE images** — only the `.cas` game data is sparse. That
correction is what made §(b) possible.
