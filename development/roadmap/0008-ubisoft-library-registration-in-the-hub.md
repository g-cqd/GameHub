---
status: done
blocked-by: []
date: 2026-10-31
---

# 0008: The hub registers Ubisoft installs itself

On 2026-10-31 the install-dir values for AC Unity (`Installs\720`), Far Cry 2, Far Cry 3 and Watch Dogs 2 were
imported from an ad-hoc `/tmp/ubi-register.reg`. The value names come from the `register:` entries in
`Library/Ubisoft/cache/configuration/configurations`. The registry backups are
`Prefix/{system,user}.reg.bak-20261031-register-libraries`.

## Work
Have the hub read those entries and write the values for every game folder in `Library/Ubisoft/games/`. Epic installs
are already registered this way ("register Library/Epic installs", 2026-10-24). Do it while the prefix is stopped,
with a backup, and idempotently.

## Done when
A prefix with no such values gets them from `hub start ubisoft`, and Ubisoft Connect shows each game's folder.

## The values written on 2026-10-31 (32-bit view, from `/tmp/ubi-register.reg`)

| Key under `HKLM\Software\Wow6432Node\` | Value | Data |
|---|---|---|
| `Ubisoft\Launcher\Installs\720` | `InstallDir` | `E:\Library\Ubisoft\games\Assassin's Creed Unity\` |
| `UBISOFT\Far Cry 2` | `installdir` | `E:\Library\Ubisoft\games\Far Cry 2\` |
| `UBISOFT\Far Cry 3` | `InstallDir` | `E:\Library\Ubisoft\games\Far Cry 3\` |
| `Ubisoft\WatchDogs2` | `InstallDir` | `E:\Library\Ubisoft\games\WATCH_DOGS2\` |

The value names, and their case, come from each game's `register:` entry in Ubisoft's configuration.

## Result (2026-11-01)
`hub start ubisoft` (and any Ubisoft game) first runs `register_ubisoft_installs`. For every folder in
`Library/Ubisoft/games` it finds the configuration record whose installer `game_identifier` names the folder, and
writes that record's HKLM install-dir value in the 32-bit view if it is missing or different. It reproduces exactly
the four values written by hand on 2026-10-31.

Checked live:
- with all four present, it writes nothing;
- with Far Cry 2's value deleted, it restores it (`E:\Library\Ubisoft\games\Far Cry 2\`).

It has unit tests in `launcher/tests/test_ubisoft.py`. Not written: HKCU `ExecutableName` and `StartArguments`,
whose format is unknown (roadmap 0009).

