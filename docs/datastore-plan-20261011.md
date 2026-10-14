# GameHub data store reorganisation (2026-10-11)

## 1. Summary and status

Status: Approved by the user (plan v3). Executed step by step with `gamehub-cli datastore apply`; see STATUS-20261011.md for the outcome.

This document records the reorganisation of `/Volumes/ExT2/GameHub` into a data store with fixed locations for Hub state, the shared Wine prefix, launcher libraries, backups and app build output. It covers the target layout, the decisions behind it, the executable manifest and how to run it, each of the 12 steps, what is deliberately not moved, the Hub code location, rollback, and the checks the user has to make.

Why: the Hub code and scripts pinned paths in several places (`Relocated/BF3Mac/Data/Prefix`, a Bundles-based runtime, `/Volumes/ExT2/Steam`, and others), and nothing defined where Hub state, logs and launcher libraries live. The reorganisation gives each a stable place and keeps every old path working through a link, except the case-only rename `backups` to `Backups`.

Sources: the manifest `/Volumes/ExT2/GameHub/docs/datastore-plan-20261011.json`, the dry-run record `/Volumes/ExT2/GameHub/docs/datastore-dryrun-20261011.txt` (2026-10-11T11:54:34Z, exit 0, 277 checks pass, 0 fail, 2 skipped because they need the real result of the step), and the survey `/Volumes/ExT2/GameHub/docs/datastore-survey-20261011.md`.

## 1.1 Update: EA library consolidation completed 2026-10-11

The EA library consolidation (see `docs/ea-library-consolidation-20261011.md`) has been applied. The EA library root is now `E:\EA Games` (physical `/Volumes/ExT2/GameHub/EA Games`), in a flat structure with five games: Battlefield 3, Battlefield 4, Crysis 3, F1 24, Need for Speed. The decision D-EA (keep the EA library physical) remains valid; the `Library/EA -> ../EA Games` symlink target is unchanged and valid. Any references in this document to `EA Games/BF4` nesting, BF3 inside `drive_c/Program Files`, or the NFS mirror are superseded; consult § Result in the consolidation plan for the applied mapping and backups.

## 2. Target tree

`H` = `/Volumes/ExT2/GameHub` (Windows drive `E:`). `->` marks a symlink.

```
/Volumes/ExT2/
  Backups/   Bundles/ (untouched, protected)   GameHub/   Scratch-bf3-native/
  Steam -> GameHub/Library/Steam            SteamGames -> GameHub/Library/SteamGames
  EpicGamesStore -> GameHub/Library/Epic    "Ubisoft Game Launcher" -> GameHub/Library/Ubisoft
  "EA Games" -> GameHub/Library/EA-unregistered
GameHub/
  Hub/ hub.json  State/ (0700)  Logs/ (<- Logs)  Home/Player  Temp/  Knowledge/
  Logs -> Hub/Logs
  Prefix/                     shared Wine prefix (<- Relocated/BF3Mac/Data/Prefix, same inode)
  EA Games/BF4/...            EA library, physical, = E:\EA Games (EA records unchanged; protected)
  Library/ EA -> ../EA Games  Steam/  SteamGames/  Epic/GTAV  Ubisoft/  EA-unregistered/
  Relocated/ BF3Mac/Data/Prefix -> ../../../Prefix ; NFS2015Mac/ (unchanged)
  Runtimes/                   hub-0, hub-0-helpers, hub-0-winemacfs, wine-0010, wine-0011
                              (+ hub-0.manifest, hub-0.manifest.links); kept until the user confirms
  Backups/ (<- backups, case-only rename)
                              datastore-20261011/{files/, SHA256SUMS, symlinks.tsv, journal.jsonl}
  Apps/ GameHub.app (build output), Bundles -> ../../Bundles
  Build/                      SwiftPM scratch for the app build
  bin/ docs/ STATUS-*.md      unchanged names (operator area)
  work/ src/ toolchains/ inputs/ reference/ downloads/   dev area: NOT moved (section 6)

Mac (internal disk):
  ~/Applications/GameHub Runtime hub-0.app
      Contents/SharedSupport/Wine   = hub-0
      Contents/Helpers/x87sidecar
      Contents/Resources/hub-0.manifest + .links
      Contents/Info.plist
  ~/Library/Application Support/GameHub/settings.json   (data store root, runtime app location)
  ~/Library/Application Support/BF3Mac/Data/Prefix -> /Volumes/ExT2/GameHub/Prefix
```

