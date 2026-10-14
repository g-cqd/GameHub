# T1a: HubCore knowledge data model + validators (spec; implement exactly, report, do not improvise)

Repo: worktree given in the brief (detached, package /Users/gc/Developer/nfs-macos layout). Swift 6 language mode, strict concurrency.
Design reference: /Volumes/ExT2/GameHub/docs/hub-shared-prefix-design-20261011.md sections 3-5.
All new types: `package` access, `Codable, Equatable, Sendable` (enums also `CaseIterable` when payload-free). No classes, no singletons,
no Foundation `JSONSerialization`, no `try!`, no force unwraps, no `fatalError`. Errors: throw `HubError.invalid("<Type>.<field>: <reason>")`
(existing enum in Sources/HubCore/HubTypes.swift; do NOT add cases). Use typed throws `throws(HubError)` for validate functions.
Files go in `Sources/HubCore/Model/` (new folder) and `Tests/HubCoreTests/ModelTests.swift`, `Tests/HubCoreTests/ModelMutationTests.swift`.
One change outside HubCore is allowed: in `Sources/LauncherCore/RendererSelection.swift` change `func rule(name:)`, `func serves(_:)` and
`static func isExecutableName(_:)` from internal to `package` (no other edit there).

## Strict decoding
`StrictDecoding.swift`: `struct AnyCodingKey: CodingKey` (string + int init) and
`package func rejectUnknownKeys(_ decoder: any Decoder, allowed: Set<String>, type: String) throws` that reads
`decoder.container(keyedBy: AnyCodingKey.self).allKeys` and throws `HubError.invalid("\(type): unknown key <k>")` for any key not allowed.
Every struct below implements `init(from:)` manually: first `rejectUnknownKeys`, then decode its fields (optional fields with `decodeIfPresent`).
Encoding may be synthesized. Enums with a `kind` discriminator (FixAction, Location) decode `kind` first, then reject keys not allowed for that kind.

## Shared validators (`Validators.swift`, `package enum Check`)
- `id(_ s: String, field:)`: regex `^[a-z0-9][a-z0-9-]{0,47}$`.
- `text(_ s:, field:, max:)`: non-empty after trimming, <= max UTF-8 bytes, no control characters (U+0000-U+001F, U+007F).
- `exe(_ s:, field:)`: `RendererSelection.isExecutableName(s)` must be true (also accept the literal `*` only where the spec says so).
- `sha256(_ s:, field:)`: exactly 64 chars `[0-9a-f]`.
- `relativePath(_ s:, field:)`: non-empty, <= 240 bytes, no leading `/` or `\`, no component `..` or `.` or empty (split on `/`), no control chars.
- `placeholders(_ s:, field:)`: every `{...}` occurrence must be one of `Placeholder` raw values; unbalanced `{` or `}` rejected.
- `Placeholder: String, CaseIterable`: `prefix, hubRoot, gameRoot, providerRoot, eaClientDir, offerIDs, appID` (raw value = case name).

## Types
1. `Capability: String` cases exactly: trapFlagEmulation, rosettaRwxWxEmulation, rosettaRwxWxPageLog, crashContextBlock, crashContextCodeWindows,
   rosettaPageExperiments, x87Sidecar, dxmtDXGI, compatdb, wined3dDXGI, mtld3dD3D9, mtld3dD3D8, dsoundSSE2, caseFoldCache, exeListSwitches.
2. `ProviderID: String` cases: ea, steam, epic, ubisoft, none.
3. `Condition { kind: Kind; value: String }`, `Condition.Kind: String` = exe, exeSHA256, machine, imports, subsystem, marker, provider, runtimeHas, target.
   validate per kind: exe -> Check.exe; exeSHA256 -> Check.sha256; machine in {i386, x86_64}; imports -> regex `^[a-z0-9_]{1,40}(\.dll)?$`;
   subsystem in {gui, console}; marker -> Check.relativePath; provider -> ProviderID raw; runtimeHas -> Capability raw; target -> Check.id.
4. `Predicate`: enum `all([Condition])`, `any([Condition])`; JSON `{"all":[...]}` or `{"any":[...]}` exactly one key. validate: 1...16 conditions, each valid.
   `func matches(_ facts: TargetFacts) -> Bool`.
5. `TargetFacts { targetID: String; exe: String?; exeSHA256: String?; machine: String?; subsystem: String?; imports: Set<String>; markers: Set<String>;
   provider: ProviderID; runtime: Set<Capability> }` (memberwise package init). Matching: exe case-insensitive equality; exeSHA256 equality;
   machine/subsystem equality; imports: strip a trailing `.dll`, lowercase both sides, membership; marker: exact membership; provider: raw equality;
   runtimeHas: membership; target: equality with targetID. A nil fact never matches.
6. `EnvScope: String` = session, prefixMachine. `Knob { name; scopes: [EnvScope]; reason }` validate name regex `^[A-Z][A-Z0-9_]{1,63}$`, scopes non-empty, reason text<=200.
7. `Prerequisite { id; title; url; sha256; kind: msi|exe; arch: i386|x86_64|both }` (nested String enums). url must start with `https://`, <= 400 bytes.
8. `Readiness { log: String; startMarker: String?; events: [ReadinessEvent]; ports: [Int]; timeoutSeconds: Int }`,
   `ReadinessEvent { state: ProviderState; contains: String; log: String? }`.
   validate: log Check.relativePath; startMarker text<=200 if present; events 0...16, state must be one of starting, needsSignIn, ready, launching, failed,
   contains text<=200, log relativePath if present; ports 0...4 each 1...65535; timeoutSeconds 1...900.
