# T1a fixes from the Sonnet review (report, do not improvise). Worktree /Volumes/ExT2/GameHub/work/wt-hub-a. Spec T1a-model.md still governs.
## Part A: sources (Sources/HubCore/Model/*)
A1 Remove ALL NSRegularExpression / `pattern()` use (`$` matches before a trailing "\n": "FOO\n" was accepted). Add byte helpers in `Check`:
   `static func ascii(_ s: String, _ len: ClosedRange<Int>, first: (UInt8) -> Bool, rest: (UInt8) -> Bool) -> Bool` over `s.utf8`; rewrite every former regex
   (env/knob name, dll, dword hex, drive letter, window size, ids, offer ids, steamAppID, epicAppName, ubisoftID, patch id, commit, sha) with it. No force unwraps.
A2 `Check.destination(_ s:, field:)`: for p in ["{gameRoot}/", "{prefix}/drive_c/"] where s.hasPrefix(p): relativePath(String(s.dropFirst(p.count))); else throw.
   Use it for file.destination, ini.file, xml files, Setting.file. (dropFirst(18) was wrong.)
A3 `Condition` gets a strict init(from:) (allowed: kind, value).
A4 `Check.text`: control-char scan over the ORIGINAL unicodeScalars (tab is a control char), `s.utf8.count <= max` on the original; trimming only for emptiness.
A5 CapabilityEvidence: parse prefixes: `file:` -> relativePath; `knob:` -> split once on "@", knob name rule + relativePath; `doc:` -> text max 200; else throw.
A6 `Check.registryKey(_ key:, hive:, field:)` extracted from FixAction (machine env root must be EQUAL to `System\CurrentControlSet\Control\Session Manager\Environment`
   or that + `\`...; no prefix match); `Check.registryValueName` (1...255 bytes, no control chars, no `"`). Use for FixAction.registry, Location.registry (+ name),
   Setting registry store (key + section as value name).
A7 Setting: validate type membership (bool|choice|int|float|string), defaultValue/choices with Check.text-like no-control rule (<=512), choice/int/float bounds as FixParameter.
A8 Recipe: `if launch.method == .provider { guard let p = provider, p != .none else throw }` (the old rule was inverted).
A9 urlTemplate: must contain ":"; scheme before it in the allowed set; no control chars or spaces; <= 512.
A10 ReadinessEvent.state restricted to starting, needsSignIn, ready, launching, failed.
A11 Parameter binds: switch on (action kind, field) and allow only env.value, renderer.backend, arguments.append, sidecar.enabled, window.size, window.enabled,
    ini.value, registry.value; index < actions.count.
A12 windowsPath: no minimum besides `X:\`; split on both `\` and `/` for `..`; hostPath no control chars; Stop.arguments validated like Launch.arguments;
    URLs (Prerequisite, Install.url/page): https, <= 400 bytes, no spaces/control chars.
A13 dword: decimal = all ASCII digits (no +, value <= 4294967295 checked via UInt64); hex `0x` + 1...8 hex digits. int parameter defaults via Int(); choices pass text rule.
A14 Only these may default when absent: Fix.parameters, Fix.optIn (T1b), Recipe processes/fixes/settings/evidence. Everything else required (`decode`).
A15 Check.relativePath also rejects `\` and `:` anywhere.
A16 Validate: Recipe.evidence entries (text<=300), Launch.executable (Check.exe), legacyWrapper present only with method wrapper, ProposalRule.propose.fixes ids,
    Patch.title/ref no control chars, RuntimeManifest title/wineVersion text, helpers keys Check.id.
A17 Naming: `Condition.Kind` nested; FixParameter.type, Setting.type enums; Fix.requires [Capability]; TargetFacts Equatable; Predicate.all([])/any([]) match false.
A18 No force unwraps anywhere (parseBindsString on utf8 bytes; ASCII digits only).
## Part B: tests (Tests/HubCoreTests/Model*.swift)
B1 Helper `expectInvalid(_ fieldFragment: String, _ body: () throws -> Void)` asserting `HubError.invalid(m)` with `m.contains(fieldFragment)`.
B2 Every mutation starts from a VALID sample (a function returning valid JSON dictionaries / objects) and changes exactly ONE thing; predicates in samples are non-empty.
B3 >= 60 mutations incl.: newline-suffixed env name, drive letter, dword, dll, patch id, steamAppID; `{prefix}/drive_c//x`, `{prefix}/drive_c/\u0001x` rejected and
   `{prefix}/drive_c/a` ACCEPTED; nested unknown keys for Condition, Readiness, ReadinessEvent, Location (each kind), each FixAction kind, Stop, Install, Checksum,
   StoreIDs, Setting, RuntimeManifest, Patch, Knob, Prerequisite, ProposalRule; `reason:"ok\t"`; long whitespace text; evidence `file:../x`, `file:/abs`,
   `knob:FOO@../x`; registry Setting key `Windows\x`; machine `...EnvironmentX`; game recipe method provider without provider (rejected) and provider recipe with
   method direct (accepted); urlTemplate `/bin/sh` and `steam://x\n`; ReadinessEvent state running; binds `actions[0].size` on env and `.value` on sidecar;
   dword `+5`; int parameter default `1.5`; `C:\a/../b`; relativePath with `\` or `:`; missing required arrays (e.g. Readiness without ports).
B4 Round-trip compares whole values (`==`) for every sample type. Predicate.matches table >= 14 rows (marker, runtimeHas, target, subsystem, sha equal, any false,
   all partial fail, empty list false, nil fact).
B5 `Data(json.utf8)` instead of force unwraps.