Notes on the tree:

- The runtime goes to the Mac as `~/Applications/GameHub Runtime hub-0.app`. It is built from the plain `Runtimes/hub-0` by a byte copy verified against `hub-0.manifest`; `cp -c` cannot clone across volumes (EXDEV).
- `Runtimes/` on ExT2 keeps `hub-0`, `hub-0-helpers`, `hub-0-winemacfs`, `wine-0010` and `wine-0011` (1.40 GB each, kept as named test baselines) until the user confirms the runtime app. `hub-0-winemacfs` is a patched clone made by the coordinator (`hub-0` plus new `winemac.so`/`drv`); `bin/start-ea.sh` uses it through the `HUB_RUNTIME` default.
- `~/Library/Application Support/GameHub/settings.json` holds the data store root and the runtime app location. Both are configurable in HubApp Settings. They are stored on the Mac because `Hub/hub.json` lives on the data store and cannot be read when the drive is unplugged.

## 3. Decisions

| Id | Decision | Reason |
|---|---|---|
| D-EA | The EA library stays physical at `GameHub/EA Games`; `Library/EA` is a host-side view link. Registry and ini records are untouched. | Every EA record is a Windows path through `E:` (`E:\EA Games\BF4\...`) or `C:`. Windows must not see a symlinked path, and `e:` is never re-pointed: the BF3 licence already broke once ("Mismatched machine hash") after the `E:` mapping was added. |
| D-STEAM | Rewrite the 5 Steam records to `Z:\\Volumes\\ExT2\\GameHub\\Library\\Steam`; launch Steam only via the new path. | These are the only live pins: 2 `libraryfolders.vdf` and 3 `appmanifest_*.acf` `LauncherPath` values. No registry keys. |
| D-CASE | No compatibility links for case-only renames (`backups` to `Backups` gets none). | A case-only rename cannot keep a link at the old name on this volume. References in STATUS files are updated by note. |
| D-DEV | The dev area is not moved. | See section 6. |
| D-RT | The runtime is an app bundle on the internal disk, built by a byte copy of `Runtimes/hub-0` verified against `hub-0.manifest`. | `cp -c` cannot clone across volumes. |
| D-SET | Locations are stored on the Mac (`settings.json`), not only in `hub.json`. | `hub.json` is on the data store and is unreachable when the drive is unplugged. |

Further decisions:

- S03 checks that no process uses the BF3 prefix (open files, the wineserver socket by dev/ino, command lines) rather than requiring zero wine processes. Another agent legitimately runs wine on a throwaway prefix.
- Every moved tree must be quiet for 10 minutes (`quietFor`, `minutes: 10`): S03 and S07-S11.
- `GameHub/EA Games`, `/Volumes/ExT2/Bundles` and the internal `Prefix.internal-old-20261010` directories (under `~/Library/Application Support/BF3Mac/Data` and `.../NFS2015Mac/Data`) are protected in the manifest and are never touched.
- The CLI is named `gamehub-cli` because `gamehub` collides with `GameHub` in `.build` on the case-insensitive internal disk.

## 4. How to run

### Manifest schema (`schemaVersion` 1)

Top level: `id` (`datastore-20261011`), `volume`, `protected` (paths no operation may touch), `allowedRoots`, `backupDir` (`/Volumes/ExT2/GameHub/Backups/datastore-20261011`), `journal` (`<backupDir>/journal.jsonl`), `steps`.

