# T1a round 3 (Sonnet gate findings; all required). Worktree /Volumes/ExT2/GameHub/work/wt-hub-a.
## Sources (round 3a)
S1 Readiness.validate (ModelTypes.swift ~457): ports count 0...4; decode `events` and `ports` with `decode` (required arrays, may be empty). Fix the test ~ModelMutationTests.swift:1217 so `ports: []` is VALID; add a test that JSON without `ports` is rejected.
S2 A14: required (no default): Fix.evidence, Fix.requires, Launch.arguments, RuntimeSource.patchSeries. Only Fix.parameters, Fix.optIn and Recipe processes/fixes/settings/evidence may default. Update test JSON samples to include them.
S3 Remove every force unwrap: Validators.swift ~84 (bytes.first!), FixTypes.swift ~105 (num!), ~430 and ~449 (remaining.first!). parseBindsString over utf8 bytes, ASCII digits 0x30...0x39 only (no isNumber). dword: `if let n = UInt64(value), n <= 4294967295` with all-ASCII-digit precheck.
S4 imports condition: strip an optional trailing ".dll" (case-insensitive), then the rest must be 1...40 bytes of [a-z0-9_] (no "."). `a.b` rejected; `d3d9.dll` and `d3d9` accepted.
S5 windowsPath: minimum is the 3-byte `X:\`; split on both `\` and `/` when checking `..`; hostPath rejects control characters.
S6 Location.registry calls Check.registryKey and Check.registryValueName(name). Stop.arguments run the placeholder check like Launch.arguments. FixParameter choices pass the no-control, <=512-byte text rule.
S7 Setting int default parsed with Int(); float with Double(). FixParameter.type and Setting.type become String enums (bool, choice, int, float [, string for Setting]); Condition.Kind becomes a real `enum Kind: String, Codable, CaseIterable`.
S8 Remove the extra rule at RecipeTypes.swift ~772-776 (non-none provider requiring launch.method provider). Keep only: launch.method provider => provider non-nil and != none.
S10 drive letter lowercase d...y only.
## Tests (round 3b)
T9 Replace all `#expect(throws: HubError.self)` in ModelMutationTests.swift with `expectInvalid("<fragment>")` naming the field (use the actual message text); unknown-key tests assert the message contains "unknown key"; fragment at ~1026 -> "launch method provider". Each mutation must change exactly one thing of a VALID sample (so a missing required field never masks the tested check).
T10 Add accepted tests: provider recipe with launch.method direct; `{prefix}/drive_c/a` destination; `ports: []`; imports `d3d9`; windowsPath `C:\`. Add rejected: imports `a.b`; `C:\a/../b`; hostPath with \u{1}; Location.registry name with `"`; Stop.arguments `{bogus}`; FixParameter choice with \u{1}; Setting int default "1.5"; drive letter "D".
After T9: `grep -c "throws: HubError.self" Tests/HubCoreTests/Model*.swift` == 0.
