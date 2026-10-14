# Swift mirror of the Python import-rules changes (spec only; no Swift was edited or built)

Python is the reference: `Packaging/recipes.py` on branch `bf4-recipe-schema`, gate `Packaging/check_bf4_recipe_schema.py`
(cases are listed there; port each one to `ImportRulesTests`). The Swift side reads the same JSON.

## 1. `machine` (already in the Python at b028857)
- `ImportRules.swift:100`: `expectedMachine` returns only `machineI386` for "i386". Add `"x86_64"` -> `PortableExecutable.machineX8664 = 0x8664`
  (new constant in `PortableExecutable.swift`); any other string stays invalid. `validate()` already rejects `nil`.
- `InstallScanner.swift:88-89`: the error text says "32-bit"; make it say which machine the recipe expects.
- `PortableExecutable.read` must accept PE32+ (optional header magic 0x20b) when machine is 0x8664; check it does not hard-code PE32 offsets.

## 2. `rootFiles` (new; this commit)
JSON: optional key `rootFiles` in `importRules`: array of bare file names. Absent key = today's behaviour exactly.

Decoding/encoding (`ImportRules` is `Codable` and is embedded in the bundle manifest):
- Add `package let rootFiles: [String]` with default `[]`; decode with `decodeIfPresent`, encode ONLY when non-empty
  (`encodeIfPresent`/custom `encode`) so every existing manifest stays byte-identical. A present-but-empty array is invalid (see below), so
  keep "absent" and "empty" distinguishable on decode (decode into `[String]?` then validate).

`validate()` rules (same order and strictness as `validate_import_rules`):
1. If present: 1...16 entries, else invalid.
2. Each entry must fully match `[A-Za-z0-9][A-Za-z0-9._ ()-]{0,63}` (ASCII only; no `/`, `\`, NUL, control characters, leading dot or space, `.`/`..`).
3. Lower-cased entries are unique.
4. No entry equals (lower-cased) the first path component of any `directories[].path`.
5. A `required` path is accepted if it equals (lower-cased) a `rootFiles` entry OR starts with a directory root + "/". (Today only the second.)
6. Every `rootFiles` entry must also appear (lower-cased) in `required`.
7. The executable must still be a `required` path; it may be a root file.
Nothing else in `validate()` changes (pairings, markers, knownBuilds, limits).

`InstallScanner.scan`:
- The `required` loop already resolves any relative path with `resolve(..., wantsFile: true)`; verify it accepts a single-component path and still rejects
  symlinks/aliases.
- After the `directories` loop, for each `rootFiles` entry: resolve it directly under `root` (case-insensitive match against the folder listing, regular file,
  no link), `describe` its size, and append a `Found` (relative = the entry as it exists on disk). Count its bytes in `totalBytes` against
  `maximumBytes`, and include it in the `found.count <= maximumFiles` check.
- The case-collision check (`seen`) must include the root files; a root file named like a file inside a directory cannot happen (rule 4) but a case clash
  between two root-level names is already rejected by rule 3.
- The executable lookup (`found.first(where: relative == executable)`) then finds `bf4.exe` at the root; digest/inventory loops need no change.
- The copy/seed step that uses `InstallScan.inventory`: confirm it copies root files (it copies by inventory path today, so it should), and
  that nothing assumes every inventory path has a directory component (look for `components(separatedBy: "/").first` style code).

## 3. `offerID` list and `storeClient` fields (b028857, not yet mirrored)
- `StoreClientPlan.swift`: `offerID` becomes "one decimal id (string) OR 1...32 distinct decimal ids (`[0-9]{1,20}`)"; the expanded launch URL is at most 512 bytes.
  Keep the string form decoding/encoding unchanged; encode a single id as a string so shipped manifests do not change.
- Optional `launchChain` (bounded list of bare `.exe` names), `leaseTarget` (must be in `launchChain`), `expectedPorts` (bounded list of ints in 1024...65535): exact
  bounds are in `recipes.validate_store_client`; port them literally.
- `gameExecutable` / `deniedBackends` per recipe: defaults are today's NFS 2015 constants; a recipe may only ADD denials.

## 4. Tests to port
- `ImportRulesTests`: every accept/reject case in the gate's "Root files" and "Machine" sections.
- `InstallScannerTests`: a synthetic folder with a root-level executable (PE32+ header, machine 0x8664), a missing root file, a symlinked root file, a root file
  below `minimumSize`, and a count/bytes limit hit by root files.
- Fixtures that use `offerID: String` (`SyntheticPrefix`, `NFS2015LaunchTests`, `NFS2015GameKindTests`, `SeededFixture`, `ImportRulesTests`) keep compiling if the
  new type keeps a `String` initializer; otherwise update them.
- `Tests/GameFixtures/RecipeRules.swift` loads the shipped recipe JSON: it must still pass untouched, which is the byte-identity check on the Swift side.
