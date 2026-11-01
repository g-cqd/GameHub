---
status: in-progress
blocked-by: []
date: 2026-11-01
---

# 0033: Steam's relaunch after a self-update fails

Seen twice:

| When | Log | What happened |
|---|---|---|
| 2026-10-31 20:54 | `steam-20261031-205448.log` | The bootstrapper logged "Update complete, launching Steam..." and its thread died: `err:virtual:virtual_setup_exception nested exception on signal stack`. |
| 2026-11-01 02:11 | `steam-20261101-021034.log` (39 lines) | `bootstrap_log.txt`: "Update complete, launching Steam..." then "Shutdown", and no `steam.exe` came up. |

Starting Steam again afterwards works, because the update is already installed.

## Done when
After a client update, Steam relaunches itself and logs on without a second `hub start`. Until then, `hub` could
start Steam once more when the bootstrap log ends with "Update complete" and no `steam.exe` remains.

## Progress (2026-11-01)
Mitigation in `start_provider`: when Steam dies during start and `bootstrap_log.txt` reports "Update complete" since
the spawn, the hub starts the updated client once more. Not yet exercised: it needs the next client update. The
Wine-side cause (the relaunch's nested exception on the signal stack) is still open, and can only be reproduced
during an update.

