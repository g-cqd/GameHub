# T4b: LaunchPlanCompiler + CompatDB + golden plans (spec; report, do not improvise)

Depends on T4a. Pure (no I/O except via the injected TargetFactsBuilder/RuntimeVerifier results passed in). Files `Sources/HubCore/Plan/{CompatDB.swift,
LaunchPlanCompiler.swift, TargetSettings.swift}`, tests `Tests/HubCoreTests/{CompatDBTests.swift, LaunchPlanTests.swift, GoldenRecipeTests.swift}`.
Model edits: `LaunchPlan` gains `stages: [LaunchStage]`, `hostCommand: [String]` (argv: wine binary + Windows args) and `state: ProviderState?`
(`notInstalled` when the executable is missing, else nil).

## TargetSettings (`State/settings/<target>.json`)
`package struct TargetSettings: Codable, Equatable, Sendable { enabledFixes: [String]; disabledFixes: [String]; parameters: [String: String] }` where parameter
keys are `<fixID>.<parameterID>`; strict keys; `static let empty`. Validation: ids Check.id; each parameter value accepted by that fix parameter (type/choices/range).

## CompatDB (`package enum CompatDB`)
`render(rules: [(exe: String, api: String, backend: String, owner: String)], runtime: URL) throws(HubError) -> String`:
each rule validated through `RendererSelection(api:backend:executable:)` (`*` -> executable nil); group by exe case-insensitively (keep the first spelling);
same exe+api with different backends -> `.invalid("renderer conflict for <exe> <api>: <owner1> vs <owner2>")`; identical duplicates collapse;
no `*` group -> `.invalid("no total default renderer rule")`; > 32 lines -> invalid; `RuntimeVerifier.backendProblems` non-empty -> `.invalid` with them.
Output: `v=3`, then non-default exes sorted by lowercase name as `name=hub-<n>;exe=<exe>;<api>=<backend>[;...]` (n from 1, apis sorted), last
`name=default;exe=*;<apis sorted>`; joined with `\n`.

## LaunchPlanCompiler
`package struct LaunchPlanCompiler { knowledge; paths: HubPaths; prefix: URL; runtimeID: String; runtimeDir: URL; runtimeCaps: Set<Capability>;
facts: [String: TargetFacts]; roots: [String: (windows: String, host: URL)]; settings: [String: TargetSettings]; helperURLs: [String: URL] }`
`func plan(target: String, mode: Mode) throws(HubError) -> LaunchPlan` with `enum Mode { case start, launchGame }` (start = run the target itself: a provider
client or a direct game; launchGame = a game through its provider). Errors only for unknown target / invalid knowledge; every other problem is a `refusals` entry.
1 applicable(T) = fixes where status != rejected AND (appliesWhen.matches(facts[T]) OR recipe(T).fixes contains id) AND (!optIn OR settings[T].enabledFixes contains id)
  AND NOT settings[T].disabledFixes contains id (a verified fix may be disabled only if it has `optIn`... NO: any fix may be disabled by the user; record a warning
  "fix <id> disabled by the user" for verified ones). Parameter values replace the bound field (bool -> Bool, others String) before use.
2 requires: a missing capability -> verified fix: refusal "fix <id> needs <cap>, missing in <runtimeID>"; experimental: warning and the fix is dropped.
3 Session targets: Mode.start -> [T]; Mode.launchGame -> [provider(T), T] (refusal if T has no provider or launch.method != provider). Session fixes = union.
4 compatdb = CompatDB.render over renderer actions of applicable fixes of EVERY recipe in knowledge (prefix-wide), owners = fix ids.
  (Errors from render become refusals; compatdb then "".)
5 environment = base {HOME paths.home, USER "Player", LOGNAME "Player", TMPDIR paths.temp, PATH "/usr/bin:/bin:/usr/sbin:/sbin", LANG "en_US.UTF-8",
  WINEPREFIX prefix.path, WINEDEBUG "-all", WINEMSYNC "1", MTL_HUD_ENABLED "0", RUST_LOG "warn,mtld3d::perf=off", WINE_COMPATDB compatdb}
  + WINEDLLOVERRIDES = exe-less disabled overrides of session fixes, sorted case-insensitively, `<dll>=d` joined by `;` (omit the key if none)
  + session-scope env actions (two different values for one name -> refusal) + ROSETTA_X87_PATH = helperURLs["x87sidecar"] when session sidecar is on
  (on iff >= 1 sidecar action true and none false; on but helper missing -> refusal). Nothing else; never copy the Hub's own environment.
  sessionProfile = the session env actions + `x87sidecar`: "on"/"off".
