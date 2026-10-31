---
status: not-started
blocked-by: []
date: 2026-10-31
---

# 0027: A native front end over `launcher/hub`

The owner wants "proper ways to run our apps" instead of scripts. A menu-bar or library app lists the games,
plays them and shows the session state, with `launcher/hub` as its only engine (ADR-0013). The earlier GameHub.app
(2026-10-10/11) is the starting point.

## Done when
A game can be found and started from the app, and the app holds no launch logic of its own.
