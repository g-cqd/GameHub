---
status: not-started
blocked-by: []
date: 2026-10-31
---

# 0006: Launch the Steam games registered on 2026-10-31

The 2026-10-31 handoff registered these games. None of them has been started.

| Game | App id | State |
|---|---|---|
| HITMAN 3 | 1659040 | Steam updated it to Fully Installed. |
| Crysis Remastered | 1715130 | No `content_log.txt` lines yet; confirm Steam shows it as installed. |
| Wolfenstein II | 612880 | Steam rewrote the hand-written manifest (build 3329064), replaced 245 files and lists it as Fully Installed. |

This is also the first test of a game launched through the 64-bit client.

## Done when
Each of the three reaches its menu through `hub play`, and its DXMT log is clean of pipeline failures. Any failure
becomes its own item.