9. `ProviderState: String` = notInstalled, stopped, starting, needsSignIn, ready, launching, running, stopping, failed, blocked.
10. `FixAction` enum (JSON object with `kind`):
   - `env(name: String, value: String, scope: EnvScope)` keys kind,name,value,scope. validate: value text-like but may be empty? NO: value 1...512 bytes no control chars; name format as Knob.
     (Knob allow-list membership is checked later by the knowledge loader, not here.)
   - `renderer(exe: String, api: String, backend: String)`: exe is Check.exe or `*`; `RendererSelection(api:backend:executable:).validate()` must pass
     (map LauncherError to HubError.invalid); backend in {dxmt, wined3d, mtld3d}.
   - `dllOverride(exe: String?, dll: String, mode: String)`: dll regex `^[A-Za-z0-9_.-]{1,64}$`; mode in {"native,builtin","builtin","native","builtin,native","disabled"}; exe Check.exe if present.
   - `registry(hive: String, key: String, name: String, type: String, value: String)`: hive in {user, machine}; key: <=255 bytes, no control chars, no `]`, no `/`,
     not starting/ending with `\`, no empty component when split on `\`, must start with `Software\` or (hive machine only) `System\CurrentControlSet\Control\Session Manager\Environment`;
     name 1...255 bytes no control chars and no `"`; type in {string, dword}; dword value: decimal 0...4294967295 or `0x` + 1...8 hex; string value <=1024 bytes no control chars; placeholders checked in value.
   - `file(asset: String, destination: String, sha256: String)`: asset Check.relativePath; destination must start with `{gameRoot}/` or `{prefix}/drive_c/` and the rest Check.relativePath; sha256.
   - `ini(file: String, section: String, key: String, value: String)`: file as destination above; section 1...128 no `]`/control; key 1...128 no `=`/control; value <=512 no control.
   - `drive(letter: String, target: String)`: letter regex `^[d-y]$`; target in {"{hubRoot}", "{gameRoot}"}.
   - `arguments(exe: String, append: [String])`: exe Check.exe; 1...16 args each 1...256 bytes no control chars; placeholders checked.
   - `sidecar(enabled: Bool)`.
   - `window(mode: String, size: String?, enabled: Bool?)`: mode virtualDesktop requires size regex `^[0-9]{3,4}x[0-9]{3,4}$` and enabled nil; mode retina requires enabled non-nil and size nil.
   - `prerequisite(id: String)`: Check.id (table membership checked by the loader).
   - `companion(exe: String, after: String, readiness: Readiness)`: exe Check.exe; after must equal "ready"; readiness valid.
11. `FixStatus: String` = verified, experimental, rejected. `FixParameter { id; title; type: bool|choice|int|float; defaultValue (JSON key "default", String);
    choices: [String]?; range: [Double]?; binds: String }`. validate: id Check.id; title text<=80; choice needs 2...16 choices and default in choices;
    int/float need range of exactly 2 with lower<upper and default parseable within it; bool default "true"/"false"; binds regex `^actions\[([0-9]{1,2})\]\.([a-zA-Z]+)$`.
12. `Fix { id; title; reason; status: FixStatus; evidence: [String]; appliesWhen: Predicate; requires: [Capability]; actions: [FixAction]; parameters: [FixParameter] }`
    (parameters optional in JSON, default []). validate: id; title<=80; reason<=400; evidence 0...8 entries text<=300, and >=1 when status is verified or rejected;
    appliesWhen valid; actions 1...32 each valid; each parameter valid AND its binds index < actions.count AND the field is bindable for that action kind:
    env.value, renderer.backend, arguments.append (whole list replaced by one value), sidecar.enabled, window.size, window.enabled, ini.value, registry.value; parameter ids unique.
