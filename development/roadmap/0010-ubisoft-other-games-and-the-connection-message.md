---
status: not-started
blocked-by: []
date: 2026-10-31
---

# 0010: The other Ubisoft games, and the "connection issues" message

- **Other games:** check Play against Install for Far Cry 2, AC Unity and Watch Dogs 2.
- **The message:** the owner reported "connection issues". No session has seen it, and the Wine logs have no DNS, TLS
  or timeout lines. Capture the text with a screenshot, then delete the screenshot. Compare it with
  `Library/Ubisoft/logs/launcher_log.txt` and `service_log.txt`.
- **A known error:** `GameCatalogExtensionRegistration.cpp (571) Error: 5` (access denied) appears in every session
  since 2026-10-24, on hub-1 and hub-2.

## Done when
Each game's Play state is known, and the message has a cause or a fix.
