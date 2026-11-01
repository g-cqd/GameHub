---
status: in-progress
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

## Progress (2026-11-01)
**Far Cry 3 starts through Ubisoft Connect** and shows its full-screen window. The cause was the missing
`HKCU\SOFTWARE\UBISOFT\Far Cry 3\ExecutableName`, which `FC3Updater.exe -write_registry` should write but
can't, because it crashes probing D3D11.

The updater's own strings give the format: a path relative to the install dir (`/bin/farcry3_d3d11.exe` when
D3D11 is used, else `/bin/farcry3.exe`). Connect joins it to `InstallDir`. An absolute value failed with "Game
executable is not found at E:/.../Far Cry 3/E:/.../bin/farcry3_d3d11.exe".

The hub now writes the relative path to the executable it launches, for records that rely on an `evil_updater`
(only Far Cry 3 among the installed games). It does this in `register_ubisoft_installs`, which has unit tests.

`hub play "Far Cry 3"` starts the exe, which hands off to Connect. On a cold start Connect may need a second request;
`uplay://launch/46/0` from the session started it.

## Still open
- Verify: the gameplay itself, and that `hub play "Far Cry 3"` alone starts it every time.
- Verify files: Ubisoft's `UplayService generic failure`.
- `StartArguments` is missing (Connect only notes it).

