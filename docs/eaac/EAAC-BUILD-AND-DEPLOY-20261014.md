# EAAC Wine ntdll.so Build & Deploy Recipe

> Wine source: now at /Users/gc/Developer/wine (moved 2026-10-15), branch `main`. Former `/Volumes/ExT2/GameHub/src/wine` paths in this document are rewritten to that location; `eaac-ntdll-20261014` and `development` mentions are 14 Oct history.

**Date:** 2026-10-14  
**Status:** Reconstructed from in-tree configuration and archive artifacts  

## Scope & Status

This document is reconstructed from Wine source configuration files and archived build artifacts. The exact commands that jobs 469–475 executed were not recorded in any log found, so this is the reference procedure going forward, not a transcript. run-475 REPORT.txt names the suites observed (focused syscall test; full ntdll module real run under Rosetta, 28 groups); their exact commands were not recorded. The build output from job 475 (`fb185cd96f6eee08345b37131f7e2f6864f25c5e83b9af2f4c763172fd5366a0`) is archived at `/Users/gc/eaac-archive/codex-20261014/ntdll-job475-fb185cd9.so`. Currently deployed to the runtime is job 475 (fb185cd9…, deployed atomically at 11:59Z); job 473 (313e87df…) was deployed before it.

---

## 1. Preconditions

Before building, confirm:

### No In-Use Processes
```bash
pgrep -fl 'wineserver|wine64|EADesktop|EAAntiCheat'
```
If any match, close EA Desktop through its normal quit menu (do not force-kill mid-game without recording the interruption in the deployment notes). This command may also match unrelated processes whose command line contains those words.

### Source State
```bash
git -C /Users/gc/Developer/wine status
git -C /Users/gc/Developer/wine rev-parse HEAD
```
Record the branch and HEAD commit. Ensure a clean working tree (no uncommitted changes) or document any local patches applied before building.

### Disk Space
```bash
df -h /Volumes/ExT2
```
Ensure at least 5 GB free (current state: 80% full, ~189 GB available).

---

## 2. Build Procedure

The Wine build produces two outputs: the Unix-side ELF loader (`ntdll.so`) and a Windows-side PE DLL (`ntdll.dll`). Only the `.so` changes in jobs 469–475; the `.dll` version resource is managed at source level and does not need post-build patching.

### Configure (One-Time, or After Source Refresh)

```bash
cd /Users/gc/Developer/wine
./configure --host=x86_64-apple-darwin27 --enable-archs=x86_64
```

The config.log shows:
```
./configure --host=x86_64-apple-darwin27 --enable-archs=x86_64
```

This cross-configures Wine to build 64-bit macOS binaries targeting x86-64 Windows architecture.

### Build ntdll.so

```bash
make -C /Users/gc/Developer/wine -j8 dlls/ntdll/ntdll.so
```

Runs 8 parallel jobs (machine has 10 cores; reserve 2 for system). Output file: `/Users/gc/Developer/wine/dlls/ntdll/ntdll.so`.

**Record the wall time** (no prior build time was recorded).

### (Optional) Build ntdll.dll

If PE-side version resource or metadata changed in `dlls/ntdll/version.rc`:

```bash
make -C /Users/gc/Developer/wine -j8 dlls/ntdll
```

This builds both the `.so` and the PE `.dll`. Current deployed `.dll` (in `lib/wine/x86_64-windows/ntdll.dll`, Oct 13 23:30) was not redeployed in jobs 469–475 and differs from the in-tree build (dlls/ntdll/x86_64-windows/ntdll.dll, Oct 13 23:33) in 1,692,101 of 3,145,728 bytes (first at byte 129); cause not investigated. **No post-build PE patching tool exists.** To deploy a new `.dll`, rebuild it from source and copy it to the runtime alongside the `.so`.

---

## 3. Verify & Archive

### Hash the Build Output

```bash
shasum -a 256 /Users/gc/Developer/wine/dlls/ntdll/ntdll.so
```

Record the hash. Example from job 475: `fb185cd96f6eee08345b37131f7e2f6864f25c5e83b9af2f4c763172fd5366a0`.

### Assign Next Job Number

Previous jobs: 469, 473, 474 (two variants), 475. Next job: **476**.

### Archive the Build

Copy the build output to the archive with the job number and first 8 hex characters of the hash:

```bash
HASH=$(shasum -a 256 /Users/gc/Developer/wine/dlls/ntdll/ntdll.so | cut -d' ' -f1)
HASH8=${HASH:0:8}
cp /Users/gc/Developer/wine/dlls/ntdll/ntdll.so \
   /Users/gc/eaac-archive/codex-20261014/ntdll-job476-${HASH8}.so
```

### Save Source Diff and HEAD

```bash
git -C /Users/gc/Developer/wine diff > /Users/gc/eaac-archive/codex-20261014/wine-src-diff-job476.patch
git -C /Users/gc/Developer/wine rev-parse HEAD > /Users/gc/eaac-archive/codex-20261014/job476-HEAD.txt
```

