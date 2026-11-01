---
status: done
blocked-by: []
date: 2026-10-31
---

# 0021: Stores quit cleanly before the prefix stops

`hub stop` kills the prefix (`wineserver -k`), so Steam never shuts down cleanly (ADR-0018). `steam.exe -shutdown` run
without the hub's session environment did nothing on 2026-10-31.

## Work
`hub stop` first asks each running store to quit through the hub's own `spawn()`, with the session environment. It
waits up to a bound, and only then kills the prefix. It also refuses while a game runs, unless `--force`.

## Done when
Steam's log shows a clean shutdown after `hub stop`, and `hub stop` refuses while a game runs.

## Progress (2026-10-31)
- `stop_all()` first runs `steam.exe -shutdown` through `spawn()` with the session's own environment, rebuilt from
  `session.json`, and waits up to 30 s.
- `hub stop` refuses while a game runs, unless `--force`.

Not run yet, because the owner was playing.

## Result (2026-11-01)
Three polite shutdowns (`steam-shutdown-*.log`, 2026-10-31 23:39 and 23:49, 2026-11-01 02:10) each made Steam log
"Log session ended" within a second, before the prefix was stopped. Refusing while a game runs is in `cmd_stop`;
that has not been exercised live.
