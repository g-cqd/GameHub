# Provider Installation Plan (2026-10-11)

## 1. Installers

Downloaded and verified 2026-10-11. No vendor publishes checksums; policy is Authenticode signature + recorded SHA256.

| Vendor | File | Size | SHA256 | Signer | Source Evidence |
|--------|------|------|--------|--------|-----------------|
| Steam | SteamSetup.exe | 2,380,800 B | `7d3654531c32d941...12bcb` | Valve Corp. (DigiCert Trusted G4 Code Signing RSA4096 SHA384 2021 CA1), timestamped | https://cdn.fastly.steamstatic.com/client/installer/SteamSetup.exe (confirmed) |
| Epic | EpicInstaller-20.3.3.msi | 264,237,056 B | `d55d79710edfeaa1...c60337` | Epic Games Inc. (DigiCert Trusted G4 Code Signing RSA4096 SHA384 2021 CA1), timestamped | launcher-public-service-prod06.ol.epicgames.com → epicgames-download1.akamaized.net (403 Cloudflare on vendor page; redirect chain confirmed) |
| Ubisoft | UbisoftConnectInstaller.exe | 259,083,384 B | `5043134956484...4d4b8` | UBISOFT ENTERTAINMENT INC. (Microsoft ID Verified CS AOC CA 01), timestamped | ubistatic3-a.akamaihd.net (JavaScript-added; URL + signer confirmed) |

## 2. Per-Provider Adoption

**Steam**: 287 GB present at `/Volumes/ExT2/Steam`. Three games registered: app IDs 228980, 243470, 1359090. Lives at `Z:\Volumes\ExT2\Steam\steam.exe` via `z:` -> `/` dosdevice. Adoption: in place, no moves. Hub will invoke `steam.exe -shutdown` then `taskkill steam.exe` to stop.

**Ubisoft Connect**: 97 GB present at `/Volumes/ExT2/Ubisoft Game Launcher`. Lives at `Z:\Volumes\ExT2\Ubisoft Game Launcher\UbisoftConnect.exe`. Adoption: in place, no moves. Installer re-run only if registry keys absent (verified policy, Stage 4).

**Epic Games Launcher**: 117 GB present at `/Volumes/ExT2/EpicGamesStore` (GTAV only; no launcher installed). Adoption: must install. Official MSI: `/Volumes/ExT2/GameHub/downloads/epic/EpicInstaller-20.3.3.msi` → `wine msiexec /i "Z:\Volumes\ExT2\GameHub\downloads\epic\EpicInstaller-20.3.3.msi" /qn` (`/qn` is the standard msiexec quiet switch; this installer's behaviour under Wine is unverified). Destination: `C:\Program Files (x86)\Epic Games\Launcher\...`. User then installs GTA V into the existing folder so the launcher verifies instead of downloading. Anti-cheat note: GTA Online anti-cheat recorded; never bypassed.

## 3. Dry-Run Adoption Plan

**Prefix rename** (gated Stage 4): `/Volumes/ExT2/GameHub/Relocated/BF3Mac/Data/Prefix` → `/Volumes/ExT2/GameHub/Prefix` + symlink at old path.

Preconditions (all must hold, checked by the Hub doctor, not by hand): no wineserver serves the prefix (`/tmp/.wine-<uid>/server-<dev>-<ino>` absent for it); no EADesktop.exe / game process; EA downloads finished. On 2026-10-11 12:50 the EA app WAS running in this prefix (another session, bundle Wine) and installing F1 24 into `E:\EA Games\BF4\F1 24` (ExT2 free space fell from 196 GB to 149 GB), so the rename must wait.

Commands (same volume, run only after approval):
```
mv /Volumes/ExT2/GameHub/Relocated/BF3Mac/Data/Prefix /Volumes/ExT2/GameHub/Prefix
ln -s /Volumes/ExT2/GameHub/Prefix /Volumes/ExT2/GameHub/Relocated/BF3Mac/Data/Prefix
```
then set `prefix` in /Volumes/ExT2/GameHub/Hub/hub.json to `/Volumes/ExT2/GameHub/Prefix`.

Rollback:
```
rm /Volumes/ExT2/GameHub/Relocated/BF3Mac/Data/Prefix   # removes the symlink only
mv /Volumes/ExT2/GameHub/Prefix /Volumes/ExT2/GameHub/Relocated/BF3Mac/Data/Prefix
```

Never touch `~/Library/Application Support/BF3Mac/Data/Prefix.internal-old-20261010`.

**NFS 2015 clone** (gated, dry-run first): Game folder at `/Volumes/ExT2/GameHub/Relocated/NFS2015Mac/Data/Prefix/drive_c/Program Files/EA Games/Need for Speed` (14 GB). Clone to `/Volumes/ExT2/GameHub/EA Games/Need for Speed` via `/bin/cp -c -R` (APFS clone, same volume). ExT2 free space at 12:50: 149 GB (783 of 932 GB used). An APFS clone (`cp -c`) shares blocks with the source, so it uses little new space until either copy changes. User clicks "Locate game" in EA app; one NFS activation for this prefix identity expected.

## 4. Approval Gates

Design §12: gated items to approve before execution.

1. Prefix rename to canonical path (dry-run, rollback prepared).
2. NFS 2015 clone into shared EA app (dry-run, free space confirmed).
3. Registry writes (fix apply of registry/AppDefaults actions; signed-in prefix only).
4. Installer runs: Epic MSI install, Ubisoft re-install if registry absent, Steam bootstrap.

Nothing above has been executed. Each gate needs the owner's go-ahead.