13. `RecipeKind` game|provider; `RecipeStatus` verified|unverified|proposed; `Architecture` i386|x86_64.
    `StoreIDs { eaOfferIDs: [String]?; steamAppID: String?; epicAppName: String?; ubisoftID: String? }`: offer ids regex `^[A-Za-z0-9:._-]{1,64}$` (1...32 of them);
    steamAppID `^[0-9]{1,10}$`; epicAppName `^[A-Za-z0-9_.-]{1,64}$`; ubisoftID `^[0-9]{1,10}$`.
    `Location` enum JSON `{"kind":"windowsPath","path":...}` | `{"kind":"registry","hive":...,"key":...,"name":...}` | `{"kind":"hostPath","path":...}`:
    windowsPath regex `^[C-Zc-z]:\\` then <=240 bytes, no control chars, no `..` component; registry like FixAction.registry key rules; hostPath absolute, no `..` component.
    `LaunchMethod` direct|provider|browser|wrapper. `Launch { method; executable: String?; arguments: [String]; urlTemplate: String? }`:
    urlTemplate scheme (before `:`) in {origin2, link2ea, steam, com.epicgames.launcher, uplay}, <=512 bytes, placeholders checked; arguments as FixAction.arguments but 0...16.
    `Stop { arguments: [String]?; taskkill: [String] }` taskkill 1...16 Check.exe.
    `Checksum { policy: pinned|authenticodeRecord; sha256: String?; signer: String? }` pinned requires sha256; authenticodeRecord requires signer text<=120.
    `Install { url; page; checksum: Checksum; command: [String] }` url/page https, command 1...16 args no control chars.
    `SettingStore` hub|ini|registry. `Setting { id; title; group; store; file: String?; section: String?; key: String?; type: bool|choice|int|float|string; defaultValue ("default"); choices; range }`:
    ini needs file (destination rule as FixAction.ini), section, key; registry needs key + section (= value name) with registry key rules; hub needs none of file/section.
    `Recipe { schemaVersion: Int (must be 1); id; kind; title; status; evidence: [String]; provider: ProviderID?; ids: StoreIDs?; location: Location?;
      executable: String?; architecture: Architecture?; processes: [String]; leaseTarget: String?; launchChain: [String]?; launch: Launch; stop: Stop?;
      readiness: Readiness?; fixes: [String]; settings: [Setting]; install: Install?; legacyWrapper: String? }`
    (processes, fixes, settings, evidence default [] when absent). validate: kind provider => provider non-nil and != none, stop and readiness non-nil, executable non-nil;
    kind game => readiness may be nil; executable Check.exe if present; processes/launchChain/leaseTarget Check.exe; fixes each Check.id, unique; settings ids unique, each valid;
    launch.method provider requires provider non-nil and != none; launch.method wrapper requires legacyWrapper text<=120; status verified requires >=1 evidence.
14. `RuntimeManifest { id; title; wineVersion; source: RuntimeSource{origin; revision: String?; patchSeries: [String]}; manifestSHA256; keyFiles: [String: String];
    capabilities: [CapabilityEvidence{id: Capability; evidence: String}]; helpers: [String: Helper{path; sha256}] }`. evidence regex: `file:<relativePath>`,
    `knob:<NAME>@<relativePath>`, or `doc:<text<=200>`; keyFiles keys Check.relativePath values sha256 (1...64 entries); helper path Check.relativePath.
15. `Patch { id (regex ^[0-9]{4}$); title; capability: Capability?; ref: String (<=120); commit: String? (regex ^[0-9a-f]{7,40}$); status: FixStatus }`.
16. `ProposalRule { id; when: Predicate; propose: Proposal{ fixes: [String]; provider: ProviderID? } }`.
17. Plain data (no validation, synthesized Codable OK): `LaunchPlan { target; runtime; prefix; executable; arguments: [String]; environment: [String: String];
    compatdb: String; sessionProfile: [String: String]; pendingActions: [PendingAction{owner: String; action: FixAction}]; warnings: [String]; refusals: [String] }`,
    `TargetStatus { target; state: ProviderState; reason: String?; pid: Int32?; since: Date?; log: String?; ports: [Int: Bool] }`,
    `LedgerEntry { time: Date; fix: String; target: String; action: FixAction; before: String?; after: String; backup: String? }`.

## Tests (Swift Testing, style of Tests/HubCoreTests/HubTypesTests.swift)
- ModelTests: decode a valid JSON sample of each of Fix (with 3 actions incl. renderer + env + companion and 1 parameter), Recipe (provider EA-like
  and game BF3-like), RuntimeManifest, Patch, Knob, Prerequisite, ProposalRule; validate passes; encode->decode round-trips equal.
  Predicate.matches table: >= 12 cases incl. case-insensitive exe, `d3d9.dll` vs `d3d9`, nil fact, any vs all.
- ModelMutationTests: from each valid sample, a table of >= 40 single mutations total (unknown key, bad id, `..` path, bad sha, out-of-range port,
  `{bogus}` placeholder, renderer backend `gptk`, dword `0x1FFFFFFFF`, parameter binds index out of range, binds unbindable field, verified fix without
  evidence, provider recipe without stop, urlTemplate scheme `http`, windowsPath `C:relative`, registry key starting `System\` in user hive,
  hostPath with `..`, 17 conditions...) each must throw HubError (decode or validate).
## Done
`swift build --scratch-path <scratch>` and `swift test --scratch-path <scratch> --filter HubCoreTests` both succeed; all prior 99 HubCore tests still pass.
Report: files created/changed, test counts (before/after), any spec point you could not satisfy (do not silently deviate).
