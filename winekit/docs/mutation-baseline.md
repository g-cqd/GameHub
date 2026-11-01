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
| `Sources/HubRules/PEFacts.swift:75` | `index * 20 < maxImportSpan` → `<=` | `maxImportSpan` is 65,536, not a multiple of 20, so `index * 20` never equals it. (The `*` → `/` and the import-count mutants on that line are killed by `BoundaryTests`.) |

Last full run (2026-11-01, swift-mutation-testing 1.6.4, experimental tier): 328 mutants, 297 viable; 293 detected and
these 4 undetected, a score of 98.7%. Every QualityKit mutant is detected.
