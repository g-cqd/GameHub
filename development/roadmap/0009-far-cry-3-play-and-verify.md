---
status: not-started
blocked-by: []
date: 2026-10-31
---

# 0009: Far Cry 3 starts, through Ubisoft Connect or directly

## Failures seen on 2026-10-31

| Action | Failure |
|---|---|
| Play | `HKEY_CURRENT_USER\SOFTWARE\UBISOFT\Far Cry 3\ExecutableName` missing ("Game executable is not found"). |
| `FC3Updater.exe -write_registry` | Should write that value, but crashed in `FC3.dll` (a null read near +0x1eb1). |
| Verify | `VerifyGame.cpp (135) UplayService generic failure`. |
| Download | A 404 on `uplaypc/downloads/46/latest.txt`. This is server-side and can't be fixed here. |

The key is under HKCU, while the 2026-10-31 registration wrote only HKLM.

## Steps
1. `hub play "Far Cry 3"` (`bin/farcry3_d3d11.exe`), bypassing Ubisoft Connect.
2. If that crashes the same way, debug `FC3.dll` with `--debug`.
3. Write `ExecutableName` and `StartArguments` from Ubisoft's config if the updater can't.

## Done when
Far Cry 3 reaches its menu, and Play in Ubisoft Connect starts it.
