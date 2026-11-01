---
status: done
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

## Result (2026-11-01)
- `session.json` is written when the store is spawned (`record_session`), so a retry during the start reuses the
  session. Checked live: a `hub play` 8 s into a Steam start launched the game without restarting Steam.
- Steam's logon wait follows `steam_start_verdict`: done when logged on; died when `steam.exe` has been gone for 10 s
  (a shorter gap is Steam relaunching itself); timeout after 600 s with Steam left running; otherwise wait, with a
  note every minute. It has five unit tests in `launcher/tests/test_steam.py`.
- The live check also caught a real death: Steam updated itself and its relaunch never came up (roadmap 0033).
  The hub now says so instead of waiting out a timeout.

