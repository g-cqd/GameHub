# T3: HubPaths, HubConfig, SharedPrefix (spec; implement exactly, report, do not improvise)

Swift 6, strict concurrency, `package` access, value types, typed throws `throws(HubError)`. No force unwraps, no `try!`, no DispatchQueue.
Files: `Sources/HubCore/Prefix/{HubPaths.swift, HubConfig.swift, SharedPrefix.swift, PrefixProblem.swift}`, tests `Tests/HubCoreTests/SharedPrefixTests.swift`.
Edit allowed in `Sources/HubCore/HubTypes.swift`: add exactly two cases to `HubError`: `case volumeMissing(String)` (doc: the volume holding the
path is not mounted) and `case blocked(String)` (doc: an operation is refused because something else holds the resource). Fix any exhaustive switch
over HubError that breaks (search the whole repo, including Sources/HubApp).
Design reference: /Volumes/ExT2/GameHub/docs/hub-shared-prefix-design-20261011.md sections 2, 7, 8.

## HubPaths
`package struct HubPaths: Equatable, Sendable { package let root: URL }` with `package init(root: URL)` and `package static func standard() -> HubPaths`
(root `/Volumes/ExT2/GameHub`). Computed URLs (exact relative paths): hub `Hub`, config `Hub/hub.json`, state `Hub/State`, leases `Hub/State/leases`,
settings `Hub/State/settings`, runs `Hub/State/runs`, ledger `Hub/State/ledger.jsonl`, session `Hub/State/session.json`, logs `Hub/Logs`,
home `Hub/Home/Player`, temp `Hub/Temp`, userKnowledge `Hub/Knowledge`, runtimes `Runtimes`; functions `runtime(_ id: String) -> URL` (`Runtimes/<id>`),
`runtimeManifest(_ id:)` (`Runtimes/<id>.manifest`), `helpers(_ id:)` (`Runtimes/<id>-helpers`). `id` must match `^[a-z0-9][a-z0-9-]{0,47}$` else the
functions are `throws(HubError)` with `.invalid`.
`package func prepareTree() throws(HubError)`: if `root` does not exist as a directory (use `lstat`; a symlinked root is refused with `.unsafePath`)
throw `.volumeMissing(root.path)` and create NOTHING. Otherwise create (withIntermediateDirectories only below root) hub, state, leases, settings, runs,
logs, home, temp, userKnowledge with mode 0700 for state/leases/settings/runs and 0755 others. Idempotent.
`package static func volumeRoot(of path: String) -> String?`: for `/Volumes/<name>/...` return `/Volumes/<name>`, else nil.
`package static func isMounted(_ volumeRoot: String) -> Bool`: true iff `lstat` succeeds, it is a directory, and its `st_dev` differs from `lstat("/Volumes").st_dev`.

## HubConfig (`Hub/hub.json`)
`package struct HubConfig: Codable, Equatable, Sendable { schemaVersion: Int; prefix: String; runtime: String; runtimeManifestSHA256: String; generation: Int }`.
`package static func read(_ url: URL) throws(HubError) -> HubConfig`: file must be a regular file (lstat, not a symlink), <= 64 KiB; decode with JSONDecoder;
reject unknown top-level keys (decode once as `[String: AnyJSON]`-free approach: decode a `struct Keys: Decodable` using a dynamic CodingKey and compare
the key set to the five allowed names); validate: schemaVersion == 1, prefix absolute path without `..` components, runtime id regex as above,
runtimeManifestSHA256 64 lowercase hex, generation 0...1000. `package func write(to url: URL) throws(HubError)`: encode sorted keys + pretty printed,
write atomically (`Data.write(options: .atomic)`), only if the parent directory exists (never create it here).