Each step has `id`, `title`, optional `notes`, `requiresNoWine`, `preconditions`, `operations`, `verify`.

| Op | Behaviour |
|---|---|
| `mkdir` | Creates a directory with the given mode; fails if the path exists or a case-insensitive sibling exists. |
| `rename` | `renamex_np` with `RENAME_EXCL`, source and destination parent on one device; never copies. |
| `symlink` | Creates a link; the path must be absent. |
| `replaceSymlink` | Atomically replaces an existing symlink; `expectedTarget` must match the current target. |
| `backup` | Copies the file or symlink into `backupDir` (`files/`, `SHA256SUMS`, `symlinks.tsv`). Rollback restores from it. |
| `rewriteText` | Replaces `find` with `replace`, requires exactly `expectedCount` occurrences, written atomically. |
| `writeHubConfig` | Writes `hub.json` (prefix, runtime id, runtime manifest path and SHA-256, generation). |

Every operation also gets implicit checks before it runs (visible in the dry-run record): volume mounted, journal directory exists, path absent or a real file/directory as the op requires, no case-insensitive sibling, parent exists, same device for renames, no open file under a rename source, and not inside a `protected` path. Where the dry-run record lists these as "implicit", this is what they mean.

Check kinds used in `preconditions` and `verify`: `exists` (file/directory), `absent`, `notSymlink`, `symlinkTarget`, `sameFile` (same dev/ino), `quietFor`, `prefixNotInUse`, `prefixLocates`, `textContains` (with `count`), `shellSyntax`, `vdfParses`, `hubConfigValid`.

### Commands

Run from `~/Developer/nfs-macos`, with the plan `/Volumes/ExT2/GameHub/docs/datastore-plan-20261011.json`:

```
swift run gamehub-cli datastore validate <plan>
swift run gamehub-cli datastore dry-run <plan> [--step ID] [--json]
swift run gamehub-cli datastore apply <plan> --step ID [--json]
swift run gamehub-cli datastore verify <plan> --step ID [--json]
swift run gamehub-cli datastore rollback <plan> --step ID [--json]
swift run gamehub-cli datastore status <plan> [--json]
```

`apply` runs exactly one step. Run steps in order and stop at the first failure.

| Exit | Meaning |
|---|---|
| 0 | OK |
| 1 | Usage error or invalid plan |
| 2 | A precondition failed (or the command was refused on order/journal state); nothing changed |
| 3 | An operation failed; the step was undone |
| 4 | A verify check failed; the step was undone |
| 5 | An undo failed; the disk is half-changed and the report names its exact state |

(Exit codes from the doc comment in `Sources/HubCore/Datastore/DatastoreCommand.swift`.)

## 5. Steps S01-S12

Measured entries and bytes are the dry-run's "measured before" figures for the renamed tree. The dry-run result for every step was `planned` with all checks passing, apart from the skipped checks named below. Rollback for every step is `swift run gamehub-cli datastore rollback <plan> --step <ID>`; it applies the inverse of the step's operations in reverse order (renames back, created links and directories removed, replaced links and files restored from `Backups/datastore-20261011`).

### S01-backups-dir: capitalise the backups folder, create the backup directory
- Preconditions: none explicit. Implicit: `GameHub/backups` is a real directory; `GameHub/Backups` is absent with no case-insensitive sibling; same device; no open file.
- Operations: `rename` `H/backups` to `H/Backups`; `mkdir` `H/Backups/datastore-20261011` (0755).
- Verify: `H/Backups/Crysis3-installerdata.xml.orig-20261011` exists (file); `H/Backups/licenses-20261011` exists (directory).
- Rollback: `rollback --step S01-backups-dir` is not usable here. The journal and backups live inside the renamed folder, so S01 is undone by hand (section 8).
- Dry run: planned, pass. Measured 5 entries, 20,532 bytes.