6 executable/arguments: Mode.start: root(T) + recipe.executable (Windows path joined with `\`), arguments = `arguments` actions of session fixes whose exe
  equals the executable (case-insensitive), in fix id order. Mode.launchGame: provider root + provider.launch.executable, arguments = [urlTemplate resolved]
  with {offerIDs} = eaOfferIDs joined "," and {appID} = steamAppID | epicAppName | ubisoftID per provider; missing id -> refusal "no store id".
  root missing or executable missing -> state notInstalled + refusal "not installed: <windows path>". legacy wrapper (launch.method wrapper) -> executable "",
  warning "opens the legacy wrapper <legacyWrapper>", no refusal. hostCommand = [runtimeDir/bin/wine, executable] + arguments when executable non-empty.
7 pendingActions = every other action kind of session fixes (registry, file, ini, xmlAttribute, drive, window, prerequisite, dllOverride with exe, companion)
  as PendingAction(owner: fixID, action) after placeholder resolution: {prefix} prefix.path, {hubRoot} paths.root.path, {gameRoot} root(T).host.path,
  {providerRoot} and {eaClientDir} root(provider).windows (Windows-valued fields) or host (host-valued file fields); unresolvable -> refusal.
8 stages: Mode.start -> stages of T with scope client; Mode.launchGame -> provider stages (client + game scope) then T's stages; probes' log placeholders resolved to host paths.
9 Determinism: same inputs -> byte-identical JSON (sorted keys encoder).

## Tests
CompatDB: conflict, duplicate collapse, missing default, gptk dir missing, 33 rules, exact text for the EA set.
Golden (GoldenRecipeTests) using the BUNDLED knowledge with synthetic facts and temp roots (a temp prefix with drive_c + Program Files/EA layout incl. a
`13.805.11.6320-1791598480/EA Desktop/EADesktop.exe` file, `dosdevices/e:` and `z:` links to temp dirs) and a temp runtime dir with
`lib/wine/dxgi/{dxmt,wined3d}/x86_64-windows`, `lib/wine/d3d9/mtld3d/i386-windows`:
- `ea` start: compatdb == "v=3\nname=hub-1;exe=BF3WebHelper.exe;dxgi=dxmt\nname=hub-2;exe=bf3... (write the exact expected text from the fixes, sorted)" and
  contains `exe=EACefSubProcess.exe;dxgi=wined3d`, `exe=EAGEP.exe;dxgi=wined3d`, last line `name=default;exe=*;d3d9=mtld3d;dxgi=dxmt`; environment has exactly the
  base keys + WINEDLLOVERRIDES "IGOProxy32.exe=d;winemenubuilder.exe=d" + WINE_TF_EMULATION "1", WINE_TF_MAX_STEPS "0", WINE_TF_MAX_NS "0" + ROSETTA_X87_PATH;
  arguments ["--in-process-gpu"]; executable ends with `13.805.11.6320-1791598480\EA Desktop\EADesktop.exe`; no refusals.
- start-ea.sh equivalence: parse `/Volumes/ExT2/GameHub/bin/start-ea.sh` ONLY IF it exists (else skip with a recorded note): every `exe=...;api=backend` body in its
  COMPAT block appears in the ea compatdb; env names it sets (excluding HOME, TMPDIR, WINEPREFIX, ROSETTA_X87_PATH paths) equal ours except RUST_LOG/LOGNAME.
- each game recipe in bundled knowledge (bf3, bf4, crysis3, nfs2015, cod4, nfsmw, farcry2, morrowind, ron) compiles; morrowind has the refusal mentioning mtld3dD3D8;
  wrapper games have the wrapper warning; nfs2015 launchGame sessionProfile contains WINE_RWX_WX_EMULATION=1 and the ea start profile does not; bf3 launchGame
  arguments == ["origin2://game/launch/?offerIds=70619,71067"]; ron launchGame via steam -> ["steam://rungameid/287450"].
- steam/epic/ubisoft start plans: no refusal when their exe exists in the temp layout, notInstalled otherwise.
- user settings: disabling x87-sidecar removes ROSETTA_X87_PATH; enabling metalfx-spatial adds the two DXMT env vars; invalid parameter value rejected.
- A grep-style test: no file under Sources/HubCore references `GameKind` (read the source tree via #filePath-relative URL; skip if unreadable).
## Done: build + HubCoreTests green. Report files, counts, deviations.
