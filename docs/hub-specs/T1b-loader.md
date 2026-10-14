# T1b: Knowledge loader + model amendments (spec; implement exactly, report, do not improvise)

Depends on T1a (Sources/HubCore/Model). Swift 6, `package` access, typed throws `throws(HubError)`.
Files: `Sources/HubCore/Model/Knowledge.swift`, `Tests/HubCoreTests/KnowledgeLoaderTests.swift`; edits listed below.

## Amendments to T1a types
A1 `Fix` gains `optIn: Bool` (JSON key optional, default false): an opt-in fix applies only when the user enabled it. Encoded always.
A2 `Readiness.log` and `ReadinessEvent.log` are no longer plain relative paths: they must start with `{prefix}/` or `{providerRoot}/` and the remainder must
   pass `Check.relativePath`. Update validation + the T1a tests/mutations that used the old form (add mutations: `drive_c/x.log` without placeholder, `{gameRoot}/x.log`).
A3 `Check.isAlwaysTrue`: none. Instead add `Condition.Kind.always` (value must be the empty string `""`; matches every target). Add tests.
A4 `RuntimeManifest.helpers` paths are relative to the Runtimes directory (e.g. `hub-0-helpers/x87sidecar`). Doc comment only.

## Package
In Package.swift change the HubCore target to `.target(name: "HubCore", dependencies: ["LauncherCore"], resources: [.copy("Knowledge")])` and create
`Sources/HubCore/Knowledge/` containing ONLY a placeholder `README.md` (one line: "Hub knowledge base: see docs/hub-shared-prefix-design-20261011.md")
and empty folders kept with `.gitkeep`: `runtimes`, `fixes`, `recipes/providers`, `recipes/games`, `rules`, `assets`; plus minimal valid
`capabilities.json` = `[]`, `knobs.json` = `[]`, `prerequisites.json` = `[]`, `patches.json` = `[]` (T2 fills them; your loader must accept these).
`package static var bundledDirectory: URL? { Bundle.module.url(forResource: "Knowledge", withExtension: nil) }`.

## Knowledge
```
package struct CapabilityDoc: Codable, Equatable, Sendable { id: Capability; title: String; evidenceHint: String }   // strict keys, title<=80, hint<=200
package struct Knowledge: Equatable, Sendable {
  capabilities: [CapabilityDoc]; knobs: [Knob]; prerequisites: [Prerequisite]; patches: [Patch]; runtimes: [RuntimeManifest];
  fixes: [Fix]; recipes: [Recipe]; rules: [ProposalRule]; assets: [String: URL]   // asset relative path -> file URL
  package static func load(bundled: URL, user: URL?) throws(HubError) -> Knowledge
  package func fix(_ id: String) -> Fix?; recipe(_ id:) -> Recipe?; runtime(_ id:) -> RuntimeManifest?; knob(_ name:) -> Knob?
}
```
Layout read from each directory D (bundled, then user if non-nil and it exists; a missing user dir is fine; a missing bundled dir -> `.invalid`):
`D/capabilities.json`, `D/knobs.json`, `D/prerequisites.json`, `D/patches.json` (JSON arrays; optional in the user dir), `D/runtimes/*.json`, `D/fixes/*.json`,
`D/recipes/providers/*.json`, `D/recipes/games/*.json`, `D/rules/*.json` (one object per file; the file name without `.json` must equal the object's `id`),
`D/assets/**` (regular files, any name; key = path relative to `D/assets`).
Safety: every file and directory read via `lstat`: symlinks refused (`.unsafePath`); a JSON file > 256 KiB refused; an asset > 4 MiB refused; at most 1024 files total
per directory tree; only `.json` files are read in the JSON folders (others ignored except `.gitkeep`/`README.md`). Decode with `JSONDecoder` (dates iso8601).
Validation after loading both directories:
1 every object's own `validate()`; ids unique within each kind (bundled + user together) -> duplicate `.invalid("duplicate fix <id>")`; a user entry may never reuse a bundled id.
2 capabilities.json, when non-empty, must document every `Capability` case exactly once.
3 every `FixAction.env` name exists in knobs and its scope is in that knob's scopes; every `prerequisite` id exists in prerequisites; every `file.asset` exists in assets
  and its sha256 equals the asset file's sha256 (CryptoKit SHA256).
4 every `recipe.fixes` id and `rule.propose.fixes` id exists; every `runtime.source.patchSeries` id exists in patches.
5 a recipe with `provider` p (not none) and kind game requires a provider recipe with id == p.rawValue.
6 `Fix.requires` and `Patch.capability` are typed already; nothing more.
Errors name the file (`fixes/x.json: ...`).

## Tests (>= 12) using temp directories built in the test
valid minimal tree loads; bundled `Knowledge.bundledDirectory` exists and loads; duplicate id across bundled/user rejected; file name != id rejected; symlinked json
rejected; 300 KiB json rejected; unknown env knob rejected; env scope not allowed rejected; missing asset / wrong asset sha rejected; recipe referencing unknown fix
rejected; game recipe whose provider recipe is missing rejected; patchSeries unknown rejected; capabilities.json missing one case rejected (when non-empty);
`always` condition matches; optIn decodes default false.
## Done
`swift build --scratch-path <scratch>` and `swift test --scratch-path <scratch> --filter HubCoreTests` succeed. Report files, counts (before/after), deviations.

## Amendments from the Stage 1 review (also part of T1b)
A5 `ReadinessEvent` gains `holdSeconds: Int?` (0...600): the event's state takes effect only after it has stayed the latest matching event for that long
   (observation time). Used for EA `needsSignIn` (startup shows `awaitingAuthentication` for ~2 s).
A6 `FixAction.dllOverride` without `exe` is valid ONLY when mode == "disabled" and dll ends with `.exe` (disabling a program). Every other override must
   name an exe (it becomes `HKCU\Software\Wine\AppDefaults\<exe>\DllOverrides`, never session-wide WINEDLLOVERRIDES). Mutation tests for both.
A7 New action `xmlAttribute { file, element, attribute, value }`: file as the `ini` destination rule; element and attribute regex `^[A-Za-z_][A-Za-z0-9_.-]{0,63}$`;
   value <= 256 bytes, no control chars. (Far Cry 2 `GamerProfile.xml` `Platform="d3d9"`.) Bindable field: value.
A8 `drive` gains `lifetime: session|persistent` (required): session drives are created at launch under the game lease and removed at stop.
A9 `window` virtualDesktop gains required `exe` (Check.exe): it compiles to `AppDefaults\<exe>\Explorer` Desktop + `Explorer\Desktops` registry values;
   retina stays prefix-wide (exe must be nil).
A10 New `Probe` and `LaunchStage` (generic launch state machine, data only):
   `Probe` enum (JSON `kind`): `log { log, contains, holdSeconds? }` (log rule as Readiness.log), `port { port }` (1...65535),
   `process { exe, present: Bool }` (Check.exe). `LaunchStage { id (Check.id); title (<=80); passWhen: [Probe] (1...4, all must hold);
   failWhen: [Probe] (0...4, any fails the stage); timeoutSeconds 1...900 }`.
   `Recipe` gains `launchStages: [LaunchStage]` (optional in JSON, default []), validated (ids unique, <= 12 stages). Provider recipes describe the stages
   from client start to "game session started"; `gamehub doctor` reports the first stage that did not pass.
A11 `LaunchStage` gains `scope: client|game` (JSON optional, default client): provider stages with scope game run only when a game is launched through the
   provider; game recipes' stages are always scope game.
