---
status: not-started
blocked-by: []
date: 2026-10-31
---

# 0031: `hub play` gives up on a slow Steam start, and the retry restarts Steam

Observed several times on 2026-10-31 (23:12, 23:49, 23:52):

1. `start_provider` waits 120 s for "Logged On" in `connection_log.txt`. Steam needs longer when it updates itself
   or restarts its web helpers, so `hub play` exits with "Steam did not log on" while Steam keeps starting.
2. `session.json` is written only after a successful logon. The next `hub play` finds no session, treats any
   explicit option (`--debug`) as a changed environment, and restarts the prefix: Steam starts from zero again.

## Done when
A slow Steam start doesn't make `hub play` give up, as long as `steam.exe` is alive, and a retry while Steam is still
starting waits for it instead of restarting it. Both are covered by unit tests of the decision logic.