### S02-hub-tree: create the Hub tree, move the logs into it
- Preconditions: none explicit. Implicit: `H/Hub` and children absent; `H/Logs` is a real directory with no open files.
- Operations: `mkdir` `Hub` (0755), `Hub/State` (0700), `Hub/Home` (0755), `Hub/Home/Player` (0755), `Hub/Temp` (0755), `Hub/Knowledge` (0755); `rename` `H/Logs` to `H/Hub/Logs`; `symlink` `H/Logs` -> `Hub/Logs`.
- Verify: no explicit checks (implicit post-checks only).
- Rollback: `rollback --step S02-hub-tree`: removes the `Logs` link, renames `Hub/Logs` back, removes the created directories.
- Dry run: planned, pass. Measured (Logs): 22 entries, 2,117,030 bytes.

### S03-prefix: move the shared Wine prefix to `GameHub/Prefix`
- Preconditions: `prefixNotInUse` on `H/Relocated/BF3Mac/Data/Prefix` (aliases `~/Library/Application Support/BF3Mac/Data/Prefix` and `~/Library/Application Support/BF3Mac`); `quietFor` 10 min on the same path. `requiresNoWine` is false.
- Operations:
  1. `backup` the link `~/Library/Application Support/BF3Mac/Data/Prefix`.
  2. `rename` `H/Relocated/BF3Mac/Data/Prefix` to `H/Prefix` (same inode).
  3. `symlink` `H/Relocated/BF3Mac/Data/Prefix` -> `../../../Prefix`.
  4. `replaceSymlink` `~/Library/Application Support/BF3Mac/Data/Prefix` -> `/Volumes/ExT2/GameHub/Prefix`, `expectedTarget` `/Volumes/ExT2/GameHub/Relocated/BF3Mac/Data/Prefix` (atomic).
- Verify: `sameFile` for `H/Prefix` against both old paths; `system.reg` and `user.reg` exist; `dosdevices/e:` -> `/Volumes/ExT2/GameHub`, `c:` -> `../drive_c`, `z:` -> `/`; `drive_c/Program Files/Electronic Arts/EA Desktop` and `H/EA Games/BF4/Battlefield 4` exist; `prefixLocates` resolves the Mac link to `/Volumes/ExT2/GameHub/Prefix` (allowed roots: `H`, `BF3Mac`, `NFS2015Mac`).
- Rollback: `rollback --step S03-prefix`: re-points the Mac link to the old target (from the backup), removes the compat link, renames `Prefix` back.
- Dry run: planned, pass. `prefixNotInUse` passed with "stale Wine socket with no holder"; newest of 9,824 entries changed 54m 31s earlier. Measured: 9,823 entries, 25,240,835,881 bytes, 4 symlinks. `prefixLocates` skipped (needs the real result).

### S04-hub-config: write the Hub configuration
- Preconditions: `H/Hub/hub.json` absent.
- Operations: `writeHubConfig` `H/Hub/hub.json`, prefix `/Volumes/ExT2/GameHub/Prefix`, runtime `hub-0`, runtime manifest `H/Runtimes/hub-0.manifest` with SHA-256 `278e1d9da269c8c1f28d6a8b93451461b76a069336d9dcbea1496170163a6f9f`, generation 0. The implicit check confirms the manifest hash matches.
- Verify: `hubConfigValid` for the file against the prefix.
- Rollback: `rollback --step S04-hub-config`: removes the written `hub.json`.
- Dry run: planned, pass (manifest hash matched). `hubConfigValid` skipped (file exists only after the step). No tree measured.

### S05-scripts: point the helper scripts at the new prefix, logs and runtime
- Preconditions: `H/Runtimes/hub-0-winemacfs/bin/wine` and `H/Runtimes/hub-0-helpers/x87sidecar` exist (files). Implicit: each `find` string occurs exactly once.
- Operations: `backup` `H/bin/start-ea.sh` and `H/bin/wine-query.sh`, then seven `rewriteText` edits, each `expectedCount` 1:

