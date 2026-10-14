> Historical snapshot (2026-10-15): branch names and paths below reflect the state when written and may no longer exist.

# Import Need for Speed (2015) into the shared EA app prefix (plan, 2026-10-11)

## 1. Status

**PLAN ONLY. Nothing in this document has been applied.** The author wrote only the four plan files and ran only the read-only dry-run script (record in section 10). Phase 2 (section 5, steps S0 to S8; rollback in section 7) is run by the user with EA stopped. Companion files:

- `/Volumes/ExT2/GameHub/docs/nfs-ea-import-plan-20261011.json` (machine-readable plan, own schema `nfs-ea-import-plan/1`; `gamehub-cli datastore` cannot express hard links, clones or registry imports, so it is not used. Check names `exists/absent/notSymlink/noWineProcess/prefixNotInUse/textContains/sameFile` are reused where they fit.)
- `/Volumes/ExT2/GameHub/docs/nfs-ea-import-20261011/nfs-import.reg` (3 values, REGEDIT4, ASCII)
- `/Volumes/ExT2/GameHub/docs/nfs-ea-import-20261011/nfs-ea-import-dryrun.sh` (read-only checker, `--gate` mode)

Your login shell is fish. **Run `bash` first**, then paste the blocks in order into that bash session. Each block runs in a `( set -euo pipefail ... )` subshell (S6's verify blocks excepted), so a failed command stops that block and prints `rc` != 0; do not continue after a non-zero `rc`. Every block that changes something starts with the `stopped` check (no wine, EA or old wrapper running). Do not `set -e` the interactive shell.

## 2. Summary and decisions

Goal: let the shared EA app (prefix `SP`) see the NFS game as Installed, with the game files at `E:\EA Games\Need for Speed`, without a re-download (14.6 GB) and without breaking the old NFS wrapper.

| # | Decision | Why |
|---|---|---|
| D1 | Target `NEW=/Volumes/ExT2/GameHub/EA Games/Need for Speed` = `E:\EA Games\Need for Speed\`. Deliberately outside the EA library root `E:\EA Games\BF4\` (user request). | EA detects NFS through `installCheck` (registry `Install Dir` + `NFS16.exe`), not through the library root. Alternative in section 9. |
| D2 | Move the folder by `rename` (same APFS device, same inodes, zero bytes copied). Then recreate `OLD` as a real directory whose 144 files are **hard links** to `NEW`. **No symlink.** | The old wrapper resolves every path component below `drive_c` with `GuestPath.resolve(followingLinks:false)` and throws `A Windows folder entry is a link: <name>` for a symlink (`/Volumes/ExT2/GameHub/work/wt-hub-a/Sources/LauncherCore/GuestPath.swift:82-84`, called from `Sources/NFS2015Core/NFS2015Install.swift:171-172` on every launch; identical to commit 13d1f4f and the bundle's shipped source). It checks only `isSymbolicLink`, not link count or inode. Symlinks above `drive_c` are fine. A hard-link tree passes. |
| D3 | Registry: only the NFS-prefix shape, written to the 32-bit view `HKLM\SOFTWARE\Wow6432Node\EA Games\Need for Speed`, with `Install Dir` rewritten to `E:\\EA Games\\Need for Speed\\`. Imported with `wine reg import` while EA is stopped. | It is the only NFS install record in the old prefix. EA reads `[HKEY_LOCAL_MACHINE\SOFTWARE\EA Games\Need for Speed\Install Dir]NFS16.exe` through the 32-bit view. |
| D4 | No `InstallData`, `Uninstall`, GDF/GameUX or `Origin Games` fabrication. | The NFS prefix proves EA marks NFS Installed without them (no such records exist there). Fabricated records could be wrong and persist. BF4/Crysis 3/F1 24 have them only because EA's own touchup wrote them. Non-fatal side effect: `Could not parse uninstallCommandLine=[] of offerId=[Origin.OFR.50.0000810]`. |
| D5 | Licence: do **not** copy `1024486.dlf`. Let EA issue a fresh one on the first Play. | Licences bind to a machine fingerprint that is not just the `machash`: BF3's `70619.dlf` (issued with c:+z:) failed with `Mismatched machine hash in license` / `License Failure 3` after `e:` was added (storage count 2 to 3) while `machash` stayed constant (PD-EA Logs `gl_log_2.log` 20:47:59; fixed by moving the dlf aside, `STATUS-20261011.md:23`). NFS's dlf was issued in a c:+z: prefix, the shared prefix is c:+e:+z:, so expect the same mismatch. |
| D6 | Activation budget: first Play = 1 EA activation (EA's published user-agreement limit is 5 unique machines/activations per rolling 24 h; not verified here) and possibly one Denuvo activation by NFS itself under the new runtime. Do not combine with other runtime switches or sign-ins that day. | EA activation limit. |
| D7 | The old prefix changes in exactly one way: its game folder's files become hard links. Its registry, licence, saves and runtime are untouched. | Old wrapper keeps working. |

Known consequence of D2: EA updates write-new + rename in `NEW`, so a patched file diverges from the mirror in `OLD` (the old wrapper keeps the old version). In-place writes affect both.

## 3. Survey findings

Sources: old prefix `OP/system.reg`, shared `SP/system.reg`, EA logs under `SP/drive_c/ProgramData/EA Desktop/Logs` and `OP/drive_c/ProgramData/EA Desktop/Logs`, PD-EA Logs `SP/drive_c/ProgramData/EA Logs/gl_log_*.log` (UTF-16), Origin logs `SP/drive_c/ProgramData/Origin/Logs`, `/Volumes/ExT2/GameHub/bin/start-ea.sh`, `STATUS-20261011.md`. A snapshot of both prefixes' registries and ProgramData is at `/tmp/nfs-ea-survey-20261011T1621/{nfs,shared}` (may vanish on reboot; not needed by the plan).

Paths: `SP=/Volumes/ExT2/GameHub/Prefix` (EA binaries `EA Desktop\13.805.99.0` per `start-ea.sh`, app version string 13.805.11.6320; dosdevices `c:` -> `../drive_c`, `e:` -> `/Volumes/ExT2/GameHub`, `z:` -> `/`; library root `user.downloadinplacedir=E:\EA Games\BF4\`). `OP=/Volumes/ExT2/GameHub/Relocated/NFS2015Mac/Data/Prefix` (also `/Users/gc/Library/Application Support/NFS2015Mac/Data/Prefix`, a symlink to it; drives `c:`, `z:`). `OLD=$OP/drive_c/Program Files/EA Games/Need for Speed`: real dir, 144 files, 26 dirs, 14,639,595,955 bytes, 0 symlinks, 0 files with link count > 1, same device as `NEW`'s parent. `NEW` is absent today.

### 3.1 Registry: NFS prefix versus shared prefix

| Item | Old NFS prefix (`OP/system.reg`) | Shared prefix (`SP/system.reg`) |
|---|---|---|
| `Software\\Wow6432Node\\EA Games\\Need for Speed` | `Install Dir`=`C:\\Program Files\\EA Games\\Need for Speed\\`, `Locale`=`en_US`, `Product GUID`=`{F8643E83-A868-4EE8-A0B9-389386830453}` | absent (0 lines match "Need for Speed") |
| Native (non-Wow6432Node) NFS key | none | none |
| `Uninstall\{Product GUID}`, GameUX/GDF, `Origin Games\<contentId>` for NFS | none | not applicable; BF4/Crysis 3/F1 24 have them (written by EA's touchup), e.g. `InstallLocation=E:\EA Games\BF4\<game>\`, paths written `E:\\EA Games\\BF4\\<Game>\\` with trailing backslash |
| Detection by EA | `installCheck`: `watchPath path [C:\Program Files\EA Games\Need for Speed\NFS16.exe] for software [Origin.SFT.50.0000347]`, `Located files for software [Origin.SFT.50.0000347]. Setting state to Installed`, `launcher.exePath=[[HKEY_LOCAL_MACHINE\SOFTWARE\EA Games\Need for Speed\Install Dir]NFS16.exe]`, `IS update: ... baseSlug=[need-for-speed] installedStatus=[Installed]`, on Play `Got exePath=[C:\Program Files\EA Games\Need for Speed\NFS16.exe] ... from defaultLauncher` | shared installStore currently says `NotInstalled` for `Origin.SFT.50.0000347` |

IDs: contentId 1024486, softwareId `Origin.SFT.50.0000347`, offerId `Origin.OFR.50.0000810`, slug `need-for-speed`, game version 1.3.0.0; `installerdata.xml` launcher `filePath` is `[HKEY_LOCAL_MACHINE\SOFTWARE\EA Games\Need for Speed\Install Dir]NFS16.exe` (also `NFS16_trial.exe`); `autoUpdateEnabled=1`, `treatUpdatesAsMandatory=1`, `forceTouchupInstallerAfterUpdate=1`; touchup `executeElevated`/`requiresAdmin` 0.

### 3.2 ProgramData and InstallData

The old prefix has no `ProgramData/EA Desktop/InstallData` folder for NFS. EA keeps `InstallData/<game>/base-<softwareId>/map.eacrc` (relative paths only, no absolute paths) for games it installed itself; NFS never had one, and EA still marked it Installed. Expect no NFS folder in the shared `InstallData` afterwards. State lands in the installStore (IS).

### 3.3 Licences

| Location | Files |
|---|---|
| Old prefix `OP/drive_c/ProgramData/Electronic Arts/EA Services/License/` | `1024486.dlf` (1889 B, 2026-10-08) |
| Shared `SP/drive_c/ProgramData/Electronic Arts/EA Services/License/` | `1007968.dlf`, `16425782.dlf`, `70619.dlf` (+ a `.stale-machine-hash-20261011` copy), `71503.dlf`; no `1024486.dlf` |

EA `machash` is `d1920624b6654b648e83b7732a233cc23636a0c9` in both prefixes, but the BF3 incident shows it is not what the licence binds to (D5). Decision: no copy.

### 3.4 Old wrapper behaviour

Bundle `/Volumes/ExT2/Bundles/Need for Speed Bundled 20261008-13d1f4f-0010.app`, helper `Contents/Helpers/NFS2015Session`. Every launch resolves each component below `drive_c` without following links (see D2). `seed.json` is only checked for existence; there is no re-seed or delete at launch. A symlink at `OLD` would therefore break it; a real directory of hard links does not.

### 3.5 Other facts that shaped the plan

- `gamehub-cli datastore` ops are `mkdir/rename/symlink/replaceSymlink/backup/rewriteText/writeHubConfig`; it has no hard link, clone or registry op. Hence this plan's own JSON.
- Wine socket of a prefix: `/tmp/.wine-<uid>/server-<hex st_dev>-<hex st_ino>/socket` (dir of the prefix). For `SP` today: `server-100002c-114cbb` (`stat -f '%d %i'` gives 16777260 1133755). The dry-run script replicates `prefixNotInUse` from `DatastoreChecks.swift`.
- macOS volume free space measured by the dry-run: about 40 GiB (not 92 GB); BF1 is downloading. The plan itself needs no space beyond the roughly 85 MB of ProgramData backups (cloned, so close to zero on APFS).
- NFS settings (`users\crossover\Documents\Need For Speed`, about 5 MB) live under the Wine user `crossover` in the old prefix. The shared prefix uses the same profile name `crossover` (pinned by this Wine build; `USER=Player` in `W` does not change it; `SP/drive_c/users/crossover/Documents` holds only `Battlefield 3` and `Battlefield 4`). The optional step S6b copies the folder.
- The detection evidence in 3.1 was logged by the old prefix's EA build 13.805.11.6320; the shared prefix runs `13.805.99.0` (a `13.805.11.6320-...` directory also exists there). Identical `installCheck` behaviour is assumed; S6 has a contingency if it does not hold.

## 4. Preconditions

1. BF1 (and any other download) must not be in progress. The dry-run's installer-process count cannot see downloads. In EA's **Downloads** queue pause (or finish) BF1 and everything else, then Quit. Stopping EA mid-install can leave BF1 half-installed.
2. You can quit EA, any game, and the old NFS wrapper now.
3. `bash /Volumes/ExT2/GameHub/docs/nfs-ea-import-20261011/nfs-ea-import-dryrun.sh` (plan mode) shows `fail=0`; `expected_fail_now` items disappear after S1.
4. The only wine server touched is the one of `SP`. Never touch `/Volumes/ExT2/Bundles`.
5. Do not run any step with another EA sign-in/runtime switch the same day (activation cap, D6).

## 5. Steps (Phase 2, run by the user)

Never use `sleep`. Waiting is by event: `wineserver -w`, or `~/.agent-harness/bin/work wait`.

### S0 Variables (for a new bash window or a rollback, run `TS=<original value>` first, then paste S0; S0 keeps an existing `TS`)

```bash
PATH=/usr/bin:/bin:/usr/sbin:/sbin
TS=${TS:-$(date -u +%Y%m%dT%H%M%SZ)}
H=/Volumes/ExT2/GameHub
SP=$H/Prefix
OP=$H/Relocated/NFS2015Mac/Data/Prefix
OPALIAS="/Users/gc/Library/Application Support/NFS2015Mac/Data/Prefix"
OLD="$OP/drive_c/Program Files/EA Games/Need for Speed"
NEW="$H/EA Games/Need for Speed"
RT=$H/Runtimes/hub-0-winemacfs-dxmtrtv
PLAN=$H/docs/nfs-ea-import-20261011
REG=$PLAN/nfs-import.reg
DRY=$PLAN/nfs-ea-import-dryrun.sh
BK=$H/Backups/nfs-ea-import-$TS
WORK=$HOME/.agent-harness/bin/work
BR="/Users/gc/Library/Application Support/BF3Mac"
SPLIC="$SP/drive_c/ProgramData/Electronic Arts/EA Services/License"
LOGD="$SP/drive_c/ProgramData/EA Desktop/Logs"
BSV="$LOGD/EABackgroundServiceVerbose.log"
HDR='[Software\\Wow6432Node\\EA Games\\Need for Speed]'
W=(env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin LANG=en_US.UTF-8 USER=Player HOME="$BR/RuntimeHome/Player" TMPDIR="$BR/Temporary" WINEPREFIX="$SP" WINEDEBUG=-all WINEMSYNC=1 ROSETTA_X87_PATH="$H/Runtimes/hub-0-helpers/x87sidecar" WINEDLLOVERRIDES="winemenubuilder.exe=d")
jr() { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$BK/journal.txt"; }
inv() { (cd "$1" && /usr/bin/find . -type f -print0 | xargs -0 /usr/bin/stat -f '%i%t%l%t%z%t%N') | LC_ALL=C sort -t "$(printf '\t')" -k4,4; }
stopped() { local o; o=$(/bin/bash "$DRY" --gate) || true; printf '%s\n' "$o" | grep -q '^DRYRUN gate ' || { echo "dry-run did not run"; return 1; }; ! printf '%s\n' "$o" | grep -E '^\[FAIL\] (noWineProcess|prefixNotInUse|old wrapper)'; }
lic_bad() { for f in "$SP/drive_c/ProgramData/EA Logs"/gl_log_*.log; do iconv -f UTF-16LE -t UTF-8 "$f" 2>/dev/null; done | grep -acE 'Mismatched machine hash|License Failure' || true; }
echo "TS=$TS"; echo "BK=$BK"
```

`W` is `start-ea.sh`'s environment (same `HOME`, `TMPDIR`, `USER`, `WINEMSYNC=1`, so wine creates no new profile and no second server) minus graphics-only variables, plus `winemenubuilder.exe=d`. The Wine user profile name inside `SP` is `crossover` (pinned by this build; `USER=Player` does not change it). `inv` prints `inode<TAB>linkcount<TAB>size<TAB>name`, sorted by name. `stopped` succeeds when no wine process, prefix use or old wrapper remains (it runs the dry-run in `--gate` mode and looks only at the stop checks). `lic_bad` counts the licence-failure lines in the UTF-16 `gl_log_*.log` files; BF3's old failure lines are already there (10 at the time of the dry-run), so S7 compares counts before and after Play. Rollback needs the original `TS` (the backup directory name is under `/Volumes/ExT2/GameHub/Backups/`).

### S1 Stop everything, then the apply gate

1. In EA: pause BF1 and any download in the Downloads queue, then menu **Quit** (graceful, so EA flushes its install store). Quit any running game and the old NFS wrapper.
2. Block until the shared wineserver is gone, then run the gate:

```bash
"${W[@]}" "$RT/bin/wineserver" -w; echo "wineserver -w rc=$?"
/bin/bash "$DRY" --gate; echo "gate rc=$?"
```

`wineserver -w` returns at once when no server runs. Proceed only when the last line is `DRYRUN gate pass=N fail=0 expected_fail_now=0` and `gate rc=0`. The gate checks: no wine/x87sidecar/`.exe`/NFS2015 process at all; `prefixNotInUse` for `SP` and for `OP` (+ the `~/Library` alias); `OLD` real dir with 144 files, 0 symlinks, all link counts 1, 14,639,595,955 bytes, `NFS16.exe` present; `NEW` absent; same device; shared `system.reg` has no "Need for Speed"; old `system.reg` has the Wow6432Node NFS key; no `1024486.dlf` in the shared License dir; free space >= 1 GiB; tools and the `.reg` bytes.

Note: a parent shell whose command line contains the prefix path (for example `bash -c '... Prefix ...'`) counts as "naming the prefix", as in the original tool. Run the gate from a plain interactive `bash`.

Fallback if `wineserver -w` does not return (a service such as PnkBstrA keeps the server alive) or EA ignores Quit:

```bash fallback
for p in EADesktop.exe EACefSubProcess.exe EABackgroundService.exe EAGEP.exe; do "${W[@]}" "$RT/bin/wine" taskkill /f /im "$p"; done
"${W[@]}" "$RT/bin/wineserver" -w
# last resort only, loses unflushed EA state:
"${W[@]}" "$RT/bin/wineserver" -k; "${W[@]}" "$RT/bin/wineserver" -w
```

### S2 Backups (no wine; cloned copies, near zero extra space)

```bash
( set -euo pipefail
  stopped || { echo "wine/EA/old wrapper still running: quit them and re-run S1"; exit 1; }
  [ ! -e "$BK" ] || { echo "BK exists: $BK"; exit 1; }
  mkdir -p "$BK/files/shared" "$BK/files/old-nfs"
  jr "S2 start: stopped check passed (EA, games, old wrapper not running)"
  for f in system.reg user.reg userdef.reg; do
    /bin/cp -c -p "$SP/$f" "$BK/files/shared/$f"
    /bin/cp -c -p "$OP/$f" "$BK/files/old-nfs/$f"
  done
  mkdir -p "$BK/files/shared/ProgramData/Electronic Arts/EA Services" "$BK/files/old-nfs/ProgramData/Electronic Arts/EA Services"
  /bin/cp -c -R -p "$SP/drive_c/ProgramData/EA Desktop" "$BK/files/shared/ProgramData/EA Desktop"
  /bin/cp -c -R -p "$SPLIC" "$BK/files/shared/ProgramData/Electronic Arts/EA Services/License"
  /bin/cp -c -R -p "$OP/drive_c/ProgramData/Electronic Arts/EA Services/License" "$BK/files/old-nfs/ProgramData/Electronic Arts/EA Services/License"
  /bin/cp -p "$REG" "$BK/nfs-import.reg"
  inv "$OLD" > "$BK/game-inventory-before.tsv"
  [ "$(wc -l < "$BK/game-inventory-before.tsv" | tr -d ' ')" = 144 ] || { echo "inventory is not 144 lines"; exit 1; }
  awk -F'\t' '$2 != 1 { bad++ } END { exit bad > 0 }' "$BK/game-inventory-before.tsv" || { echo "a game file has link count != 1"; exit 1; }
  ( cd "$BK/files" && /usr/bin/find . -type f -print0 | LC_ALL=C sort -z | xargs -0 /usr/bin/shasum -a 256 ) > "$BK/SHA256SUMS"
  ( cd "$BK/files" && /usr/bin/shasum -a 256 -c ../SHA256SUMS > /dev/null )
  ( cd "$BK" && /usr/bin/shasum -a 256 game-inventory-before.tsv nfs-import.reg > SHA256SUMS.meta && /usr/bin/shasum -a 256 -c SHA256SUMS.meta > /dev/null )
  jr "S2 OK: $(wc -l < "$BK/SHA256SUMS" | tr -d ' ') files hashed, inventory 144 lines"
  echo "S2 OK: $BK" ); echo "S2 rc=$?"
```

The game data is not copied: `game-inventory-before.tsv` records inode, link count, size and name of the 144 files. `SHA256SUMS` lines are `<sha256>  <path>` relative to `files/`; verify any time with `cd "$BK/files" && shasum -a 256 -c ../SHA256SUMS`. `SHA256SUMS.meta` covers the inventory and the copied `nfs-import.reg`; verify with `cd "$BK" && shasum -a 256 -c SHA256SUMS.meta`.

### S3 Move the game folder (rename, not copy)

```bash
( set -euo pipefail
  stopped || { echo "wine/EA/old wrapper still running: quit them and re-run S1"; exit 1; }
  [ -f "$BK/game-inventory-before.tsv" ] || { echo "S2 not done, or BK is wrong: set TS to the original value"; exit 1; }
  [ -d "$OLD" ] && [ ! -L "$OLD" ] || { echo "OLD is not a real directory"; exit 1; }
  [ ! -e "$NEW" ] && [ ! -L "$NEW" ] || { echo "NEW already exists"; exit 1; }
  /bin/df -k "$H" | awk 'NR==2{print $4}' > "$BK/free-kb-before.txt"
  jr "S3 mv start"
  /bin/mv -n "$OLD" "$NEW"
  [ ! -e "$OLD" ] || { echo "OLD still exists after mv (BSD mv -n exits 0 when it does nothing)"; exit 1; }
  [ -d "$NEW" ] || { echo "NEW missing after mv"; exit 1; }
  inv "$NEW" > "$BK/game-inventory-after-move.tsv"
  cmp "$BK/game-inventory-before.tsv" "$BK/game-inventory-after-move.tsv" || { echo "inventory differs: not a pure rename"; exit 1; }
  jr "S3 OK: renamed, 144 inodes identical"
  echo "S3 OK" ); echo "S3 rc=$?"
```

From here until S4 finishes, the old wrapper has no game folder. Do not start it.

### S4 Hard-link mirror at the old location

```bash
( set -euo pipefail
  stopped || { echo "wine/EA/old wrapper still running: quit them and re-run S1"; exit 1; }
  [ ! -e "$OLD" ] && [ ! -L "$OLD" ] || { echo "OLD exists"; exit 1; }
  [ -d "$NEW" ] && [ ! -L "$NEW" ] || { echo "NEW missing"; exit 1; }
  mkdir "$OLD"
  (cd "$NEW" && /usr/bin/find . -mindepth 1 -type d -print0) | while IFS= read -r -d '' d; do
    mkdir -p "$OLD/$d" || { echo "mkdir failed: $d"; exit 1; }
  done
  (cd "$NEW" && /usr/bin/find . -type f -print0) | while IFS= read -r -d '' f; do
    /bin/ln "$NEW/$f" "$OLD/$f" || { echo "ln failed: $f"; exit 1; }
  done
  jr "S4 mirror created"
  [ ! -L "$OLD" ] || { echo "OLD is a symlink"; exit 1; }
  [ "$(/usr/bin/find "$OLD" -type f | wc -l | tr -d ' ')" = 144 ] || { echo "OLD file count != 144"; exit 1; }
  [ "$(/usr/bin/find "$OLD" -type l | wc -l | tr -d ' ')" = 0 ] || { echo "symlink under OLD"; exit 1; }
  [ "$(/usr/bin/find "$OLD" -type d | wc -l | tr -d ' ')" = "$(/usr/bin/find "$NEW" -type d | wc -l | tr -d ' ')" ] || { echo "directory count differs"; exit 1; }
  inv "$OLD" > "$BK/game-inventory-mirror-old.tsv"
  inv "$NEW" > "$BK/game-inventory-mirror-new.tsv"
  cmp "$BK/game-inventory-mirror-old.tsv" "$BK/game-inventory-mirror-new.tsv" || { echo "OLD and NEW differ (inode/size/name)"; exit 1; }
  awk -F'\t' '$2 != 2 { bad++ } END { exit bad > 0 }' "$BK/game-inventory-mirror-new.tsv" || { echo "link count != 2"; exit 1; }
  cut -f1,3,4 "$BK/game-inventory-before.tsv" | cmp - <(cut -f1,3,4 "$BK/game-inventory-mirror-new.tsv") || { echo "inodes differ from before S3"; exit 1; }
  F0=$(cat "$BK/free-kb-before.txt"); F1=$(/bin/df -k "$H" | awk 'NR==2{print $4}')
  [ $((F0 - F1)) -lt 102400 ] || { echo "free space dropped by $((F0 - F1)) KiB: data was copied?"; exit 1; }
  jr "S4 OK: 144 hard links, 0 symlinks, free-space delta $((F0 - F1)) KiB"
  echo "S4 OK" ); echo "S4 rc=$?"
```

If this block stops midway (a half-built mirror), run R0 (S4-undo) in section 7, fix the cause, then run S4 again.

### S5 Registry import (wine allowed, EA still stopped)

```bash
( set -euo pipefail
  stopped || { echo "wine/EA/old wrapper still running: quit them and re-run S1"; exit 1; }
  [ -f "$BK/game-inventory-before.tsv" ] || { echo "BK is wrong: set TS to the original value"; exit 1; }
  for p in 'Battlefield 4' 'Battlefield 3' 'Crysis' 'F1_24' 'Need for Speed'; do
    printf '%s\t%s\n' "$p" "$(grep -cF "$p" "$SP/system.reg" || true)"
  done | tee "$BK/reg-counts-before.txt"
  "${W[@]}" "$RT/bin/wine" reg import 'Z:\Volumes\ExT2\GameHub\docs\nfs-ea-import-20261011\nfs-import.reg'
  jr "S5 reg import rc=0"
  "${W[@]}" "$RT/bin/wineserver" -k || true
  "${W[@]}" "$RT/bin/wineserver" -w
  jr "S5 wineserver stopped"
  echo "S5 import OK" ); echo "S5 rc=$?"
```

`wine reg` starts a wineserver for `SP`; services such as PnkBstrA auto-start with it, so `-w` alone may not return. `-k` flushes the registry and exits, then `-w` returns at once.

Verify on disk (read-only). Only the section is extracted (header line to the next `[` line), then the three values are looked up in it:

```bash verify
( set -euo pipefail
  SEC=$(HDR="$HDR" awk 'index($0,ENVIRON["HDR"])==1{f=1;next} f&&/^\[/{exit} f' "$SP/system.reg")
  printf '%s\n' "$SEC"
  [ "$(grep -cF "$HDR" "$SP/system.reg")" = 1 ] || { echo "header count != 1"; exit 1; }
  for l in '"Install Dir"="E:\\EA Games\\Need for Speed\\"' '"Locale"="en_US"' '"Product GUID"="{F8643E83-A868-4EE8-A0B9-389386830453}"'; do
    printf '%s\n' "$SEC" | grep -qxF "$l" || { echo "MISSING: $l"; exit 1; }
  done
  for p in 'Battlefield 4' 'Battlefield 3' 'Crysis' 'F1_24'; do
    before=$(awk -F'\t' -v p="$p" '$1 == p { print $2 }' "$BK/reg-counts-before.txt")
    now=$(grep -cF "$p" "$SP/system.reg" || true)
    [ "$before" = "$now" ] || { echo "COUNT CHANGED for $p: $before -> $now"; exit 1; }
  done
  jr "S5 verified: NFS key present, other game keys unchanged"
  echo "S5 verify OK" ); echo "S5 verify rc=$?"
```

Expected section in `SP/system.reg` (timestamps differ): `[Software\\Wow6432Node\\EA Games\\Need for Speed] <unix time>`, `#time=...`, `"Install Dir"="E:\\EA Games\\Need for Speed\\"`, `"Locale"="en_US"`, `"Product GUID"="{F8643E83-A868-4EE8-A0B9-389386830453}"`.

Alternative if `reg import` fails (documented, not recommended): with **no** wine server running (`stopped` succeeds), append the section to `system.reg` yourself. Wine loads sections in any order. Never `sed -i` a hive; never do this while any wine process runs.

```bash fallback
( set -euo pipefail
  stopped || { echo "wine/EA/old wrapper still running: quit them and re-run S1"; exit 1; }
  /bin/cp -c -p "$SP/system.reg" "$BK/files/shared/system.reg.pre-manual-edit"
  printf '\n[Software\\\\Wow6432Node\\\\EA Games\\\\Need for Speed] %s\n"Install Dir"="E:\\\\EA Games\\\\Need for Speed\\\\"\n"Locale"="en_US"\n"Product GUID"="{F8643E83-A868-4EE8-A0B9-389386830453}"\n' "$(date +%s)" >> "$SP/system.reg"
  echo "appended" ); echo "manual-edit rc=$?"
```

### S6b Copy NFS settings (optional; run after S5 and BEFORE S6, EA must be stopped)

The shared prefix's Wine user is `crossover`, the same as in the old prefix, so the settings folder (about 5 MB) can be cloned over. Nothing is backed up because the target does not exist.

```bash
( set -euo pipefail
  stopped || { echo "wine/EA/old wrapper still running: quit them and re-run S1"; exit 1; }
  SRC="$OP/drive_c/users/crossover/Documents/Need For Speed"
  DOCS="$SP/drive_c/users/crossover/Documents"
  [ -d "$SRC" ] || { echo "source missing: $SRC"; exit 1; }
  [ -d "$DOCS" ] || { echo "target Documents missing: $DOCS"; exit 1; }
  [ ! -e "$DOCS/Need For Speed" ] || { echo "target exists, nothing copied"; exit 1; }
  /bin/cp -c -R "$SRC" "$DOCS/"
  [ -d "$DOCS/Need For Speed/settings" ] || { echo "copy failed"; exit 1; }
  jr "S6b NFS settings copied"
  echo "S6b OK" ); echo "S6b rc=$?"
```

### S6 Start EA and verify detection

The log lines below were recorded by the old prefix's EA build 13.805.11.6320; the shared prefix runs 13.805.99.0, so detection is assumed to behave the same. The start block records the byte size of each checked log first; the verify block reads only bytes added after that point, so old log lines cannot give a false OK. `work wait --log` scans the whole file from offset 0, so it is used only when the stale-match count is 0 (it is today).

```bash
OFF_BSV=$(wc -c < "$BSV" | tr -d ' '); OFF_ED=$(wc -c < "$LOGD/EADesktop.log" | tr -d ' ')
echo "${OFF_BSV:-0} ${OFF_ED:-0}" > "$BK/log-offsets.txt"
STALE=$(grep -ac 'Located files for software \[Origin\.SFT\.50\.0000347\]' "$BSV" || true)
echo "stale matches before start (work wait needs 0): $STALE"
/Volumes/ExT2/GameHub/bin/start-ea.sh
if [ "$STALE" = 0 ]; then
  "$WORK" wait --log "$BSV" 'Located files for software \[Origin\.SFT\.50\.0000347\]\. Setting state to Installed' --timeout 570
  echo "work rc=$? (124 = not yet; run just the wait line again)"
else
  echo "stale lines exist: skip work wait and run the verify block below repeatedly"
fi
```

Then confirm each line (all four must print `OK`). A log that rotated to `.bak` (EA rotates at about 12.6 MB) is handled: if the live file is smaller than the recorded offset it is read whole, and on a miss the `.bak` is searched too.

```bash verify
( set -u; bad=0
  read OFF_BSV OFF_ED < "$BK/log-offsets.txt"
  chk() { local f=$1 off=$2 t=$3 sz; sz=$(wc -c < "$f" | tr -d ' ')
    if [ "$sz" -lt "$off" ]; then off=0; fi
    if tail -c +"$((off + 1))" "$f" | grep -aqF -- "$t"; then echo "OK   $t"
    elif [ -f "${f%.log}.bak" ] && grep -aqF -- "$t" "${f%.log}.bak"; then echo "OK   (in .bak) $t"
    else echo "MISS $t"; bad=1; fi; }
  chk "$BSV" "$OFF_BSV" 'watchPath path [E:\EA Games\Need for Speed\NFS16.exe] for software [Origin.SFT.50.0000347]'
  chk "$BSV" "$OFF_BSV" 'Located files for software [Origin.SFT.50.0000347]. Setting state to Installed'
  chk "$BSV" "$OFF_BSV" 'launcher.exePath=[[HKEY_LOCAL_MACHINE\SOFTWARE\EA Games\Need for Speed\Install Dir]NFS16.exe]'
  chk "$LOGD/EADesktop.log" "$OFF_ED" 'IS update: set installInfo for softwareId=[Origin.SFT.50.0000347] baseSlug=[need-for-speed] installedStatus=[Installed]'
  exit $bad ); echo "S6 verify rc=$?"
```

UI check: Need for Speed shows **Play** (not Download/Install) in the EA app library. Expected and fine: no NFS folder appears under `EA Desktop/InstallData`; the `Could not parse uninstallCommandLine=[]` warning for `Origin.OFR.50.0000810` is non-fatal (same as in the old prefix).

Contingency: if the `watchPath path [E:` line is still a MISS after two `work wait` rounds (2 x 570 s) or two runs of the verify block, EA's detection differs from the old build. Stop (R4 leaves the registry in place), do not improvise, and take open question (c) next: add the native 64-bit key with the same three values.

### S7 First launch and licence (user-driven; may be the same session)

BF3's old `Mismatched machine hash in license` / `License Failure 3` lines are already in `gl_log_2.log` and the lines carry no content ID, so scanning for them proves nothing. Record a baseline **before** pressing Play:

```bash
L0=$(lic_bad); echo "$L0" > "$BK/lic-bad-before.txt"; jr "S7 before Play: licence-failure lines=$L0"
echo "licence-failure lines before Play: $L0"
```

Press **Play** in the EA app and let the game start (or fail). Then:

```bash verify
( set -u
  L0=$(cat "$BK/lic-bad-before.txt"); L1=$(lic_bad)
  echo "licence-failure lines before=$L0 after=$L1 (after > before = failure)"
  if [ "$L1" -gt "$L0" ]; then echo "LICENCE FAILURE: see R2"; else echo "licence OK"; fi
  ls -l "$SPLIC/1024486.dlf"
  grep -ac 'License signature is good' "$SP/drive_c/ProgramData/Origin/Logs/NFS16_1024486_OnlineActivation_Log.html"
  grep -ahF 'Got exePath=[E:\EA Games\Need for Speed\NFS16.exe]' "$LOGD/EADesktop.log" | tail -1 )
```

Expected: a new `1024486.dlf` in the shared License dir; `after` not greater than `before` (a smaller count only means a log rotated); the Origin activation log reports `License signature is good.` (count >= 1); `Got exePath=[E:\EA Games\Need for Speed\NFS16.exe]`. This counts as 1 EA activation (+ possibly 1 Denuvo activation). If `iconv` reports an error for a `gl_log` file (not UTF-16), read that file with `LC_ALL=C tr -d '\000' < "$f"` instead. Disable auto-update for NFS in EA before the first Play; if EA offers an update or repair anyway, note the mirror divergence (section 2).

### S8 Old wrapper smoke test (optional, later)

The old wrapper uses its own prefix and runtime, so it may run whenever the shared EA is not playing NFS from the same files (same inodes, one game at a time). Launch the bundle normally. It must not print `A Windows folder entry is a link`, and it must find `NFS16.exe`. Then write `jr "S8 old wrapper OK"`.

## 6. Verification summary

| What | How | Expected |
|---|---|---|
| Rename, not copy | S3 `cmp` of inventories (same inodes) | identical |
| Mirror | S4 checks | 144 files, 0 symlinks, `OLD` not a link, link count 2, inode equal, free-space delta < 100 MiB |
| Registry | S5 verify | key present with `E:\\...`; BF3/BF4/Crysis/F1 key counts unchanged |
| EA detection | S6 four log lines + UI | Installed / Play |
| Licence | S7 | new dlf; licence-failure line count after Play not greater than before Play (`L1 <= L0`) |
| Old wrapper | S8 | no link error |

## 7. Rollback

Always first: quit EA/games/wrapper, set `TS=<original value>` and paste S0, then confirm `stopped && echo STOPPED` prints `STOPPED` (it prints the offending dry-run lines otherwise). Every rollback block re-checks both. Do R1 to R3 in order (R0 first if S4 stopped midway); each is independent of which later steps have run.

### R0 Undo a half-built mirror (S4-undo; run when S4 stopped midway)

Removes `OLD` only if every file in it is a hard link of its `NEW` counterpart and it holds nothing but files and directories, so no data can be lost.

```bash
( set -euo pipefail
  stopped || { echo "wine/EA/old wrapper still running: quit them and re-run S1"; exit 1; }
  [ -d "$OLD" ] && [ ! -L "$OLD" ] || { echo "OLD is not a real directory: nothing to undo"; exit 1; }
  [ -d "$NEW" ] || { echo "NEW missing: do not remove OLD"; exit 1; }
  (cd "$OLD" && /usr/bin/find . -type f -print0) | while IFS= read -r -d '' f; do [ "$OLD/$f" -ef "$NEW/$f" ] || { echo "unique file: $f"; exit 1; }; done
  [ "$(/usr/bin/find "$OLD" ! -type f ! -type d | wc -l | tr -d ' ')" = 0 ] || { echo "OLD holds symlinks or other non-file entries: inspect by hand"; exit 1; }
  rm -r "$OLD"
  [ ! -e "$OLD" ] || { echo "OLD still exists"; exit 1; }
  echo "S4-undo OK" ); echo "S4-undo rc=$?"
```

### R1 Registry (delete only the NFS keys, never the parent `EA Games`, which holds BF3/BF4)

Deletes the 32-bit key, and the native key too if a touchup created one. Each delete runs only if the key exists.

```bash
( set -euo pipefail
  [ -f "$BK/game-inventory-before.tsv" ] || { echo "BK is wrong: set TS to the original value"; exit 1; }
  stopped || { echo "wine/EA/old wrapper still running: quit them and re-run S1"; exit 1; }
  if "${W[@]}" "$RT/bin/wine" reg query 'HKLM\SOFTWARE\Wow6432Node\EA Games\Need for Speed' >/dev/null 2>&1; then
    "${W[@]}" "$RT/bin/wine" reg delete 'HKLM\SOFTWARE\Wow6432Node\EA Games\Need for Speed' /f
  fi
  if "${W[@]}" "$RT/bin/wine" reg query 'HKLM\SOFTWARE\EA Games\Need for Speed' >/dev/null 2>&1; then
    "${W[@]}" "$RT/bin/wine" reg delete 'HKLM\SOFTWARE\EA Games\Need for Speed' /f
  fi
  "${W[@]}" "$RT/bin/wineserver" -k || true
  "${W[@]}" "$RT/bin/wineserver" -w
  [ "$(grep -cF "$HDR" "$SP/system.reg" || true)" = 0 ] || { echo "NFS key still present"; exit 1; }
  grep -nE 'Need for Speed|F8643E83' "$SP/system.reg" || echo "no NFS leftovers"
  jr "R1 NFS registry keys removed"
  echo "R1 OK" ); echo "R1 rc=$?"
```

If the `grep` lists lines (for example an `Uninstall\{F8643E83-...}` entry created by a touchup), review them by hand; the plan never deletes those automatically. Restoring the whole `system.reg` from `$BK/files/shared/system.reg` is a last resort only: it would also revert unrelated changes made since the backup (for example BF1 progress).

### R2 Licence

```bash
( set -euo pipefail
  [ -f "$BK/game-inventory-before.tsv" ] || { echo "BK is wrong: set TS to the original value"; exit 1; }
  stopped || { echo "wine/EA/old wrapper still running: quit them and re-run S1"; exit 1; }
  mkdir -p "$BK/rolled-back"
  if [ -e "$SPLIC/1024486.dlf" ]; then
    [ ! -e "$BK/rolled-back/1024486.dlf" ] || { echo "rolled-back/1024486.dlf already exists"; exit 1; }
    /bin/mv -n "$SPLIC/1024486.dlf" "$BK/rolled-back/1024486.dlf"
    [ ! -e "$SPLIC/1024486.dlf" ] || { echo "not moved"; exit 1; }
  fi
  jr "R2 new 1024486.dlf (if any) moved to rolled-back/"
  echo "R2 OK" ); echo "R2 rc=$?"
```

Nothing is deleted. The old prefix's own `1024486.dlf` was never touched.

### R3 Game files back to the old location

```bash
( set -euo pipefail
  [ -f "$BK/game-inventory-before.tsv" ] || { echo "BK is wrong: set TS to the original value"; exit 1; }
  stopped || { echo "wine/EA/old wrapper still running: quit them and re-run S1"; exit 1; }
  [ -d "$NEW" ] && [ ! -L "$NEW" ] || { echo "NEW missing"; exit 1; }
  if [ -e "$OLD" ]; then
    inv "$OLD" > "$BK/rollback-old.tsv"; inv "$NEW" > "$BK/rollback-new.tsv"
    cmp "$BK/rollback-old.tsv" "$BK/rollback-new.tsv" || { echo "STOP: OLD mirror and NEW differ (EA patched a file?). Nothing deleted. Decide by hand."; exit 1; }
    rm -r "$OLD"
  fi
  [ ! -e "$OLD" ] || { echo "OLD still exists"; exit 1; }
  /bin/mv -n "$NEW" "$OLD"
  [ ! -e "$NEW" ] || { echo "NEW still exists: mv did not move it"; exit 1; }
  inv "$OLD" > "$BK/rollback-after.tsv"
  cmp "$BK/game-inventory-before.tsv" "$BK/rollback-after.tsv" || { echo "inventory differs from game-inventory-before.tsv"; exit 1; }
  jr "R3 OK: game folder back at OLD, inventory identical to before"
  echo "R3 OK" ); echo "R3 rc=$?"
```

`rm -r "$OLD"` removes only the mirror's names (the files stay alive through `NEW`). If EA patched files, the comparison fails and the block stops before deleting anything.

### R4 EA state

After R1 and R3, EA marks NFS NotInstalled on the next start (the watched path no longer exists). Restore `ProgramData/EA Desktop` from `$BK/files/shared/ProgramData/EA Desktop` only if EA state is corrupt; move the current one aside first, never delete it:

```bash fallback
( set -euo pipefail
  [ -f "$BK/game-inventory-before.tsv" ] || { echo "BK is wrong: set TS to the original value"; exit 1; }
  stopped || { echo "wine/EA/old wrapper still running: quit them and re-run S1"; exit 1; }
  mkdir -p "$BK/rolled-back"
  [ ! -e "$BK/rolled-back/EA Desktop.after" ] || { echo "rolled-back/EA Desktop.after already exists"; exit 1; }
  /bin/mv -n "$SP/drive_c/ProgramData/EA Desktop" "$BK/rolled-back/EA Desktop.after"
  [ ! -e "$SP/drive_c/ProgramData/EA Desktop" ] || { echo "EA Desktop not moved"; exit 1; }
  /bin/cp -c -R -p "$BK/files/shared/ProgramData/EA Desktop" "$SP/drive_c/ProgramData/EA Desktop"
  jr "R4 EA Desktop state restored"; echo "R4 OK" ); echo "R4 rc=$?"
```

### R5 Journal

`$BK/journal.txt` records every step (UTC time, step, result); add `jr "R<n> ..."` lines as shown. Keep `$BK` (hashed, cloned) until you are satisfied. `mv -n` exits 0 when it does nothing, so every `mv -n` above is followed by an existence check.

## 8. What NOT to do

- No symlink at `OLD` (old wrapper throws `A Windows folder entry is a link`).
- Do not copy `1024486.dlf` into the shared License dir (machine-binding mismatch, wasted activation).
- No edits to the bundles under `/Volumes/ExT2/Bundles` and none to the old prefix besides the S4 hard links.
- No `sed -i`/manual edit on a live hive; the manual append is only for a stopped prefix.
- No fabricated `Uninstall`, GDF/GameUX, `Origin Games` or `InstallData` records.
- No `reg delete` of the parent `EA Games` key.
- No `sleep`; no second wineserver or runtime switch while EA runs.
- Never add or remove drive letters in `SP` (`dosdevices`): changing the storage count is what invalidated BF3's `70619.dlf`.

## 9. Risks and open questions

Risks:

- Mirror divergence after an EA update (D2). Mitigation: the old wrapper keeps working with the old version; or skip the mirror (question b).
- `autoUpdateEnabled=1` and `treatUpdatesAsMandatory=1` mean EA may patch or repair NFS (`forceTouchupInstallerAfterUpdate=1`; touchup is non-elevated and idempotent but untested in the shared prefix). Write-new + rename keeps the old inodes alive in the mirror, so disk use grows by the patched size; a full repair is about 14.6 GB against about 37 to 40 GiB free at the dry-run. Disable auto-update for NFS in EA before the first Play. Re-mirroring `OLD` from `NEW` is possible later (R3 verification fails on divergence by design; redo S4 after removing the mirror).
- First launch may need an EA activation and a Denuvo activation (D6). BF3's old `Mismatched machine hash` lines are already in `gl_log_2.log` and the lines carry no content ID, so S7 decides failure only by `L1 > L0` (licence-failure line count after Play greater than before Play). On failure, move the new dlf aside (R2) and retry once.
- EA build difference: the evidence is from 13.805.11.6320, the shared prefix runs 13.805.99.0. If S6's `watchPath path [E:` line is still a MISS after two `work wait` rounds, the next step is open question (c), the native 64-bit key.
- Disk is at 96 % (about 37 to 40 GiB free); the BF1 download is the main consumer, not this plan.
- A parent process naming the prefix path makes the gate fail (see S1 note).

Open questions for you:

- (a) Target path `E:\EA Games\Need for Speed` lies outside the library root `E:\EA Games\BF4\`. This is fine for detection. If you prefer `E:\EA Games\BF4\Need for Speed`, change `NEW`, the `.reg` `Install Dir` and the greps in S5/S6/S7 (JSON `paths.NEW` too).
- (b) Do you want to keep the old wrapper? If not, skip S4: `OLD` then simply disappears and the wrapper would fail its locate check.
- (c) Add the native 64-bit key `HKLM\SOFTWARE\EA Games\Need for Speed` too? Not needed per the evidence (EA reads the 32-bit view); it is the contingency if S6 does not detect NFS.
- (d) NFS settings (`drive_c/users/crossover/Documents/Need For Speed`, about 5 MB): the shared prefix uses the same Wine user `crossover`, so the optional step S6b copies them (cloned, target absent, EA stopped). Skip S6b if you want a fresh profile.

## 10. Dry-run checklist and record

Run any time (read-only; no wine, no files written, no `sleep`):

```bash
/bin/bash /Volumes/ExT2/GameHub/docs/nfs-ea-import-20261011/nfs-ea-import-dryrun.sh          # plan mode
/bin/bash /Volumes/ExT2/GameHub/docs/nfs-ea-import-20261011/nfs-ea-import-dryrun.sh --gate   # S1 gate: exit 0 only if every check passes, else 2
```

Checklist: no wine process; `prefixNotInUse` SP (with the `Relocated/BF3Mac` and `~/Library/.../BF3Mac` aliases) and OP; old wrapper not running; `OLD` real dir, 144 files, 0 symlinks, all link counts 1, 14,639,595,955 bytes, `NFS16.exe`; `NEW` absent and its parent writable; same device; `e:` -> GameHub and `z:` -> `/`; S6b target free; shared `system.reg` clean; old key present; no shared `1024486.dlf`; free space; `wine`, `wineserver`, `start-ea.sh`, `work`; Backups parent writable; `nfs-import.reg` bytes. Info only: machash, installStore state, running installers. Last line: `DRYRUN <mode> pass=N fail=M expected_fail_now=K`.

The recorded output lives in this document (no other file was permitted).

### Dry-run record (2026-10-11, EA running)

Plan mode, 2026-10-11T15:02Z, exit 0 (`bash -n` clean). The two `EXPECTED-FAIL-NOW` items are the stop checks (EA and BF4 were running, as were other sessions' shells whose command lines name the prefix, which the heuristic counts); a `--gate` run at the same time exits 2 with those two as FAIL. Long lines are cut by the script itself; four tool checks and three `.reg` checks are joined onto one line here and the `.reg` listing the script prints is omitted.

```text
== nfs-ea-import dry run, mode=plan, 2026-10-11T15:02:29Z, host MBP23.local ==
[EXPECTED-FAIL-NOW] noWineProcess -- 27 matching processes: EADesktop.exe, x87sidecar, EACefSubProcess.exe, bf4.exe, ... (+22 more)
[EXPECTED-FAIL-NOW] prefixNotInUse shared prefix SP (+ Relocated and ~/Library BF3Mac aliases) -- open files: 809 e.g. /Volumes/ExT2/GameHub/Prefix/drive_c/Program Files/Electronic Arts/EA Desktop/13.805.11.6320-1791598480/EA Desktop ...
      | wine server socket /tmp/.wine-503/server-100002c-114cbb/socket is held (173 handles)
      | wine server socket /private/tmp/.wine-503/server-100002c-114cbb/socket is held (173 handles)
      | 3 process(es) name the prefix: ...
[PASS] prefixNotInUse old NFS prefix OP (+ ~/Library alias) -- dev 16777260 ino 1143392 (100002c-117260)
[PASS] old wrapper not running -- no NFS2015Launcher/NFS2015Session/bundle process
[PASS] OLD is a real directory -- .../Relocated/NFS2015Mac/Data/Prefix/drive_c/Program Files/EA Games/Need for Speed
[PASS] fileCount OLD == 144 -- found 144
[PASS] symlinks under OLD == 0 -- found 0
[PASS] linkCount: all OLD files have 1 link -- 0 files with more than 1 link
[PASS] total bytes OLD == 14639595955 -- found 14639595955
[PASS] NFS16.exe present -- 106474272 bytes
[INFO] directories under OLD (incl. root): 26
[PASS] NEW absent -- /Volumes/ExT2/GameHub/EA Games/Need for Speed
[PASS] NEW parent exists, is a real dir, writable -- /Volumes/ExT2/GameHub/EA Games
[PASS] sameDevice OLD / NEW parent / SP -- dev OLD=16777260 NEWparent=16777260 SP=16777260
[PASS] SP dosdevices e: -> /Volumes/ExT2/GameHub -- /Volumes/ExT2/GameHub
[PASS] SP dosdevices z: -> / -- /
[PASS] shared system.reg has no 'Need for Speed' -- 0 matching lines
[PASS] old system.reg has the Wow6432Node NFS key
[PASS] shared License dir has no 1024486.dlf -- present: 1007968.dlf 16425782.dlf 70619.dlf 71503.dlf
[INFO] old prefix licence: 1889 bytes Oct 8 20:49
[PASS] free space >= 1 GiB -- free 37 GiB (39534196 KiB); the plan itself copies no game data
[PASS] RT/bin/wine executable / wineserver executable / start-ea.sh executable / work exists
[PASS] Backups parent exists and is writable -- /Volumes/ExT2/GameHub/Backups
[PASS] shared EA Desktop + License dirs exist (backup sources)
[PASS] nfs-import.reg header + 3 values / plain ASCII / bytes == expected (197 bytes)
[PASS] S6b target free (shared crossover Documents exists, no 'Need For Speed' yet)
[INFO] EA machash in shared EADesktop.log: d1920624b6654b648e83b7732a233cc23636a0c9 (== expected, identical to old prefix)
[INFO] shared installStore last state for Origin.SFT.50.0000347: NotInstalled (expected NotInstalled before the import)
[INFO] EA install/touchup processes running now: 0 (this cannot see downloads: pause BF1 and any download in the EA Downloads queue before Quit)
DRYRUN plan pass=27 fail=0 expected_fail_now=2
```
