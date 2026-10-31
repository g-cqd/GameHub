# launcher: one `hub` command for every game in the GameHub prefix

Scripts and settings only. All runtime data lives on the ExT2 volume (`HUB_ROOT`, default `/Volumes/ExT2/GameHub`); nothing is stored on the internal drive.
Background, decisions and troubleshooting: `docs/hub/steam-light-aoa.md`.

| What | Where |
|---|---|
| Wine runtime (fork Wine + mtld3d + DXMT + x87sidecar + GStreamer/FFmpeg + MoltenVK) | `$HUB_ROOT/Runtimes/hub-1` |
| General prefix | `$HUB_ROOT/Prefix` (`E:` = `$HUB_ROOT`, user `crossover`) |
| Steam client (the only one: older 32-bit build, updates blocked) and the one Steam library | `$HUB_ROOT/Library/Steam` = `E:\Library\Steam` (also `Z:\Volumes\ExT2\Steam` through the ext2 root symlink) |
| Games | `E:\Library\Steam\steamapps\common`: AoA 318020, Generals 2229870, C&C Zero Hour 2732960, Rise of Nations 287450, Watch_Dogs 243470, "Zero Hour" (Unity) 1359090, plus folders Steam does not know yet (HITMAN 3, Wolfenstein II, Crysis Remastered, Halo MCC; see docs) |
| Logs / session state | `$HUB_ROOT/Hub/Logs`, `$HUB_ROOT/Hub/State` |
| Known-good game settings (versioned) | `settings/` in this directory |

## Command
`launcher/hub` is the only script. It discovers installed games (Steam manifests, EA registrations, Ubisoft and Epic folders), picks the
runtime and launcher each needs, starts it, and starts the game.

- `hub list` games, their launcher, and whether each is known to work; `hub play <game>` (alias, Steam app id or part of the name, e.g. `hub play aoa`, `hub play bf4`).
- `hub start steam|ea|ubisoft`, `hub status`, `hub stop [game]`, `hub doctor`.
- Options: `--restart`, `--runtime NAME`, `--metalfx [FACTOR]`, `--dxgi wined3d`, `--debug SPEC`, `--no-wait`, `--force`.
- `hub trim epic` stops the Epic launcher and its web helpers and overlay while a game started through it runs. They held about 5 GB, mostly compressed, and the Mac swapped 50-400 MB/s while GTA V played. Whether every game survives it is untested; GTA V is being tested.
- `--metalfx` turns on DXMT's MetalFX spatial upscaler (factor above 1.0, at most 2.0; the game's output is its resolution times the factor). It applies to the whole session, except for Epic, where it is scoped to `GTA5.exe` so the launcher itself keeps its normal swapchain.
- All launchers (Steam, EA, Ubisoft, Epic) run on the unified `hub-1` runtime. Switching launchers cleanly stops the other one (refused while a game runs, unless `--restart`).

## What makes it work (do not remove)
1. Steam overlay files are moved to `_overlay-disabled` (the overlay crashes AoA right after its intro). `start-steam.sh` re-applies this.
2. Steam is the current 64-bit client (since 2026-10-31, on hub-2), started without flags and allowed to update itself; `prep_steam` removes a leftover `steam.cfg` update block. The Steam Client Service is registered in the prefix (`SteamService.exe /install`, image `C:\Program Files (x86)\Common Files\Steam\SteamService.exe`); without it Steam shows "Steam Service Error". The 2025 32-bit client it replaced (it needed `BootStrapperInhibitAll` and `-nobootstrapupdate` etc.) is in `Library/Steam-legacy`.
3. The runtime bundles the GStreamer `deinterlace` plugin (the intro video stalls without it).
4. Game exe backend via compat DB: AoA uses DXMT (`HUB_GAME_DXGI=wined3d` to override); everything else d3d9=mtld3d, dxgi=dxmt. 32-bit games get x87sidecar automatically.
5. Retina mode is prefix-wide (`HKCU\Software\Wine\Mac Driver\RetinaMode=y`) with `LogPixels=192` (HKCU `Control Panel\Desktop` and `Software\Wine\Fonts`) so Steam stays readable.
6. Registry in the prefix points at the one client: `HKCU\Software\Valve\Steam` `SteamPath`/`SteamExe`/`SourceModInstallPath`, `HKLM\Software\[Wow6432Node\]Valve\Steam\InstallPath` = `E:\Library\Steam`; both `libraryfolders.vdf` files and every `appmanifest_*.acf` `LauncherPath` use the same path.
7. AoA settings: `settings/ActOfAggression/Option.ini` (max quality, 2560x1600; in this engine 0 is the highest texture/water/shader/impostor level). `Option.autotuned.ini` is the game's auto benchmark; `Option.max-stuck.ini` hangs the Reboot Edition (3600x2338, 4096 shadows, SSR 3, tess 8, HDR, FxPreset 5), `Option.my-first-guess.ini` is wrong, do not use. `play-aoa.sh` restores the last saved copy in `$HUB_ROOT/Hub/State/ActOfAggression/` or else the file here.
