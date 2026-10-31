# One prefix, one Steam: Steam and Act of Aggression on ExT2

Status: 2026-10-22. Launcher and settings: `launcher/` (`launcher/hub`). Runtime data lives on ExT2 only (ExT2 is for runtime data, not code).

## Layout (all under `/Volumes/ExT2/GameHub`)
- Runtimes: `Runtimes/hub-1` (fork Wine + mtld3d + DXMT + x87sidecar; used by `launcher/` scripts) and `Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer` (EA identity runtime, see `hub-shared-prefix-design-20261011.md`). Both run on the same prefix; pick with `HUB_RUNTIME`.
- The one prefix: `Prefix` (`E:` = GameHub root, user `crossover`). It holds EA (signed in), BF3/BF4/Crysis 3, NFS, and now Steam.
- The one Steam: `Library/Steam` (`E:\Library\Steam`), older 32-bit client with updates blocked, one library folder `E:\Library\Steam\steamapps`. Logs: `Hub/Logs`; state: `Hub/State`.

## How the merge was done (2026-10-22)
1. The standalone "SteamLight" prefix (`~/Games/SteamLight`, 30 GB on the internal drive) was moved into this layout; its registry files, logs and screenshots are in `Backups/steamlight-migration-20261022/`. Per-user data (`Saved Games`, `Documents`, Steam `AppData`) was merged into the prefix without overwriting.
2. Steam client: the modern client files that were in `Library/Steam` were moved to `Backups/steam-modern-client-20261022/` (with its `appmanifest_228980.acf` and `libraryfolders.vdf`); that backup was deleted on 2026-10-24 at the owner's request. The older client was moved into `Library/Steam`; `Library/SteamOld` no longer exists.
3. Library: the managed games (AoA, Generals, Zero Hour, Rise of Nations, Steamworks Shared) moved into `Library/Steam/steamapps/common` next to the Watch_Dogs and "Zero Hour" (Unity) installs. The three older duplicate copies of Generals, Zero Hour and Rise of Nations in the old library were byte-identical subsets and were deleted (7 GB); one stray log was kept.
4. Registry: SteamPath, SteamExe, InstallPath, SteamClientDll*, protocol handlers, SourceModInstallPath all point at `E:\Library\Steam`. Retina mode on, LogPixels 192 (prefix-wide; larger fonts for other apps in the prefix).
5. The research prefix `prefixes/eaac-x86_64` (only default Wine content) was archived as `Backups/prefix-eaac-x86_64-20261015.tar.gz` and removed.
6. Safety net: an APFS clone of the prefix before the merge: `Backups/prefix-pre-merge-20261022/Prefix` (shares blocks, costs almost no space until the prefix changes; delete it once you are happy).

## What was learned
- 2026-10-22: the modern Steam client did not render under hub-0 (blank window, update prompts, "steam folder not writable"); the older client with updates blocked was used.
- 2026-10-31: the current 64-bit client (build of 2026-10-22, `steam.exe`, `steamclient64.dll` and the `cef.win64` webhelper all x86_64) renders, logs on and updates itself under hub-2. It was installed by letting an APFS clone of the old client self-update, then swapped in: the old client is `Library/Steam-legacy` (with `steamapps.from-modern-test`, the empty library the test made), `steamapps` moved into the new client, the path stays `E:\Library\Steam`. It asked for the Steam Client Service ("requires some maintenance"); `bin\SteamService.exe /install` registered it. Registry backups from before the test: `Prefix/{user,system}.reg.bak-20261031-steam-modern`.
- AoA Reboot Edition starts in two stages: `ActOfAggression.exe` plays the intro video and exits, then `ActOfAggressionRE.exe` runs ("DirectX 11" window). Needs: overlay disabled, GStreamer `deinterlace`, DXMT, x87sidecar.
- The first launch of a game in a new prefix runs Steam's install scripts (DirectX June 2010, VC redists through `SteamService.exe /installscript`). It takes a few minutes and shows nothing.
- After merging folders under Steam, Steam notices `Steamworks Shared` (app 228980, a dependency of AoA) differs from its manifest and downloads about 530 MB. A game launch during that update fails with `AppError_6`, and the game shows "no internet connection" even though the network is fine. Wait for `content_log.txt` to show `AppID 228980 finished update`, then launch again.
- The max-quality `Option.ini` at 3600x2338 hangs the RE (hidden window after device creation). Suspects: 3600x2338, HDR, SSR 3, 4096 shadows; not bisected.
- AoA only lists native pixel modes when Wine Retina mode is on. It ignores requested sizes it dislikes (asked 1800x1169, picked 2560x1600).
- MetalFX (DXMT spatial): `DXMT_METALFX_SPATIAL_SWAPCHAIN=1` + `d3d11.metalSpatialUpscaleFactor` (output = game resolution x factor; 2560x1600 x 1.40625 is about 3600x2250). Not confirmed active in logs. mtld3d (D3D8/9) uses `render.scale` <= 1.0 instead. Other knobs: `d3d11.preferredMaxFrameRate` (divisor of the refresh rate), `d3d11.maxTessFactor` (AoA log shows a 64 clamp; try 16).
- `steamwebhelper` costs 40-90% of a core while Steam runs; restart Steam between long sessions (Wine msync leak: `msync: node memory pool exhausted`).
- Running hub-1 on the general prefix made Wine update the prefix (`.update-timestamp` now newer than hub-0's `wine.inf`, so hub-0 will not update it again). Registry diffs before and after touched only Steam keys and LogPixels. EA activation under hub-0 was re-tested on 2026-10-22 on the merged prefix: EA Desktop booted, reached `authenticated`, the UI loaded in 5.9 s and NFS 2015 launched (`hub play nfs`).

## Open items
- Test Rise of Nations, Generals and Zero Hour (Generals with `Options.ini` at 2560x1440 created the D3D device and then exited).
- EA on hub-1 works since 2026-10-24 (`hub play nfs` reaches the game). Three causes were fixed: (1) ntdll read BOOLEAN syscall arguments with stale upper bits, so EA Desktop 13.813 looped forever in `NtQueryDirectoryObject` on `\DosDevices` (wine commit `51430b514f7`); (2) hub-1 had lost the `lib/wine/dxgi/gptk -> dxmt` alias, so steamwebhelper crashed in a restart loop (now created by `scripts/assemble_runtime.sh`); (3) the NFS licence `1024486.dlf` was bound to the old machine hash and was moved aside (`1024486.dlf.stale-machine-hash-20261024`); EA requested a new one on the next launch.
- Re-test a BF game under hub-0 on the merged prefix.
- HITMAN 3 (77 GB), Wolfenstein II (49 GB), Crysis Remastered (20 GB), Halo MCC (16 GB) and the Unity "Zero Hour" are in `steamapps/common` without manifests, so Steam does not list them as installed. In Steam, install each into this library and let it verify; it should reuse the files.
- Bisect which AoA setting hangs the RE; add a MetalFX preset to `hub play aoa`.
- Old `bin/hubenv.sh` and `bin/start-steam.sh` on ExT2 are superseded by `launcher/`; remove when convenient.