| File | Find | Replace |
|---|---|---|
| `start-ea.sh` | `BUN="/Volumes/ExT2/Bundles/Battlefield 3 Bundled 20261009-5ee7913.app/Contents"` | `RT="${HUB_RUNTIME:-/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs}"` |
| `start-ea.sh` | `log="/Volumes/ExT2/GameHub/Logs/ea-$ts.log"` | `log="/Volumes/ExT2/GameHub/Hub/Logs/ea-$ts.log"` |
| `start-ea.sh` | `WINEPREFIX="$R/Data/Prefix"` | `WINEPREFIX="/Volumes/ExT2/GameHub/Prefix"` |
| `start-ea.sh` | `ROSETTA_X87_PATH="$BUN/Helpers/x87sidecar"` | `ROSETTA_X87_PATH="/Volumes/ExT2/GameHub/Runtimes/hub-0-helpers/x87sidecar"` |
| `start-ea.sh` | `"$BUN/SharedSupport/Wine/bin/wine"` | `"$RT/bin/wine"` |
| `wine-query.sh` | `B="/Volumes/ExT2/Bundles/Battlefield 3 Bundled 20261009-5ee7913.app/Contents/SharedSupport/Wine/bin/wine"` | `B="${HUB_RUNTIME:-/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs}/bin/wine"` |
| `wine-query.sh` | `WINEPREFIX="$R/Data/Prefix"` | `WINEPREFIX="/Volumes/ExT2/GameHub/Prefix"` |

  The COMPAT block, the WINEDEBUG default, `HOME`, `TMPDIR` and `R` are left untouched.
- Verify: `bash -n` syntax check on both scripts; each replacement string present exactly once; `$BUN` absent (0) from `start-ea.sh`; `/Volumes/ExT2/Bundles` absent (0) from both scripts.
- Rollback: `rollback --step S05-scripts`: restores both scripts from the backup (checked against `SHA256SUMS`).
- Dry run: planned, pass; all find strings occurred once. No tree measured.

### S06-library: create the Library folder and link the EA games into it
- Preconditions: none. Implicit: `H/Library` absent.
- Operations: `mkdir` `H/Library` (0755); `symlink` `H/Library/EA` -> `../EA Games`.
- Verify: `H/EA Games` is not a symlink and is a directory.
- Rollback: `rollback --step S06-library`: removes the link, then the directory.
- Dry run: planned, pass. No tree measured.

### S07-steam: move Steam into the Library and fix the Windows paths
- Preconditions: `quietFor` 10 min on `/Volumes/ExT2/Steam`.
- Operations: `rename` `/Volumes/ExT2/Steam` to `H/Library/Steam`; `symlink` `/Volumes/ExT2/Steam` -> `GameHub/Library/Steam`; `backup` of the five files below; then five `rewriteText` edits, each `expectedCount` 1. In the files the backslashes are doubled (VDF escaping):

| File (under `H/Library/Steam`) | Find | Replace |
|---|---|---|
| `steamapps/libraryfolders.vdf` | `"Z:\\Volumes\\ExT2\\Steam"` | `"Z:\\Volumes\\ExT2\\GameHub\\Library\\Steam"` |
| `config/libraryfolders.vdf` | `"Z:\\Volumes\\ExT2\\Steam"` | `"Z:\\Volumes\\ExT2\\GameHub\\Library\\Steam"` |
| `steamapps/appmanifest_1359090.acf` | `Z:\\Volumes\\ExT2\\Steam\\steam.exe` | `Z:\\Volumes\\ExT2\\GameHub\\Library\\Steam\\steam.exe` |
| `steamapps/appmanifest_228980.acf` | same | same |
| `steamapps/appmanifest_243470.acf` | same | same |

