# Data store survey: /Volumes/ExT2

Date: 2026-10-11. Deliverable 1 (read-only survey) for reorganising `/Volumes/ExT2` (case-sensitive APFS, Thunderbolt, ~149 GB free) into a clean data store under `/Volumes/ExT2/GameHub`.

Method: read-only scouts. Sizes from `du -sk`; records from grep of registry and config files. Nothing was started or modified, and nothing was run under Wine. Sizes are GB (binary, 1 decimal) unless stated. `P` = `/Volumes/ExT2/GameHub/Relocated/BF3Mac/Data/Prefix` (the shared prefix).

## 1. Volume overview

### `/Volumes/ExT2`

| Path | Size | Purpose |
|---|---|---|
| `Backups` | 17.8 GB | `git` 1.15 GB, `Preserve-20261009` 1.85 GB, `Store-20261008` 14.8 GB, manifests, `deleted-20261010.log` |
| `Bundles` | 54.4 GB | Built game bundles (never modified): `Battlefield 3 Bundled 20261009-5ee7913.app` 24.6 GB, `Call of Duty 4 Bundled 20261002-7d108a4.app` 6.74 GB, `Far Cry 2 Bundled 20261002-845b6c9.app` 3.85 GB, `Far Cry 2 Import 20261002-7d108a4.app` 0.57 GB, `Most Wanted Bundled 20261002-7d108a4.app` 3.39 GB, `Need for Speed Bundled 20261008-13d1f4f-0010.app` 15.2 GB, `README.txt`, `Open This First - Need for Speed complete.txt` |
| `EA Games` | 1.14 GB | Stub `Battlefield 4` (Aug 2025), see section 2.1 |
| `EpicGamesStore` | 116.5 GB | GTAV only |
| `GameHub` | 211.7 GB | Hub data, prefixes, runtimes, dev area |
| `Scratch-bf3-native` | 17.5 MB | BF3 native-work logs, scripts, evidence |
| `Steam` | 286.2 GB | Windows Steam install and library |
| `SteamGames` | 1.7 MB | Stale Steam library stub, see section 2.2 |
| `Ubisoft Game Launcher` | 96.6 GB | Windows Ubisoft Connect and games |

### `/Volumes/ExT2/GameHub`

| Path | Size | Purpose |
|---|---|---|
| `backups` | 32 KB | |
| `bin` | 8 KB | `start-ea.sh`, `wine-query.sh` |
| `docs` | 540 KB | Plans and specs |
| `downloads` | 501 MB | Installers |
| `EA Games` | 115.6 GB | EA download-in-place root (only `BF4/`) |
| `inputs` | 92 MB | `x87sidecar-src` |
| `Logs` | 2.1 MB | `start-ea.sh` writes `ea-<ts>.log` |
| `reference` | 18 MB | MoltenVK |
| `Relocated` | 40.0 GB | `BF3Mac/Data` 23.2 GB (the shared prefix), `NFS2015Mac/Data` 16.8 GB (NFS 2015 wrapper prefix) |
| `Runtimes` | 4.2 GB | `hub-0` 1.40 GB, `hub-0-helpers`, `hub-0.manifest`, `hub-0.manifest.links`, `wine-0010` 1.40 GB, `wine-0011` 1.40 GB |
| `src` | 9.0 GB | `wine` 1.45 GB, `wine-arm64` 7.57 GB, `dxmt-v0.80` |
| `toolchains` | 6.2 GB | `cargo`, `rustup` 1.40 GB, `llvm-mingw` 0.76 GB, `wine-sdk-cx-26.3.0-5` 1.16 GB, `xwin` 1.03 GB, `xwin-cache` 1.24 GB, `downloads` 0.37 GB, `provision.sh`, `mt-env` |
| `work` | 36.0 GB | See section 3 |
| `docs/history/STATUS-20261010.md`, `docs/history/STATUS-20261011.md` | | Status notes |

No `Hub/` directory and no `hub.json` exist.

