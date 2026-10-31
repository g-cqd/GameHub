---
status: accepted
date: 2026-10-31
---

# 0009: hub-2 is the unified runtime for every store

## Context
- **hub-1** (2026-10-24) unified the earlier runtimes (hub-0 variants for EA identity and others), but it was built
  from forks that later moved on.
- **hub-2** (2026-10-30) was assembled from scratch from every fork's `main` with the same file set
  (`docs/hub/upstream-sync-20261030.md`). It has the upstream DXMT, mtld3d and Wine work, the dsound resampler and the
  new DXMT staging allocator.
- **What ran where:** the 64-bit Steam client was tested only on hub-2 (ADR-0010). The owner asked for everything to
  run on hub-2 and for hub-1 to be deleted.

## Decision
`PROVIDER_RUNTIME` maps every provider (steam, ea, ubisoft, epic, direct) to hub-2. This landed in b2455c8 on
2026-10-31; see ADR-0017 for how. hub-1 stays on disk, reachable with `--runtime hub-1`, until EA and Epic have
passed on hub-2.

## Evidence so far
- **Works on hub-2:** Steam (64-bit client), Crysis 2 Remastered, Battlefield 3, Ubisoft Connect (in software,
  ADR-0012).
- **EA:** did not finish booting within 150 s on 2026-10-31. That was under memory pressure (swap at 6 of 7 GB, four
  launchers open), so it is not conclusive.
- **Epic:** untested.

## Consequences
- Roadmap 0004 owns the EA and Epic retests and the deletion of hub-1.
- New runtimes are assembled with `OLD_RT=hub-2`, the source of `compatdb.so` and `lib/external`. So deleting hub-1
  doesn't break assembly.
