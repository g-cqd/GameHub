---
status: done
blocked-by: []
date: 2026-10-31
---

# 0003: Static analysis of every project, and fix every real finding

The owner asked for a review of all research, commits and agent sessions, then a static-only bug hunt with real
checkers, with every real finding fixed.

## Done when
Every fork and the hub have had their checker run (ADR-0015), every real finding is fixed, built, committed and
pushed, and the false positives are recorded.

## Result (2026-10-31)
Done. Diary 2026-10-31-03 has the list.

| Repo | Commits |
|---|---|
| Wine | 941e02e … ff91cd1 (7 commits) |
| DXMT | d907082 |
| x87sidecar | 4f2e62e |
| mtld3d | 4a2f494 |
| GameHub | b2455c8, d275a82, 4677479 |

Installed into hub-2: ntdll, dsound, dinput, dinput8, ncrypt, the DXMT PEs and x87sidecar. Nothing was run. The
checkers are in `scripts/static-analysis/`.