## 2. Launchers

### 2.1 EA app

Provider: EA app inside the shared prefix, at `P/drive_c/Program Files/Electronic Arts/EA Desktop/13.805.11.6320-1791598480`.

`P/dosdevices`: `c:` -> `../drive_c`, `e:` -> `/Volumes/ExT2/GameHub` (created Oct 10 18:50), `z:` -> `/`. No `.windows-serial` or `.windows-label` in `/Volumes/ExT2/GameHub`, `/Volumes/ExT2` or `P`.

**Folders**

| Path | Size | Games / notes |
|---|---|---|
| `/Volumes/ExT2/GameHub/EA Games/BF4/Battlefield 4` | 61.5 GB | Registered |
| `/Volumes/ExT2/GameHub/EA Games/BF4/Crysis 3` | 10.6 GB | Registered (Crytek key) |
| `/Volumes/ExT2/GameHub/EA Games/BF4/F1 24` | 43.5 GB | Partial download (`DiP_Staged` files); state in `P/drive_c/ProgramData/EA Desktop/InstallData/F1 24/base-Origin.SFT.50.0001497`; not in registry |
| `C:\Program Files\EA Games\Battlefield 3` (inside `P`) | 19.9 GB | BF3 |
| `C:\Program Files\EA Games\Need for Speed` in `/Volumes/ExT2/GameHub/Relocated/NFS2015Mac/Data/Prefix` | | NFS 2015 in its own prefix; registry `Install Dir` is `C:\...`; its `dosdevices` has only `c:` and `z:`; `InstallSource` points at `Z:\Volumes\ExT2\Bundles\Need for Speed Bundled ...` |
| `/Volumes/ExT2/EA Games/Battlefield 4` | 1.14 GB | Aug 2025 `DiP_Staged` stub (`bf4.exe_DiP_Staged`, `Core`, `Data`, `Support`, `Update`, `__Installer`); no registry or ini record points at it |

**Records** (`P/system.reg` unless noted; line numbers)