- Verify: both `libraryfolders.vdf` parse (`vdfParses`); each new string present exactly once in its file; `Library/Steam/steam.exe` exists; `sameFile` of `/Volumes/ExT2/Steam` and `H/Library/Steam`.
- Rollback: `rollback --step S07-steam`: restores the five files from the backup, removes the link, renames the tree back.
- Dry run: planned, pass. Newest of 56,256 entries changed 50m 58s earlier. Measured: 56,255 entries, 307,166,481,007 bytes, 0 symlinks.

### S08-steamgames: move SteamGames into the Library
- Preconditions: `quietFor` 10 min on `/Volumes/ExT2/SteamGames`.
- Operations: `rename` to `H/Library/SteamGames`; `symlink` `/Volumes/ExT2/SteamGames` -> `GameHub/Library/SteamGames`.
- Verify: none explicit. Nothing pins this folder; its manifests are stale (section 6).
- Rollback: `rollback --step S08-steamgames`: removes the link, renames back.
- Dry run: planned, pass. Measured: 71 entries, 1,706,449 bytes, 0 symlinks.

### S09-epic: move the Epic Games Store folder into the Library
- Preconditions: `quietFor` 10 min on `/Volumes/ExT2/EpicGamesStore`.
- Operations: `rename` to `H/Library/Epic`; `symlink` `/Volumes/ExT2/EpicGamesStore` -> `GameHub/Library/Epic`.
- Verify: `H/Library/Epic/GTAV/.egstore` exists (directory).
- Rollback: `rollback --step S09-epic`: removes the link, renames back.
- Dry run: planned, pass. Newest of 646 entries changed 88h 46m earlier. Measured: 645 entries, 125,126,227,544 bytes, 0 symlinks.

### S10-ubisoft: move the Ubisoft Game Launcher folder into the Library
- Preconditions: `quietFor` 10 min on `/Volumes/ExT2/Ubisoft Game Launcher`.
- Operations: `rename` to `H/Library/Ubisoft`; `symlink` `/Volumes/ExT2/Ubisoft Game Launcher` -> `GameHub/Library/Ubisoft`.
- Verify: `H/Library/Ubisoft/UbisoftConnect.exe` exists (file).
- Rollback: `rollback --step S10-ubisoft`: removes the link, renames back.
- Dry run: planned, pass. Measured: 3,978 entries, 103,735,856,492 bytes, 0 symlinks.

### S11-ea-unregistered: move the unregistered top-level EA Games folder into the Library
- Preconditions: `quietFor` 10 min on `/Volumes/ExT2/EA Games`. This is not the registered `GameHub/EA Games`, which stays put.
- Operations: `rename` `/Volumes/ExT2/EA Games` to `H/Library/EA-unregistered`; `symlink` `/Volumes/ExT2/EA Games` -> `GameHub/Library/EA-unregistered`.
- Verify: `H/Library/EA-unregistered/Battlefield 4` exists; `H/EA Games` is still not a symlink; `H/EA Games/BF4` still exists.
- Rollback: `rollback --step S11-ea-unregistered`: removes the link, renames back.
- Dry run: planned, pass. Measured: 745 entries, 34,798,104,629 bytes, 0 symlinks. Note: the survey recorded this folder as 1.14 GB (a stub of Aug 2025); the dry-run measured about 32.4 GiB. The difference is unexplained in the sources; the rename moves the tree whatever its size.

### S12-apps: create the Apps and Build folders and link the bundles
- Preconditions: none.
- Operations: `mkdir` `H/Apps` and `H/Build` (0755); `symlink` `H/Apps/Bundles` -> `../../Bundles`.
- Verify: `H/Apps/Bundles` resolves to a directory.
- Rollback: `rollback --step S12-apps`: removes the link and both directories.
- Dry run: planned, pass. No tree measured.

## 6. Not moved or deferred

