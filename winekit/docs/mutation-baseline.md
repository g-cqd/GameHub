# The mutation baseline

`.swift-mutation-testing-baseline.json` holds the mutants that no test can detect because no input tells them apart from
the original: equivalent mutants. The mutation gate fails on any undetected mutant not listed there. Every entry is
explained below; a mutant that a test *could* catch is never added, it gets the test.

`swift package --disable-sandbox quality mutation-baseline` rewrites the file from a full run; read the diff against this
list before committing it.

| Where | Mutation | Why it is equivalent |
|---|---|---|
| `Sources/HubRules/PEFacts.swift:15` | `offset < bytes.count` → `offset <= bytes.count` | At `offset == bytes.count` the original returns `[]`; the mutant reads the slice `bytes[count..<count]`, which is `[]` too. |
| `Sources/HubRules/PEFacts.swift:15` | `count > 0` → `count >= 0` | At `count == 0` the original returns `[]`; the mutant reads an empty slice, which is `[]` too. |
| `Sources/HubRules/PEFacts.swift:47` | `ntOffset >= 0` → `ntOffset > 0` | An NT header at offset 0 overlaps the DOS header, whose first bytes are `MZ`, so the `PE\0\0` signature check rejects it either way. |
| `Sources/HubRules/PEFacts.swift:79` | `index * 20 < maxImportSpan` → `<=` | `maxImportSpan` is 65,536, not a multiple of 20, so `index * 20` never equals it. (The `*` → `/` and the import-count mutants on that line are killed by `BoundaryTests`.) |

Mutation testing covers the code Wine runs (HubRules); QualityKit is tooling, held by its tests. Runs use the `default`
operator tier, at background priority on the efficiency cores, and every run, full or scoped, is compared with this
baseline by fingerprint (`MutationVerdict`), so the baseline doesn't depend on the run's scope.

The entries above date from the last full run (2026-11-01, experimental tier, 98.0%). A full run with the current
settings has not been made since the scope was reduced: `swift package --disable-sandbox quality mutation`.