| Lines | Key | Value |
|---|---|---|
| 67078-67082 | `[Software\\EA Games\\Battlefield 4]` | `GDFBinary`; `"Install Dir"="E:\\EA Games\\BF4\\Battlefield 4\\"` |
| 77938-77955 | GameUX `ConfigApplicationPath` / `ConfigGDFBinaryPath` | BF4: `E:\\EA Games\\BF4\\Battlefield 4\\...`; BF3: `C:\\Program Files\\EA Games\\Battlefield 3\\` |
| 97288-97292 | `[Software\\Wow6432Node\\Crytek\\Crysis 3]` | `GDFBinary`; `"Install Dir"="E:\\EA Games\\BF4\\Crysis 3\\"` |
| 97296-97300 | `Wow6432Node` `EA Games\\Battlefield 3` | `Install Dir` = `C:\\...` |
| 97304-97359 | `Wow6432Node` `EA Games\\Battlefield 4` | `Install Dir` = `E:\\EA Games\\BF4\\Battlefield 4\\`; `GDFBinary`/`GDFBinary64`; DLCs `Xpack0`-`Xpack4` |
| 104107 | BF4 `UninstallString` | `E:\\EA Games\\BF4\\Battlefield 4\\pbsvc.exe -u` |
| 104239-104244 | Crysis 3 uninstall `DisplayIcon`/`HelpLink`/`InstallLocation` | under `E:\\EA Games\\BF4\\Crysis 3\\` |
| 104274-104280 | BF3 uninstall | under `C:\\` |
| 104437-104442 | BF4 uninstall `DisplayIcon`/`HelpLink`/`InstallLocation` | under `E:\\EA Games\\BF4\\Battlefield 4\\` |
| 105450-105480 | `Wow6432Node\\Origin Games\\{1004841,1004842,1007968,1011887,1011893,1011899,71503}` | `DisplayName`/`Locale` only |
| (MSI) | `InstallSource` | `e:\\c3a7c2b311a29cfdf36fbfa2\\` (nonexistent, harmless) |
| `system.reg` 90445, 91775, 100703, 101753; `user.reg` 2052, 3379 | font entries | `Z:\\Volumes\\ExT2\\Bundles\\Battlefield 3 Bundled 20261009-5ee7913.app\\...\\fonts\\{marlett,symbol}.ttf` (pin a `Bundles` path, which does not move) |
| `user.reg` 1006-1037 | Qt plugin caches | includes `E:\\EA Games\\BF4\\Battlefield 4\\Core\\imageformats` (cache only) |
| `user.reg` 912 | Run `"EADM"` | `C:\\Program Files\\Electronic Arts\\EA Desktop\\13.796.0.6309\\EA Desktop\\EALauncher.exe -silentOs` (stale version folder) |
| `P/drive_c/users/crossover/AppData/Local/Electronic Arts/EA Desktop/user_5453960179173819204.ini:16` | `user.downloadinplacedir` | `E:\EA Games\BF4\` (only config-file record of the library root) |

Other EA files:
- `ProgramData/EA Desktop/machine.ini`, `backgroundservice.ini` and `InstallData/*` contain no `E:` or `EA Games` strings.
- `installerdata.xml` launchers resolve via `[HKEY_LOCAL_MACHINE\SOFTWARE\EA Games\Battlefield 4\Install Dir]` and `{installLocation}` (no literal path).
- Licences in `P/drive_c/ProgramData/Electronic Arts/EA Services/License`: `1007968.dlf`, `70619.dlf`, `70619.dlf.stale-machine-hash-20261011`, `71503.dlf`. `docs/history/STATUS-20261011.md` records that the BF3 licence failed with "Mismatched machine hash" since the `E:` mapping was added; BF4 and Crysis 3 licences were created after it.
- Not inspected: EA `.db` files, CEF caches.

**What breaks if it moves**

- Every EA record is a Windows path through `E:` (GameHub root) or `C:` (inside the prefix). No record holds the host path `/Volumes/ExT2/GameHub/EA Games`.
- Moving `EA Games` within GameHub with a symlink left behind would keep `E:\EA Games\...` resolving (Wine follows host symlinks; inferred, not run). Windows programs would then see a symlinked path.
- Changing the `e:` target or the drive letter invalidates every record above and may change the licence machine hash.
- Moving the prefix directory (same volume, same inode) changes no Windows path.

### 2.2 Steam

`/Volumes/ExT2/Steam` 286.2 GB: Windows Steam (`steam.exe`, `steamclient64.dll`, `bin`, `package`), launched as `Z:\Volumes\ExT2\Steam\steam.exe`. `steamapps` is 284.8 GB.

**Manifests in `Steam/steamapps`**

| appid | Game | installdir | Notes |
|---|---|---|---|
| 1359090 | Zero Hour | `Zero Hour` | `SizeOnDisk` 36000693860 |
| 228980 | Steamworks Common Redistributables | `Steamworks Shared` | |
| 243470 | Watch_Dogs | | |

All three: `LauncherPath` = `Z:\\Volumes\\ExT2\\Steam\\steam.exe`.

**`steamapps/common` on disk**

| Folder | Size | Manifest |
|---|---|---|
| `Command &amp; Conquer Generals - Zero Hour` | 2.7 GB | none here; appid 2732960 in `SteamGames` |
| `Command and Conquer Generals` | 1.6 GB | none here; 2229870 in `SteamGames` |
| `Crysis Remastered` | 19.9 GB | none here; 1715130 in `SteamGames` |
| `F1 24` | 65.2 GB | none anywhere |
| `Halo The Master Chief Collection` | 16.0 GB | none |
| `HITMAN 3` | 76.8 GB | none here; 1659040 in `SteamGames` |
| `Rise of Nations` | 2.6 GB | none here; 287450 in `SteamGames` |
| `Steam Controller Configs` | | |
| `Steamworks Shared` | 0.9 GB | 228980 |
| `Watch_Dogs` | 17.1 GB | 243470 |
| `Wolfenstein.II.The.New.Colossus` | 48.5 GB | none |
| `Zero Hour` | 33.5 GB | 1359090 |

**Records**

| File | Key | Value |
|---|---|---|
| `Steam/steamapps/libraryfolders.vdf` (byte-identical copy at `Steam/config/libraryfolders.vdf`) | `libraryfolders.0.path` | `"Z:\\Volumes\\ExT2\\Steam"` |
| same | `contentid` | `3468386113388309447` |
| same | apps | `228980`, `243470`, `1359090` |
| `Steam/steamapps/appmanifest_{1359090,228980,243470}.acf` | `LauncherPath` | `Z:\\Volumes\\ExT2\\Steam\\steam.exe` |
| `Steam/logs/*` | | contain `Z:\Volumes\ExT2\Steam\...` (history) |

- No path in `config.vdf`, `loginusers.vdf`, or `userdata/313467792/config/localconfig.vdf` (only `ext2-*.steamserver.net` hostnames). No `steam.cfg`. No `Valve\\Steam` keys in `P/system.reg` or `P/user.reg`.
- No symlinks and no case-only collisions in `Steam/` top level or `steamapps`.
- `~/Library/Application Support/Steam` is not a real install (`appcache`, `config/config.vdf`, `libraryfolder.vdf` with contentid `6301114104650772684`, `logs`; no paths). No CrossOver bottles.

**`/Volumes/ExT2/SteamGames`** (1.7 MB)
- `libraryfolder.vdf`: launcher `"C:\\Program Files (x86)\\Steam\\steam.exe"`, contentid `3835886434244464239`; stray `steam.dll`.
- `steamapps/` holds 6 manifests (`StateFlags` 4, `LauncherPath` `C:\\Program Files (x86)\\Steam\\steam.exe`): 1359090 Zero Hour; 1659040 HITMAN World of Assassination (installdir `HITMAN 3`); 1715130 Crysis Remastered; 2229870 C&amp;C Generals; 2732960 C&amp;C Generals Zero Hour; 287450 Rise of Nations: Extended Edition.
- `steamapps/common` is empty; `workshop/appworkshop_287450.acf` exists.
- Not registered in Steam's `libraryfolders.vdf`.

**What breaks if it moves**
- Moving `Steam` with a symlink at the old path keeps `Z:\Volumes\ExT2\Steam` working.
- `libraryfolders.vdf` (both copies) `path` and the 3 `.acf` `LauncherPath` values should be rewritten to the new `Z:\\` path (VDF escaping: doubled backslashes).
- Whatever launches `steam.exe` must use the new path.
- `SteamGames` is pinned by nothing.

### 2.3 Epic

`/Volumes/ExT2/EpicGamesStore` 116.5 GB: only GTAV (`update/` 62.7 GB, `x64/` 16.7 GB, `x64a`..`x64w.rpf`, `Redistributables`).

**Records**: `GTAV/.egstore` holds two `.manifest` (binary) and two `.mancpn` (JSON; no path): `CatalogNamespace` `0584d2013f0149a791e7b9bad0eec102`, `CatalogItemId` `6e563a2c0f5f46e3b4e88b5f4ed50cca`, `AppName` `9d2d0eb64d5c44529cece33fe2a46482`. `Pending/` is empty.

No Epic launcher anywhere: no `P/drive_c/ProgramData/Epic`, no `~/Library/Application Support/Epic`, no Unreal Engine prefs, no `.item`, no `LauncherInstalled.dat`, no Heroic/Whisky/CrossOver. Rockstar: no registry keys in `P`; `~/Documents/Rockstar Games/Launcher/launcher.log` (2025-09-13) shows `Z:\Volumes\ExT2\EpicGamesStore\GTAV` (history only; `settings.xml`/`Profiles` not checked).

**What breaks if it moves**: nothing pins it; a symlink keeps the old `Z:\` path working. When Epic is installed later, its `.item` / `LauncherInstalled.dat` should be written with the new path.

### 2.4 Ubisoft

`/Volumes/ExT2/Ubisoft Game Launcher` 96.6 GB: Windows Ubisoft Connect (`UbisoftConnect.exe`) plus `games/` 96.0 GB.

| Folder | Size |
|---|---|
| `games/Assassin's Creed Unity` | 49.4 GB |
| `games/WATCH_DOGS2` | 31.2 GB |
| `games/Far Cry 3` | 10.8 GB |
| `games/Far Cry 2` | 4.5 GB |

Other contents: `cache` 160 MB, `shareplay`, `locales`, `data`, `license`, `logs`, `crashes`, `savegames`, `Installed_files.txt`.

**Records**: no `settings.yml` (only schema `.yml` under `data/resources`), no AppData Ubisoft folder in `P`, no Ubisoft registry keys in `P`. Paths appear only in logs (`launcher_log.txt` `Z:/Volumes/ExT2/Ubisoft Game Launcher/...`, `service_log.txt`, `overlay_log.txt` `Z:\...\games\Assassin's Creed Unity\ACU.exe`), crash dumps, and possibly `cache/http2` `Local State` / `Default/Preferences` (matched a grep; value unseen).

**What breaks if it moves**: nothing live; a symlink keeps the old path. When Ubisoft next runs it will write `settings.yml` `game_installation_path` and registry `Installs` keys, so write the new path then.

## 3. Other GameHub folders and path pins

### Folders

| Path | Size | Contents |
|---|---|---|
| `Relocated/BF3Mac/Data` | 23.2 GB | Shared prefix (`P`) |
| `Relocated/NFS2015Mac/Data` | 16.8 GB | NFS 2015 wrapper prefix |
| `Runtimes` | 4.2 GB | `hub-0`, `hub-0-helpers`, `hub-0.manifest`, `hub-0.manifest.links`, `wine-0010`, `wine-0011` |
| `src` | 9.0 GB | `wine` 1.45 GB, `wine-arm64` 7.57 GB, `dxmt-v0.80` |
| `toolchains` | 6.2 GB | see section 1 |
| `work` | 36.0 GB | `cargo-target` 14.8 GB; `mtld3d-merge` 16.3 GB (git worktree of `~/Developer/mtld3d`); `winemac-fs` 0.40 GB; `wt-hub-a/b/c` (git worktrees of `~/Developer/nfs-macos`); `build-hub-a/b/c` and `hub-build-{app,catalog,instances,main,tests}` (SwiftPM build dirs, ~0.16-0.65 GB each); `hub-catalog-src` 4.9 MB source copy; `bundle-out`; `p1`; `logs`; loose `fix_*.py` / `ship*.sh` scripts |

### Symlinks (absolute targets)

| Link | Target |
|---|---|
| `P/dosdevices/e:` | `/Volumes/ExT2/GameHub` |
| `~/Library/Application Support/BF3Mac/Data/Prefix` | `/Volumes/ExT2/GameHub/Relocated/BF3Mac/Data/Prefix` (real old copy beside it: `Prefix.internal-old-20261010`) |
| `~/Library/Application Support/NFS2015Mac/Data/Prefix` | `/Volumes/ExT2/GameHub/Relocated/NFS2015Mac/Data/Prefix` (`Prefix.internal-old-20261010` beside it) |

Nothing in `/Applications`, `~/Library/LaunchAgents` or `~/.config` points into ExT2.

### Scripts and code

| File | Pinned values |
|---|---|
| `GameHub/bin/start-ea.sh` | `BUN=/Volumes/ExT2/Bundles/Battlefield 3 Bundled 20261009-5ee7913.app/Contents`; `R=~/Library/Application Support/BF3Mac`; `WINEPREFIX=$R/Data/Prefix`; `HOME=$R/RuntimeHome/Player`; `TMPDIR=$R/Temporary`; log `/Volumes/ExT2/GameHub/Logs/ea-$ts.log`; `ROSETTA_X87_PATH=$BUN/Helpers/x87sidecar`; runs `EADesktop.exe` under `C:\Program Files\Electronic Arts\EA Desktop\13.805.99.0\EA Desktop\` |
| `GameHub/bin/wine-query.sh` | `B` = bundle wine; same `R`, `HOME`, `TMPDIR`, `WINEPREFIX` |
| `~/Developer/nfs-macos/Sources/HubCore/HubTypes.swift` (`HubLayout`) | volume `HUB_VOLUME` or `/Volumes/ExT2`; hub `HUB_ROOT` or `<volume>/GameHub`; bundles `<volume>/Bundles`; steam `<volume>/Steam`; eaGames `<hub>/EA Games`; epic `<volume>/EpicGamesStore`; ubisoft `<volume>/Ubisoft Game Launcher` |
| `~/Developer/nfs-macos/Sources/HubCore/Prefixes/HubPaths.swift` | root `/Volumes/ExT2/GameHub` (`Hub/hub.json`, `Hub/State`, `Hub/Logs`, `Hub/Home/Player`, `Hub/Temp`, `Hub/Knowledge`, `Runtimes/<id>`) |
| `~/Developer/nfs-macos/Packaging/Recipes/bf3.json` | `tunedBundle` `/Volumes/ExT2/Bundles/Battlefield3-Tuned-20261009` |

Docs under `GameHub/docs` mention `/Volumes/ExT2` paths (`provider-install-plan-20261011.md` 10 lines, `hub-shared-prefix-design-20261011.md` 6, `bundler-plan/*` and `hub-specs/*` a few); this is historical text.

## 4. Case collisions

The volume is case-sensitive, but Wine (via `E:` / `Z:`) and macOS tools treat names case-insensitively.

| Proposed name | Existing in `GameHub` | Result |
|---|---|---|
| `Backups` | `backups` | collides (`/Volumes/ExT2/Backups` also already exists, outside GameHub) |
| `Bin` | `bin` | collides |
| `Docs` | `docs` | collides |
| `Downloads` | `downloads` | collides |
| `Inputs` | `inputs` | collides |
| `Reference` | `reference` | collides |
| `Toolchains` | `toolchains` | collides |
| `Work` | `work` | collides |
| `Logs` | `Logs` | identical name |
| `Runtimes` | `Runtimes` | identical name |
| `Prefix`, `Hub`, `Library`, `Launchers`, `Build`, `Apps`, `Sources` | none | no collision |

## 5. Implications for the plan

- (a) EA paths are Windows paths through `E:` = GameHub root, so `E:` must keep pointing at `/Volumes/ExT2/GameHub` and `E:\EA Games` must keep resolving. The `e:` target is never changed (licence machine hash risk).
- (b) Steam needs a VDF rewrite of 2 `libraryfolders.vdf` plus 3 `.acf` `LauncherPath` values; nothing else.
- (c) Epic and Ubisoft can move freely; their Windows launch paths change only in the Hub's provider data and the scripts.
- (d) `SteamGames` holds stale records for games whose files live in `Steam/steamapps/common`; re-registering them is a Steam-side action, not a move.
- (e) The prefix rename changes no Windows path; it needs the two wrapper symlinks and `hub.json`.
- (f) Dev areas (`work`, `src`, `toolchains`) are pinned by other projects' absolute paths (git worktree `gitdir` files, cargo/cmake build state).
- (g) Case-only renames at the GameHub root cannot keep a compatibility symlink.

## 6. Not checked

- EA `.db` files and CEF caches.
- Rockstar `settings.xml` / `Profiles`.
- Ubisoft `cache/http2` matched strings.
- Game folders' own config files.
- Case collisions inside `Steam/steamapps/common/*`.
- Symlinks in `work/`, `src/`, `toolchains/`, `Runtimes/*/lib`.
- Nothing was run under Wine.