| Item | Reason | Future action |
|---|---|---|
| Dev area: `work`, `src`, `toolchains`, `inputs`, `reference`, `downloads` | Other projects pin absolute paths (git worktree `gitdir` files, cargo/cmake build state). Case-only renames to capitalised names cannot keep links. The Wine-driver agent works in `work/winemac-fs`. | Group under a `Dev/` folder when those projects are idle, after `git worktree repair` for `mtld3d-merge` and rebuilding caches. Not scripted yet. |
| EA registry and ini rewrite to `E:\Library\...` | Needs an EA-side move of the games, done by the user. Changing records risks the licence machine hash. | After the user moves the games in the EA app, rewrite `system.reg` keys and `user.downloadinplacedir` (`E:\EA Games\BF4\`) in `user_*.ini`. |
| `SteamGames` re-registration | `SteamGames` holds 6 stale manifests with `C:\Program Files (x86)\Steam\steam.exe`; game files live in `Steam/steamapps/common`. | Done in the Steam UI. |
| `H/Runtimes` on ExT2 | Kept until the runtime app is confirmed. | After the user confirms the runtime app, decide per directory. `hub-0-helpers` and `hub-0-winemacfs` are referenced by `bin/start-ea.sh` (S05), and `hub.json` (S04) references `hub-0.manifest`, so repoint those first. `wine-0010` and `wine-0011` are named test baselines. |
| `Prefix.internal-old-20261010` (BF3Mac 24 GB, NFS2015Mac 17 GB, internal disk) | Protected; old real copies beside the links. | Delete only after the user confirms: `rm -r ~/Library/Application\ Support/BF3Mac/Data/Prefix.internal-old-20261010 ~/Library/Application\ Support/NFS2015Mac/Data/Prefix.internal-old-20261010` |

## 7. Code location

All Hub source lives in `~/Developer/nfs-macos` (branch `bf4-recipe-schema`; no other branches).

Removed from ExT2 after verification (3,945,432 KB freed in total):

| Item | Size |
|---|---|
| `work/wt-hub-b` | 347,656 KB |
| `work/wt-hub-c` | 5,148 KB |
| `work/hub-catalog-src` | 5,024 KB |
| Build dirs `build-hub-b`, `build-hub-c`, `hub-build-app`, `hub-build-catalog`, `hub-build-instances`, `hub-build-main`, `hub-build-tests` | remainder of the total |

Pending:

- `work/wt-hub-a` and `work/build-hub-a`: in use by the Hub Stage-2 lane; its work landed as `85af3ad`.
- `Scratch-bf3-native/macos-app` and `Scratch-bf3-native/mirror`: git content is already on the branch; touched within 30 minutes at the last gate. `Evidence/signing-bf3.json` (165 B, git-ignored, unique) is copied to `~/Developer/nfs-macos/Evidence` first, then both are removed together.

Other projects, sizes only (not touched): `work/mtld3d-merge` 16.3 GB, `work/cargo-target` 14.8 GB, `src/wine` 1.45 GB, `src/wine-arm64` 7.57 GB.

App build output: `/Volumes/ExT2/GameHub/Apps/GameHub.app`, with SwiftPM scratch path `/Volumes/ExT2/GameHub/Build`. The build command is documented in the repo README once added.

## 8. Rollback (whole plan)

- Data store: run `swift run gamehub-cli datastore rollback <plan> --step ID` in reverse order, S12 down to S02.
- S01: the journal sits inside the folder S01 renamed, so undo it by hand. Move `Backups/datastore-20261011` out first, then rename `Backups` back to `backups`.
- Code: `git revert` the commits that implemented this work on `bf4-recipe-schema`.
- Runtime app: delete `~/Applications/GameHub Runtime hub-0.app`. The ExT2 copies in `Runtimes/` are kept.

## 9. User checks after execution

These cannot be verified offline.

1. The EA app lists Battlefield 4, Crysis 3 and the F1 24 download, and Battlefield 3 (start it with `bin/start-ea.sh`).
2. The BF3 wrapper starts.
3. Steam started from `Z:\Volumes\ExT2\GameHub\Library\Steam\steam.exe` keeps its library.
4. GameHub Settings shows both locations (data store and runtime app) as OK.
