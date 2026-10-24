# GameHub docs

Start with the table; each folder holds its own README or index where it needs one.

| Folder | What it holds |
|---|---|
| `hub/` | How the hub works today: Steam/Act of Aggression setup, restarting the Wine session, `compatdb.so` provenance, the per-program fix plan, and `hub-specs/` |
| `knowledge/` | Developer handoffs and synthesis: `games.md` (game bundles), `mtld3d-x87.md` (renderer and x87 sidecar), `wine-sdks.md`, and `Mac-Gaming-Knowledge-Synthesis-20261014.md` |
| `eaac/` | The EA anti-cheat (EAAC) investigation; `history/` has superseded reports and `evidence/` the text-only evidence |
| `bundler-plan/` | Design and inventory notes for the bundler in `../apps/bundler` |
| `bf4-tools/`, `ea-helper/` | Battlefield 4 recipe tooling and the EA helper design |
| `history/` | Dated plans, surveys and status snapshots of the 2026-10 consolidation. They describe the past; paths and branch names in them are not current |

The Swift bundler and its own documentation (NFS 2015, Most Wanted, Call of Duty 4, Far Cry 2, tuning, bundling, licensing,
source offer) are in [`../apps/bundler/docs/`](../apps/bundler/docs/); the entry point is
[`DEVELOPER-HANDOFF.md`](../apps/bundler/docs/DEVELOPER-HANDOFF.md).

Check the internal links with `python3 scripts/check_links.py` from the repository root.