## SharedPrefix
`package struct SharedPrefix: Equatable, Sendable { package let configured: URL; package let resolved: URL; package let hops: [URL] }`.
`package static func locate(_ path: String, allowedRoots: [URL]) throws(HubError) -> SharedPrefix`:
1. `path` absolute, no `..`/`.` components after splitting on `/`; else `.invalid`.
2. If `HubPaths.volumeRoot(of:)` is non-nil and `!HubPaths.isMounted(...)` -> `.volumeMissing(volumeRoot)`. Do this BEFORE any other filesystem access.
   Apply the same check to each symlink hop target before following it.
3. Canonicalise the allowed roots with `realpath(3)` (skip roots that do not exist). Resolve the final component chain manually: up to 8 hops; for a hop,
   `lstat`; if it is a symlink, `readlink` (bounded buffer, PATH_MAX), resolve relative targets against the link's parent directory, record the hop;
   repeat. More than 8 hops or revisiting a path -> `.unsafePath("symlink loop: ...")`. After the last hop, `realpath(3)` the result; it and every
   hop's realpath'd parent must be equal to or inside (prefix + "/") one canonical allowed root, else `.unsafePath`.
4. The resolved directory: `lstat` is a directory (not a symlink), `st_uid == getuid()`, contains regular files `system.reg`, `user.reg` and directories
   `drive_c` (real directory) and `dosdevices`; else `.invalid("prefix incomplete: <what>")`.
`package func problems(runtime: URL?, drives: [String: String]) -> [PrefixProblem]` (no throwing, read-only):
- `dosdevices/c:` must be a symlink whose readlink equals `../drive_c` -> else `.cDrive(actual: String?)`.
- for each (letter, expectedTarget) in drives (letter lowercase `d`...`y`): `dosdevices/<letter>:` missing -> `.missingDrive(letter)`; symlink with a different
  readlink -> `.driveTarget(letter, actual, expected)`.
- if runtime != nil: compare the integer in `<prefix>/.update-timestamp` with `st_mtime` (seconds) of `<runtime>/share/wine/wine.inf`; mismatch or unreadable ->
  `.updateStamp(prefix: String?, runtime: String?)` (Wine would run a prefix update: must be reported, never ignored).
`PrefixProblem: Codable, Equatable, Sendable` enum with those cases plus `var summary: String` (one English sentence each).
`package func repairPlan(drives: [String: String]) -> [RepairStep]` where `RepairStep: Codable, Equatable, Sendable { letter: String; target: String }`
covering ONLY missing links (`c:` -> `../drive_c` when missing entirely, and missing declared drives); links that exist with another target are never in the plan.
`package func repair(_ steps: [RepairStep]) throws(HubError)`: re-check each link is still missing (lstat ENOENT) and create it with `symlink(2)`; never
remove or replace anything; never touches .reg files.
`package var serverRunning: Bool { PrefixActivity.serverIsRunning(prefix: resolved) }`.

## Tests (Swift Testing; temp dirs under FileManager.default.temporaryDirectory, removed in defer; remember /var -> /private/var realpath)
1 direct prefix locates, resolved == realpath. 2 chain link1 -> link2 -> real, hops recorded, resolved ok. 3 hop escaping the allowed root -> unsafePath.
4 loop a -> b -> a -> unsafePath. 5 `/Volumes/HubTestMissing-<UUID>/GameHub/Prefix` -> volumeMissing and `FileManager.fileExists` stays false for it.
6 missing system.reg -> invalid. 7 drive_c as a symlink -> invalid. 8 problems: wrong c:, missing e:, wrong e: target, updateStamp mismatch and match (set wine.inf
mtime with `utimes`/`FileManager.setAttributes`). 9 repairPlan contains only missing links; repair creates them; an existing wrong link is unchanged afterwards.
10 HubPaths.prepareTree on a missing root -> volumeMissing and nothing created; on an existing root creates the tree with mode 0700 for state. 11 HubConfig
round-trip; unknown key rejected; `..` prefix rejected; symlinked hub.json rejected. 12 runtime(id) rejects `../x`.
## Done
`swift build --scratch-path <scratch>` and `swift test --scratch-path <scratch> --filter HubCoreTests` succeed (prior 99 tests still pass). Report files, counts, deviations.
