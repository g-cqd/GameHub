---
status: accepted
date: 2026-10-11
---

# 0002: Code lives in the repository; runtimes and game data live on ExT2

## Context
Work had spread across `~/Library/Application Support`, the desktop, scratch folders on ExT2 and the internal disk.
The owner: "the code of gamehub, not the compiled app, should be in our developer folder on the internal disk", with
"game data to be stored on ext2", and "this should be configurable".

## Decision
- **Code:** everything that is code, configuration or knowledge is in `~/Developer/GameHub` and the fork
  repositories in `~/Developer`. That covers the launcher, scripts, rules, settings and docs.
- **Data:** `HUB_ROOT` (default `/Volumes/ExT2/GameHub`) holds only data:
  - `Prefix/`
  - `Runtimes/`
  - `Library/` and `EA Games/`
  - `Hub/{Logs,State,Home,Temp}`
  - `build/` and `sdk/` trees
  - `Backups/`
- **No code on ExT2:** nothing on ExT2 is needed from the repository, and nothing in the repository depends on a file
  that exists only on ExT2, except the built artifacts it assembles.

ExT2 is a case-sensitive APFS volume. The name is historical and has nothing to do with ext2.

## Consequences
- The old scripts on ExT2 (`bin/hubenv.sh`, `bin/start-steam.sh`) are superseded and are to be deleted (roadmap
  0020).
- A path that the launcher derives from `HUB_ROOT` must not be hard-coded elsewhere.
