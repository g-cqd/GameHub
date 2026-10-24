# T4a: runtime verification, Windows path resolution, versioned locations, target facts (spec; report, do not improvise)

Depends on T1a/T1b (Model, Knowledge), T3 (HubPaths, SharedPrefix), T5a (PEScanner, FolderMarkers). Swift 6, `package`, typed throws `throws(HubError)`,
no force unwraps / try! / DispatchQueue. Files: `Sources/HubCore/Plan/{RuntimeVerifier.swift, WindowsPath.swift, TargetFactsBuilder.swift}`, model edit below,
tests `Tests/HubCoreTests/{RuntimeVerifierTests.swift, WindowsPathTests.swift, TargetFactsTests.swift}`. All file I/O here is synchronous and must never be
called from the main actor by callers (document with `/// Blocking: call off the main actor.`).

## Model edit: `Location` gains kind `versionedWindowsPath { path, child }`
`path` like windowsPath; `child` = relative Windows path (backslash-separated, components non-empty, no `..`, <= 120 bytes) of the executable's folder
under the chosen version folder (EA: path "C:\Program Files\Electronic Arts\EA Desktop", child "EA Desktop"). Strict keys, validation, mutation tests.
Update T2 data: `recipes/providers/ea.json` location becomes {kind versionedWindowsPath, path "C:\\Program Files\\Electronic Arts\\EA Desktop", child "EA Desktop"}.

## RuntimeVerifier (`package enum RuntimeVerifier`)
- `keyFileProblems(_ m: RuntimeManifest, runtime: URL) -> [String]`: each keyFile must be a regular file (lstat, not symlink) whose SHA-256 (CryptoKit, streamed
  in 1 MiB chunks via FileHandle) equals; message per problem.
- `verifiedCapabilities(_ m: RuntimeManifest, runtime: URL) -> (verified: Set<Capability>, problems: [String])`: `file:<p>` -> `<runtime>/<p>` exists (lstat any type);
  `knob:<NAME>@<p>` -> the file contains the ASCII bytes of NAME (streamed search across chunk boundaries); `doc:` -> accepted. A failing evidence drops the capability.
- `manifestProblems(_ m: RuntimeManifest, manifestFile: URL, runtime: URL, full: Bool) -> [String]`: SHA-256 of manifestFile must equal m.manifestSHA256; when
  full, parse each line `<64 hex>  ./<relpath>` (two spaces; reject other formats) and hash each file under runtime (streamed); report mismatches, missing files,
  and runtime regular files not listed (walk without following symlinks; ignore `.DS_Store`). Cap 100 reported problems.
- `helperURL(_ m:, name:, runtimes: URL) -> URL?` and `helperProblems` (sha check of `<runtimes>/<helper.path>`).
- `backendDirectory(api: String, backend: String, runtime: URL) -> URL`: api in {dxgi, d3d11, d3d10core} -> `lib/wine/dxgi/<backend>`; {d3d9, d3d8} -> `lib/wine/d3d9/<backend>`.
  `backendProblems(apiBackends: [(api: String, backend: String)], runtime:) -> [String]`: the directory must exist and contain `i386-windows` or `x86_64-windows`;
  d3d8 with mtld3d additionally needs `lib/wine/d3d9/mtld3d/i386-windows/d3d8.dll`.

## WindowsPath (`package enum WindowsPath`)
- `parse(_ s: String) throws(HubError) -> (drive: Character, components: [String])`: `^[A-Za-z]:\\` prefix; components split on `\`, empty components dropped,
  `.`/`..` rejected, each <= 255 bytes without control chars or `/`.
- `hostURL(_ s: String, prefix: URL) -> URL?`: drive `c` -> `<prefix>/drive_c`; others: `readlink(<prefix>/dosdevices/<x>:)` (relative targets resolved against
  `<prefix>/dosdevices`); a missing link -> nil; under an unmounted /Volumes volume (HubPaths.isMounted) -> nil BEFORE touching it. Then each component: exact name if
  `lstat` succeeds, else a case-insensitive match among `contentsOfDirectory` entries (stop after 4096 entries; ambiguous -> the exact-case-sorted first); none -> nil.
  Symlinked components are followed (Wine does) but the result is returned unresolved.
- `windowsPath(drive: Character, components: [String]) -> String` (joins with `\`).
- `resolveVersioned(path: String, child: String, prefix: URL) -> (windows: String, host: URL)?`: host dir of `path`; children whose name passes
  `PreparedPrefixGame.isClientVersionFolder` (make it `package` if it is not); prefer real directories over symlinks, then highest version (compare the numeric
  dot-separated prefix before any `-`, then the whole name); first that contains `child` (case-insensitive resolution) wins; returns Windows path `path\<ver>\<child>`.

## TargetFactsBuilder (`package struct TargetFactsBuilder`)
`init(knowledge: Knowledge, prefix: URL, runtimeCapabilities: Set<Capability>)`;
`func root(of recipe: Recipe) -> (windows: String, host: URL)?`: windowsPath -> hostURL; versionedWindowsPath -> resolveVersioned; registry -> read the value from
`system.reg` (machine) or `user.reg` (user) with a minimal reader: find the line `[<key with \\ doubled>]` (case-insensitive) then the next lines until a blank line,
`"<name>"="<value>"` with `\\` unescaped; the value is a Windows path -> hostURL; hostPath -> URL if it exists; nil location -> nil.
`func facts(for recipe: Recipe) -> TargetFacts`: targetID, provider (recipe.provider ?? .none; a provider recipe's own provider), runtime caps, exe = recipe.executable;
machine = recipe.architecture raw; if root resolves and `<root>/<executable>` (case-insensitive) is a regular file: PEScanner.read -> machine (overrides), subsystem,
imports = imports ∪ delayImports (strip `.dll`), markers = FolderMarkers.scan(root). Scan failures are ignored (facts from the recipe only). exeSHA256 stays nil.
`func allFacts() -> [String: TargetFacts]` for every recipe.

## Tests (>= 16; temp prefixes: `drive_c`, `dosdevices/c:` -> `../drive_c`, `dosdevices/e:` -> temp dir)
RuntimeVerifier: keyFile ok/mismatch/symlink; knob found across a chunk boundary; capability dropped when evidence missing; manifest digest mismatch; full
manifest detects a modified, a missing and an unlisted file; backendProblems for missing `lib/wine/dxgi/gptk` and present dxmt.
WindowsPath: parse rejects `C:relative`, `..`; case-insensitive resolution `C:\PROGRAM FILES\ea` -> `drive_c/Program Files/EA`; e: drive; missing link -> nil;
`/Volumes/HubTestMissing-<UUID>` target -> nil without creating it; resolveVersioned picks `13.805.11.6320-1791598480` over `13.805.2.6319`, prefers real dir over
symlink alias `13.805.99.0`. Facts: synthetic PE (reuse PEFixture) in a temp game root yields imports and machine; missing exe -> recipe facts; registry location read.
## Done
build + HubCoreTests green via the brief's commands. Report files, counts, deviations.