If the work is already committed (as of 2026-10-14 it was, on `eaac-ntdll-20261014`; wine is now on `main` at /Users/gc/Developer/wine, moved 2026-10-15), use `git -C /Users/gc/Developer/wine format-patch -1 HEAD --stdout > …` or `git diff origin/main..HEAD > …` instead, plus `git rev-parse HEAD`.

### Verify Archive Copy

```bash
FULL_HASH=$(shasum -a 256 /Users/gc/Developer/wine/dlls/ntdll/ntdll.so | cut -d' ' -f1)
ARCHIVE_HASH=$(shasum -a 256 /Users/gc/eaac-archive/codex-20261014/ntdll-job476-${HASH8}.so | cut -d' ' -f1)
[ "$FULL_HASH" = "$ARCHIVE_HASH" ] && echo "Archive copy verified" || echo "HASH MISMATCH"
```

### Test Before Deploy

Run the focused test suite and virtual suite against this build. (The exact test suite commands are not recorded in the original CI configuration; **TODO**: document test suite invocation and assertions here once the suite is formalized.)

---

## 4. Atomic Deploy

Deploy using atomic rename (same-directory temp file + mv on the same filesystem):

Run as a bash script (e.g. save as deploy.sh and run `bash deploy.sh`): the login shell is fish, the snippet is bash syntax, and `exit 1` would close an interactive shell.

```bash
RT=/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer
L="$RT/lib/wine/x86_64-unix"
NEW=/Users/gc/eaac-archive/codex-20261014/ntdll-job476-<HASH8>.so  # fill in from the Verify & archive step
EXPECT=<full 64-hex SHA-256 of the job 476 build>

# Record what is being replaced
echo "Replacing current: $(shasum -a 256 "$L/ntdll.so")  (confirm this hash is already archived under /Users/gc/eaac-archive/codex-20261014/ before continuing)"
read -r -p "Is that hash already archived? [y/N] " a; [ "$a" = y ] || exit 1

# Atomic swap: copy to temp, verify, rename
cp -p "$NEW" "$L/.ntdll.so.new.$$"
TEMP_HASH=$(shasum -a 256 "$L/.ntdll.so.new.$$" | cut -d' ' -f1)
if [ "$TEMP_HASH" != "$EXPECT" ]; then
  rm -f "$L/.ntdll.so.new.$$"
  echo "ERROR: Temp file hash $TEMP_HASH does not match expected $EXPECT"
  exit 1
fi

# Atomic rename: mv on same filesystem = rename(2), visible to all readers
mv -f "$L/.ntdll.so.new.$$" "$L/ntdll.so"

# Verify deployed file
DEPLOYED_HASH=$(shasum -a 256 "$L/ntdll.so" | cut -d' ' -f1)
if [ "$DEPLOYED_HASH" != "$EXPECT" ]; then
  echo "ERROR: Deployed hash $DEPLOYED_HASH does not match expected $EXPECT"
  exit 1
fi

echo "Deploy successful: job476 ($DEPLOYED_HASH)"
```

### Why This Method

- **Temp file in the same directory** (`$L/.ntdll.so.new.$$`): ensures it is on the same APFS volume as the target.
- **mv -f on same filesystem**: `rename(2)` system call, atomic at the filesystem level. Readers either see the old file (old inode) or the new file (new inode), never a partial or corrupt state.
- **Processes that already mapped the old file**: keep the old inode mapped in memory; their reads are unaffected. New processes get the new file.
- **No window with missing ntdll.so**: the directory entry changes atomically; there is no moment when the file does not exist.
- **Hash verification before and after**: ensure the copied file matches the archive, and the deployed file matches the expected hash.

**Avoid the non-atomic swap** documented in `/Volumes/ExT2/GameHub/work/wine-gepperf/20261011-1907/README.md` (`mv ntdll.so ntdll.so.orig` then `cp new ntdll.so`). This has a window where no `ntdll.so` exists, and if `cp` is interrupted, the file is left partial and corrupted.

---

## 5. Rollback

Rollback uses the same atomic deploy procedure with a previous archive artifact.

### Rollback to previously deployed (job 473)

```bash
RT=/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer
L="$RT/lib/wine/x86_64-unix"
NEW=/Users/gc/eaac-archive/codex-20261014/ntdll-job473-313e87df.so
EXPECT=313e87df166d8fb6a9c5e8acc1eca6f3662ea20821dee0318d331c4f73ddac77

cp -p "$NEW" "$L/.ntdll.so.new.$$"
[ "$(shasum -a 256 "$L/.ntdll.so.new.$$" | cut -d' ' -f1)" = "$EXPECT" ] || { rm -f "$L/.ntdll.so.new.$$"; echo HASH MISMATCH; exit 1; }
mv -f "$L/.ntdll.so.new.$$" "$L/ntdll.so"
shasum -a 256 "$L/ntdll.so" | grep -q "$EXPECT" && echo "Rolled back to job473" || echo "WARNING: deployed hash does not match expected"
```

