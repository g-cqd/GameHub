---
status: accepted
date: 2026-10-15
---

# 0003: Our own forks, and everything merged into `main`

## Context
Before October 15 the forks carried several branch lines each: `development`, `master`, per-feature lines and
per-bundle runtime branches. They also carried a separate `wine-arm64` repository. The hub ran several unrelated Wine
builds (CrossOver, athei, current Wine), and nobody could say which fixes a given runtime contained. The owner: "we
want all to be merged into main, no dev branch anymore", and "our fork [should contain] all the refinements of all of
them as well as ours".

## Decision
- **One `main` per fork,** and all our work lands on it:

  | Fork | Upstream merged in |
  |---|---|
  | `g-cqd/wine` | `athei/wine cx-26-patched`, which carries the CrossOver patches |
  | `g-cqd/dxmt` | `3Shain/dxmt main` |
  | `g-cqd/mtld3d` | `athei/mtld3d main` |
  | `g-cqd/x87sidecar` | `athei/x87sidecar master` |

  The upstream sync is a merge or a rebase recorded in the fork's `UPSTREAM.md`, without force-pushing `main`.
- **The arm64 workspace** was folded into `wine/macos-arm64/` (2026-10-15).
- **DXMT stays on the fork.** Our DXMT commits are not proposed upstream.
- **Superseded branches** are kept only as archive tags, for the source offer of bundles already shipped.

## Consequences
- A runtime is described by one hash per fork (`docs/hub/upstream-sync-20261030.md`), and hub-2 is "every fork's
  `main`".
- The Wine rebase of 2026-10-14 duplicated a number of patches from October 8 and 13. Patch-id checks are part of
  every sync.