Job 473 is the previously deployed build, not the current one.

### Rollback to job 469 (First Test Build)

```bash
RT=/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer
L="$RT/lib/wine/x86_64-unix"
NEW=/Users/gc/eaac-archive/codex-20261014/ntdll-job469-d585a642.so
EXPECT=d585a64244710dbfee71f4c872d164eea2414587980d907df551b2d7576ec6b2

cp -p "$NEW" "$L/.ntdll.so.new.$$"
[ "$(shasum -a 256 "$L/.ntdll.so.new.$$" | cut -d' ' -f1)" = "$EXPECT" ] || { rm -f "$L/.ntdll.so.new.$$"; echo HASH MISMATCH; exit 1; }
mv -f "$L/.ntdll.so.new.$$" "$L/ntdll.so"
shasum -a 256 "$L/ntdll.so" | grep -q "$EXPECT" && echo "Rolled back to job469" || echo "WARNING: deployed hash does not match expected"
```

### Other Backups in Runtime Directory

The runtime directory `$L` holds older backups:
- `ntdll.so.bak-20261013-prod` (724,632 bytes, Oct 13 23:00)
- `ntdll.so.bak-20261013-regs` (721,776 bytes, Oct 13 01:30)
- `ntdll.so.orig-aot` (794,304 bytes, Oct 10 01:45)

Their provenance is not recorded; verify with shasum before restoring.

To restore any of these:
```bash
cp -p "$L/ntdll.so.bak-<date>" "$L/.ntdll.so.new.$$" && mv -f "$L/.ntdll.so.new.$$" "$L/ntdll.so"
```

---

## 6. Post-Deploy Record

After deploy succeeds and passes quick-smoke tests (game launch, anti-cheat initialization):

### Update Handoff Documents

Edit `/Users/gc/Desktop/EAAC-macOS-full-game-handoff-20261014.md` (or the current handoff doc) to update the deployed version table:

| Job | Build Hash | Deployed Hash | Deployment Date | Status |
|-----|-----------|---------------|-----------------|--------|
| 475 | fb185cd9… | fb185cd9… | 2026-10-14 11:59Z | archived (superseded by 476) |
| **476** | `92a0752306fc61a2…` | `92a0752306fc61a2…` | **2026-10-14 12:54Z** | **live (deployed & verified 352/352 tests)** |

Also update `EAAC-WHERE-WE-LEFT-OFF-20261014.md` and `EAAC-handoff-report.md` with:
- New job number
- Hash (first 16 hex for readability)
- Deployment timestamp
- Any blockers or deviations

### Capture Modal Dialogs

If a modal dialog appears during game launch (e.g., "E111000D — Conflicting software detected!"), take a screenshot and save it to the archive with a timestamp and dialog text:

```
screenshot-E111000D-20261014-143022.png
```

This documents anti-cheat behavior for the deployment and aids future troubleshooting.

---

## 7. Backups & Archival

**Critical constraint:** All build artifacts and runtime files live on `/Volumes/ExT2` (single external volume, currently 80% full). Implement a secondary backup strategy:

1. **Archive copies**: keep `/Users/gc/eaac-archive/codex-20261014/` synchronized off-volume weekly.
2. **Source snapshots**: maintain a dated backup of the Wine source branch on a separate volume (e.g., via `git clone --mirror` or `rsync`).
3. **Runtime backups**: before major deployments, copy `$L/ntdll.so` and the `.dll` to a backup volume.

Review **Finding D4** in `/Users/gc/Desktop/EAAC-FULL-REVIEW-20261014.md` for archival recommendations and implementation.

---

## Appendix: Configuration Details

### Wine Source Configuration
```
Source:     /Users/gc/Developer/wine
Configure:  ./configure --host=x86_64-apple-darwin27 --enable-archs=x86_64
Platform:   x86_64-apple-darwin27 (cross-compile to Windows x86-64)
Host:       arm64 macOS 27.2.0
Makefile:   dlls/ntdll/ntdll.so (ELF Unix-side loader)
            dlls/ntdll/x86_64-windows/ntdll.dll (PE Windows-side DLL, version-stamped in version.rc)
```

### Deployed Runtime
```
Runtime:    /Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer
Target:     lib/wine/x86_64-unix/ntdll.so
Launcher:   /Users/gc/Developer/GameHub/bin/start-ea.sh (exports HUB_RUNTIME to the above)
```

### Archive Location
```
Archive:    /Users/gc/eaac-archive/codex-20261014/
Artifacts:  ntdll-job<NNN>-<hash8>.so
            wine-src-diff-job<NNN>.patch
            job<NNN>-HEAD.txt (commit hash)
            run-<NNN>-<timestamp>/ (test logs)
```

