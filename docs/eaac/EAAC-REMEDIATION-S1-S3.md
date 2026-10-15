> **DO NOT RUN AS WRITTEN**
> This script has known bugs and must be fixed before use:
> - The rollback step records the wrong target.
> - Step S3.4 symlinks to a path that does not exist.
> - `openssl dgst -c SHA256SUMS.txt` does not verify anything (wrong flag/usage).
> - A signature-gate flag set inside a piped loop (`... | while read ...`) is lost once the loop's subshell exits.
> - Scans via `find "$RT"` miss everything once `$RT` is a symlink (find does not follow it by default).
> - The backup-move step can overwrite files when two runtimes share the same name.
> - The runtime build it produces is incomplete.
> - An unguarded `rm -rf "$VERSIONED_RUNTIME"` can delete more than intended if the variable is empty or wrong.
> - Around line ~504 it copies the built binaries from `src/wine-arm64/build`, a path that has been removed.


# EAAC Security Remediation Plan: S1 & S3

**STATUS: DEFERRED — requires user review and approval before any step is executed. Nothing in this document has been applied.**

**Date:** 14 October 2026  
**Source:** EAAC-FULL-REVIEW-20261014.md §5 (S1 HIGH, S3 MEDIUM)  
**Author:** Read-only investigation for remediation planning only.

---

## Current State

### Dosdevices Mappings
*Command: `ls -l /Volumes/ExT2/GameHub/Prefix/dosdevices/`*

```
c: -> ../drive_c                      (Windows C: drive)
e: -> /Volumes/ExT2/GameHub           (entire GameHub volume)
z: -> /Volumes                        (all mounted volumes, including home)
```

**Exposure:** Windows-side processes can read/write the entire GameHub volume via `e:\` and all mounted volumes via `z:\`, including `~/.ssh`, browser profiles, and EA session tokens.

### Code Signing of Runtime Binaries

#### Wine Host Binary
*Command: `codesign -dv --verbose=4 /Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer/bin/wine 2>&1`*

- **Signed:** Yes
- **Authority:** Developer ID Application: Guillaume Coquard (NP94WB3P75)
- **TeamIdentifier:** NP94WB3P75
- **Timestamp:** 10 Oct 2026 at 01:44:27

#### Wine Entitlements
*Command: `codesign -d --entitlements - /Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer/bin/wine 2>&1`*

```
com.apple.security.cs.allow-unsigned-executable-memory     true
com.apple.security.cs.disable-library-validation            true
com.apple.security.device.audio-input                       true
com.apple.security.device.bluetooth                         true
com.apple.security.device.camera                            true
```

**Risk:** `disable-library-validation` + `allow-unsigned-executable-memory` allow arbitrary unsigned `.so` files loaded from the writable runtime directory to execute as the signed host process.

### Runtime Library Signing Status

*Command: `find "$RT" -type f \( -name '*.so' -o -name '*.dylib' \) -print0 | while IFS= read -r -d '' f; do codesign -dv "$f" 2>&1; done`*

**Total inventory:** 44 .so/.dylib files in RT
- **Signed (39):** Team ID NP94WB3P75
- **Unsigned (5):**
  1. lib/wine/x86_64-unix/ntdll.so
  2. lib/wine/x86_64-unix/win32u.so
  3. lib/wine/x86_64-unix/winemac.so
  4. lib/wine/x86_64-unix/winemetal.so
  5. lib/wine/dxgi/dxmt/x86_64-unix/winemetal.so

**Distribution:**
- lib/wine/x86_64-unix/: 29 files (not ~31)
- lib/wine/dxgi/dxmt/: includes unsigned winemetal.so
- Other locations: remaining signed files
- **Critical:** All 5 unsigned files must be signed before removing disable-library-validation in S1.3. Every scan must cover the whole RT including dxgi/dxmt, not only x86_64-unix.

#### X87 Sidecar
*Command: `codesign -dv /Volumes/ExT2/GameHub/Runtimes/hub-0-helpers-fpr/x87sidecar 2>&1`*

- **Signed:** Yes
- **TeamIdentifier:** NP94WB3P75
- **Location:** `/Volumes/ExT2/GameHub/Runtimes/hub-0-helpers-fpr/x87sidecar`

### Runtime and Script Directories (Writable)

*Commands:*
```
ls -ld /Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer
ls -ld /Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer/bin
ls -ld /Volumes/ExT2/GameHub/bin
ls -l /Users/gc/Developer/GameHub/bin/start-ea.sh
```

```
drwxr-xr-x  6 gc staff  192 Oct 12 23:28 /Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer
drwxr-xr-x  5 gc staff  160 Oct 12 23:28 /Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer/bin
drwxr-xr-x  5 gc staff  160 Oct 14 13:57 /Volumes/ExT2/GameHub/bin
-rwxr-xr-x  1 gc staff 3734 Oct 14 13:57 /Users/gc/Developer/GameHub/bin/start-ea.sh
```

All directories and the start-ea.sh script are writable by owner (gc).

### Runtime Environment Overrides

*From `/Users/gc/Developer/GameHub/bin/start-ea.sh`:*

The script launches wine via `env -i`, which clears the environment. Only the following environment variables are passed through from the caller:
- `HUB_RUNTIME` (override runtime directory; defaults to `/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer`)
- `HUB_X87_PATH` (override x87 sidecar path; defaults to `/Volumes/ExT2/GameHub/Runtimes/hub-0-helpers-fpr/x87sidecar`)
- `HUB_X87` (x87 enable/disable flag; passed to wine)
- `HUB_WINEDEBUG` (Wine debug flags; passed to wine)

Additionally, the script **sets** `ROSETTA_X87_PATH` internally:
```bash
X87P="${HUB_X87_PATH:-/Volumes/ExT2/GameHub/Runtimes/hub-0-helpers-fpr/x87sidecar}"
export ROSETTA_X87_PATH="$X87P"
```

Note: A second copy of x87sidecar exists at `$RT/bin/x87sidecar` (if versioned separately).

**Risk:** Environment variables `HUB_RUNTIME`, `HUB_X87_PATH`, `HUB_X87`, and `HUB_WINEDEBUG` can be overridden by the caller and are not verified before use. S1.4 adds verification for HUB_RUNTIME if it differs from the default.

### Backup & Sidecar Files (S3)

*Command: `ls -la /Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer/lib/wine/x86_64-unix/ | grep -E "\.bak|\.orig"`*

```
ntdll.so.bak-20261013-prod     724632  Oct 13 23:00  (most recent backup)
ntdll.so.bak-20261013-regs     721776  Oct 13 01:30
ntdll.so.orig-aot              794304  Oct 10 01:45  (original compiled)
win32u.so.orig-cec4           2070096  Oct 10 01:45
winemac.so.orig                647648  Oct 10 01:45
winemac.so.orig-d261           594840  Oct 11 13:48
winemetal.so.orig-2217       32071920  Oct 10 01:45
```

**Issue:** No matching PE (.dll) / Unix (.so) pairs archived; no checksum file; no immutability markers; unlabeled backup accumulation; in-place edits risk SIGBUS on mapped libraries.

---

## Remediation Steps

### Preconditions (All Steps)

Before executing **any** S1 or S3 step:

1. **Free-space check:** Ensure enough disk space for tarball backup (~2× runtime size)
   ```bash
   du -sh /Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer/
   df -h /Volumes/ExT2/
   ```
   The tarball will require ~2× the runtime size; abort if < 3× available.

2. Quit EA Desktop completely
3. Kill the Wine server: `WINEPREFIX=/Volumes/ExT2/GameHub/Prefix wineserver -k`
4. Confirm no process maps the runtime directory: `lsof +D /Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer`
5. Create archive directory: `mkdir -p ~/eaac-archive && chmod 700 ~/eaac-archive`
6. Save snapshots:
   - Dosdevices listing: `ls -la /Volumes/ExT2/GameHub/Prefix/dosdevices/ > ~/eaac-archive/dosdevices-snapshot-20261014.txt`
   - Wine entitlements plist: `codesign -d --entitlements - /Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer/bin/wine > ~/eaac-archive/wine-entitlements-20261014.plist 2>&1`
   - Runtime tarball: `tar -C /Volumes/ExT2/GameHub/Runtimes -czf ~/eaac-archive/runtime-backup-20261014.tar.gz hub-0-winemacfs-dxmtrtv-noWineVer/`
   - Verify snapshots: `ls -la ~/eaac-archive/`

---

## S1: Narrow Guest Writability & Add Signature Verification

### S1.1 — Narrow dosdevices Mappings

**Preconditions:**
- All preconditions from § Preconditions above completed
- EA Desktop not running, wineserver killed, runtime not in use

**Steps:**

1. **Enumerate the actual e:\ and z:\ paths from the registry and EA config:**
   ```bash
   # Search registry and config files for e:\ and z:\ paths
   grep -r "e:\\\\" /Volumes/ExT2/GameHub/Prefix/system.reg /Volumes/ExT2/GameHub/Prefix/user.reg \
     /Volumes/ExT2/GameHub/Prefix/drive_c/*/AppData/Local/Electronic\ Arts/*/config* 2>/dev/null \
     | grep -i "games\|install\|library" | sort -u
   
   # List actual top-level directories under GameHub
   ls /Volumes/ExT2/GameHub
   ```
   
   Expected findings: e:\ paths (e.g., `e:\EA Games\...`, `e:\Library\...`) and z:\ paths that specify which volumes are needed. The actual top-level dirs include: "EA Games", "Library", "Apps" (or similar).

2. **Determine which volumes and subdirectories are required:**
   - For e:\ — it currently maps to the entire `/Volumes/ExT2/GameHub`; identify which subdirectories (EA Games, Library, Apps, etc.) the registry actually requires
   - For z:\ — it currently maps to `/Volumes` (all mounted volumes); determine if a narrower scope (e.g., just the ExT2 volume) is acceptable

3. **Update dosdevices symlinks to map only the required paths:**
   ```bash
   cd /Volumes/ExT2/GameHub/Prefix/dosdevices
   
   # Update e: mapping (example: if only EA Games and Library are needed)
   rm /Volumes/ExT2/GameHub/Prefix/dosdevices/e:
   ln -s /Volumes/ExT2/GameHub e:  # Still whole volume — adjust after testing
   
   # Update z: mapping (example: narrow to ExT2 only, or make it read-only)
   rm /Volumes/ExT2/GameHub/Prefix/dosdevices/z:
   ln -s /Volumes/ExT2 z:  # Narrower than all volumes, but still allows ExT2 access
   # OR: point it at an empty, read-only staging directory
   mkdir -p /Volumes/ExT2/GameHub/Prefix/dosdevices-z
   chmod 555 /Volumes/ExT2/GameHub/Prefix/dosdevices-z
   ln -s /Volumes/ExT2/GameHub/Prefix/dosdevices-z z:
   ```
   
   **Important:** EA's registered paths (e.g., e:\EA Games\...) must keep resolving. If narrowing e:, map it to a directory that contains the required subdirectories, or update EA's registry entries to point to the new paths.

4. **Flag for recurrence:** After every `wineboot` or prefix update, inspect dosdevices and verify z: has not been re-created by Wine (it was modified on Oct 14 00:30, suggesting something recreates it — investigate):
   ```bash
   ls -la /Volumes/ExT2/GameHub/Prefix/dosdevices/ | grep "^l"
   ```

**Verification:**
- EA Desktop starts
- Login succeeds
- Library list appears
- Game install folder is accessible

**Rollback:**
Restore from dosdevices snapshot saved in preconditions:
```bash
: "${SNAPSHOT:?snapshot path not set}"
while IFS= read -r line; do
  link=$(echo "$line" | awk '{print $NF}' | cut -d' ' -f1)
  target=$(echo "$line" | awk '{print $NF}' | sed 's/.*-> //')
  ln -sf "$target" "/Volumes/ExT2/GameHub/Prefix/dosdevices/$link" 2>/dev/null || true
done < ~/eaac-archive/dosdevices-snapshot-20261014.txt
```

Alternatively, restore from precondition tarball and re-extract dosdevices.

**Risk to Current Launch:**
- HIGH: Incorrect paths or overly narrow mapping will break EA Desktop library access or the game's asset loading. Test the library and game install path resolution before and after.
- MEDIUM: dosdevices/z: appears to be recreated by Wine (modified Oct 14 00:30); investigate why before relying on its removal as a permanent protection.

---

### S1.2 — Make Runtime, start-ea.sh, and X87 Sidecar Read-Only (Post-Deploy)

**Preconditions:**
- S1.1 complete (narrower dosdevices)
- EA Desktop not running
- S3 (versioned deploy process) is fully implemented and tested before this step is enforced (do not enforce read-only before deploy automation is ready)

**Steps:**

1. After every successful deploy/symlink flip (see S3.2), make the active runtime read-only:
   ```bash
   chmod -R a-w /Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer/
   chmod -R a-w /Volumes/ExT2/GameHub/Runtimes/hub-0-helpers-fpr/x87sidecar
   chmod 555 /Users/gc/Developer/GameHub/bin/start-ea.sh
   ```
   
   Note: The x87sidecar may exist in two locations — make both read-only:
   - `/Volumes/ExT2/GameHub/Runtimes/hub-0-helpers-fpr/x87sidecar`
   - `$RT/bin/x87sidecar` (if versioned separately)

2. Confirm permissions:
   ```bash
   ls -ld /Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer/
   ls -ld /Volumes/ExT2/GameHub/Runtimes/hub-0-helpers-fpr/x87sidecar
   ls -l /Users/gc/Developer/GameHub/bin/start-ea.sh
   ```
   Expected: no writable bits for group or other.

**Verification:**
- EA Desktop launches and runs
- No "Permission denied" errors in logs

**Rollback:**
Restore writable permissions on both locations:
```bash
chmod -R u+w /Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer/
chmod u+w /Volumes/ExT2/GameHub/Runtimes/hub-0-helpers-fpr/x87sidecar
[ -f /Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer/bin/x87sidecar ] && \
  chmod u+w /Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer/bin/x87sidecar
chmod 755 /Users/gc/Developer/GameHub/bin/start-ea.sh
```

**Risk to Current Launch:**
- MEDIUM: If made read-only before deploy automation in S3 is ready, any tool that writes patches or updates will fail. Implement and test S3 thoroughly before enforcing read-only.

---

### S1.3 — Sign All Runtime Libraries and Re-Sign Wine Host Without disable-library-validation

**Preconditions:**
- S1.1 complete
- Team ID certificate available locally (the same `Developer ID Application: Guillaume Coquard (NP94WB3P75)` used to sign wine and existing .so files)
- EA Desktop not running, runtime not in use
- **MUST test on a COPY of the runtime and prefix first** — removing disable-library-validation is a breaking change if any loaded dylib is not signed by Team ID NP94WB3P75

**Critical Context:**

Removing `com.apple.security.cs.disable-library-validation` means **every** Mach-O image the wine process loads must be signed by the same Team ID (NP94WB3P75) **or** be Apple platform binaries. This includes:
- All .so and .dylib files in the runtime directory
- Any dylibs loaded from outside the runtime (e.g., Homebrew packages: freetype, gnutls, MoltenVK, OpenSSL, libusb, etc.)
- System frameworks and Apple binaries (these are exempt)

If Wine loads an unsigned or differently-signed dylib, the process will be killed by the kernel.

**Signing Steps:**

1. **Discovery: identify what the running wine process loads**
   Before signing, on a test system, capture what dylibs are loaded:
   ```bash
   # Method 1: Launch wine and capture with vmmap
   /path/to/wine cmd.exe &
   PID=$!
   vmmap "$PID" | grep -E '\.(so|dylib)' | tee ~/wine-dylib-scan.txt
   kill $PID
   
   # Method 2: Or use DYLD_PRINT_LIBRARIES on a test launch
   DYLD_PRINT_LIBRARIES=1 /path/to/wine cmd.exe 2>&1 | grep -E 'dylib|\.so' | tee ~/wine-dylib-scan.txt
   ```
   Review the output; note any third-party dylibs (Homebrew, /usr/local/lib, etc.) and ensure they will be signed with Team ID NP94WB3P75 or removed before removal of disable-library-validation.

2. **Sign all 5 unsigned .so files in the runtime:**
   ```bash
   RT="/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer"
   
   find "$RT" -type f \( -name '*.so' -o -name '*.dylib' \) -print0 |
   while IFS= read -r -d '' f; do
     tid=$(codesign -dv "$f" 2>&1 | sed -n 's/^TeamIdentifier=//p')
     if [ "$tid" != "NP94WB3P75" ]; then
       codesign --force --options runtime --timestamp -s "Developer ID Application: Guillaume Coquard (NP94WB3P75)" "$f"
     fi
   done
   ```
   This will sign the 5 unsigned files and re-sign any with the wrong Team ID. It scans the whole RT including dxgi/dxmt.

3. **Re-sign wine binary WITHOUT disable-library-validation:**
   ```bash
   # Extract current entitlements
   codesign -d --entitlements :wine-entitlements.plist \
     "$RT/bin/wine"
   
   # Edit wine-entitlements.plist: DELETE these lines:
   #   <key>com.apple.security.cs.disable-library-validation</key>
   #   <true/>
   
   # Re-sign with modified entitlements
   codesign --force --options runtime --timestamp \
     -s "Developer ID Application: Guillaume Coquard (NP94WB3P75)" \
     --entitlements wine-entitlements.plist \
     "$RT/bin/wine"
   ```

4. **Entitlements decision (USER INPUT REQUIRED):**
   - **allow-unsigned-executable-memory:** KEEP. Wine/x86 translation on Rosetta likely requires this. Test CEF/game launch before removal.
   - **camera/audio-input/Bluetooth:** REMOVE unless voice chat or game controller features are confirmed needed. Query EA and user before removal.

**Verification:**
```bash
RT="/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer"

# Verify all .so and .dylib files are signed with Team ID NP94WB3P75
find "$RT" -type f \( -name "*.so" -o -name "*.dylib" \) -print0 |
while IFS= read -r -d '' f; do
  tid=$(codesign -dv "$f" 2>&1 | sed -n 's/^TeamIdentifier=//p')
  if [ "$tid" = "NP94WB3P75" ]; then
    echo "✓ $f"
  else
    echo "✗ $f (Team ID: $tid)"
  fi
done

# Verify wine host has library-validation removed
codesign -d --entitlements - "$RT/bin/wine" 2>&1 | grep -c "disable-library-validation"  # should print 0
```

**Rollback:**
Restore runtime from precondition tarball (primary rollback):
```bash
: "${RT:?RT not set}"
tar -xzf ~/eaac-archive/runtime-backup-20261014.tar.gz -C /Volumes/ExT2/GameHub/Runtimes/ --strip-components=1 -C "$RT"
```

**Risk to Current Launch:**
- HIGH: If disable-library-validation removal breaks Wine's ability to load a required dylib, EA Desktop will be killed by the kernel. **Testing on a copy of the runtime and prefix is mandatory.** Do not apply to the live prefix without prior verification.
- MEDIUM: Team ID certificate availability—if the key is not locally available, re-signing is impossible without obtaining it from the key manager.

---

### S1.4 — Launch Gate: Verify Signatures Before exec

**Preconditions:**
- S1.3 complete (all libraries signed)
- EA Desktop not running

**Steps:**

1. Update start-ea.sh to verify signatures before the final exec. Add this verification block before the wine exec line (around line 78):

   ```bash
   # Signature verification gate (S1.4)
   HUB_SIGCHECK="${HUB_SIGCHECK:-warn}"  # User can override: HUB_SIGCHECK=enforce to hard-fail
   
   _hub_verify_sig() {
       local file="$1" team_id="NP94WB3P75"
       local tid
       
       # Extract Team ID
       tid=$(codesign -dv "$file" 2>&1 | sed -n 's/^TeamIdentifier=//p')
       
       # Verify signature is valid
       if ! codesign --verify --strict "$file" >/dev/null 2>&1; then
           return 1
       fi
       
       # Check Team ID
       if [ "$tid" != "$team_id" ]; then
           return 1
       fi
       
       return 0
   }
   
   # Gate 1: Verify wine binary
   if ! _hub_verify_sig "$RT/bin/wine"; then
       printf '%s\n' "start-ea.sh: WARNING: wine binary signature invalid or wrong Team ID" >&2
       if [ "$HUB_SIGCHECK" = "enforce" ]; then
           printf '%s\n' "start-ea.sh: ERROR: signature check enforced; aborting" >&2
           exit 1
       fi
   else
       printf '%s\n' "start-ea.sh: wine signature verified" >&2
   fi
   
   # Gate 2: Verify x87sidecar
   if [ -f "$RT/bin/x87sidecar" ]; then
       if ! _hub_verify_sig "$RT/bin/x87sidecar"; then
           printf '%s\n' "start-ea.sh: WARNING: x87sidecar signature invalid or wrong Team ID" >&2
           if [ "$HUB_SIGCHECK" = "enforce" ]; then
               printf '%s\n' "start-ea.sh: ERROR: x87sidecar check enforced; aborting" >&2
               exit 1
           fi
       fi
   fi
   
   # Gate 3: Verify all runtime libraries
   _rt_ok=0
   find "$RT" -type f \( -name '*.so' -o -name '*.dylib' \) -print0 |
   while IFS= read -r -d '' lib; do
       if ! _hub_verify_sig "$lib"; then
           printf '%s\n' "start-ea.sh: WARNING: library unsigned or wrong Team ID: $lib" >&2
           _rt_ok=1
       fi
   done
   
   if [ "$_rt_ok" -ne 0 ]; then
       if [ "$HUB_SIGCHECK" = "enforce" ]; then
           printf '%s\n' "start-ea.sh: ERROR: runtime library check enforced; aborting" >&2
           exit 1
       fi
   else
       printf '%s\n' "start-ea.sh: all runtime libraries verified" >&2
   fi
   ```

2. **Environment override:** Note that `start-ea.sh` runs `env -i`, so only `HUB_RUNTIME`, `HUB_X87_PATH`, `HUB_X87`, and `HUB_WINEDEBUG` are passed from the caller. `ROSETTA_X87_PATH` is set by the script itself. If `HUB_RUNTIME` is overridden, the above checks still apply to the override path.

3. **User decision required:** Set `HUB_SIGCHECK` mode:
   - **warn** (default): Log warnings but continue if a signature check fails
   - **enforce**: Exit with error if any signature check fails
   - **Recommended:** Start with warn-only, upgrade to enforce after 7+ days of stable launches.

**Verification:**
- EA Desktop launches; signature verification messages appear in stderr/log
- With HUB_SIGCHECK=warn: launch succeeds even with warnings
- With HUB_SIGCHECK=enforce: launch succeeds only if all signatures are valid

**Rollback:**
Remove the signature verification block from start-ea.sh.

**Risk to Current Launch:**
- MEDIUM: If a correctly-signed library is not recognized (timestamp issue, etc.), HUB_SIGCHECK=enforce will block launch. Start with warn mode.

---

## S3: Versioned, Immutable Runtimes with Atomic Symlink Switching

### S3.1 — Versioned Immutable Runtime Directories with Manifests

**Preconditions:**
- S1.1 complete (narrower dosdevices)
- S1.3 complete (all libraries signed)
- A build/deploy job or git commit SHA available to name the runtime version

**Steps:**

1. Create a versioned runtime directory structure:
   ```bash
   # Create an archive directory for released runtimes
   RUNTIME_ARCHIVE="/Volumes/ExT2/GameHub/Runtimes"
   GIT_SHA=$(cd /Users/gc/Developer/wine && git rev-parse HEAD | cut -c1-8)
   JOB_NUM=475  # from the deploy job number
   VERSION="${GIT_SHA}-job${JOB_NUM}"
   
   VERSIONED_RUNTIME="$RUNTIME_ARCHIVE/hub-runtime-$VERSION"
   mkdir -p "$VERSIONED_RUNTIME/lib/wine/x86_64-unix"
   ```

2. Build and copy both PE and Unix halves into the versioned directory:
   ```bash
   # This step presupposes a build process that produces both:
   # - Wine .so (Unix half): from src/wine build output
   # - Corresponding .dll (PE half): from the build or pre-compiled distribution
   
   # Copy runtime binaries (wine, wineserver, x87sidecar)
   cp /Volumes/ExT2/GameHub/src/wine-arm64/build/loader/wine "$VERSIONED_RUNTIME/bin/"
   cp /Volumes/ExT2/GameHub/src/wine-arm64/build/tools/wine/wineserver "$VERSIONED_RUNTIME/bin/"
   cp /Volumes/ExT2/GameHub/Runtimes/hub-0-helpers-fpr/x87sidecar "$VERSIONED_RUNTIME/bin/"
   
   # Copy signed libraries
   cp -r /Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer/lib/wine/x86_64-unix/*.so \
     "$VERSIONED_RUNTIME/lib/wine/x86_64-unix/"
   ```

3. Create a SHA256SUMS manifest:
   ```bash
   cd "$VERSIONED_RUNTIME"
   find . -type f \( -name "*.so" -o -name "*.dylib" -o -name wine -o -name wineserver -o -name x87sidecar \) \
     -exec openssl dgst -sha256 {} \; > SHA256SUMS.txt
   # Alternatively, if openssl is unavailable, use a pure-bash loop or note as UNVERIFIED
   ```

4. Sign the manifest (optional, but recommended):
   ```bash
   # If a detached signature is desired:
   codesign -s "Developer ID Application: Guillaume Coquard (NP94WB3P75)" \
     --detached "$VERSIONED_RUNTIME/SHA256SUMS.txt" \
     "$VERSIONED_RUNTIME/SHA256SUMS.txt.sig"
   ```

5. Make the versioned directory read-only:
   ```bash
   chmod -R a-w "$VERSIONED_RUNTIME"
   chmod 444 "$VERSIONED_RUNTIME/SHA256SUMS.txt"
   ```

**Verification:**
```bash
ls -la "$VERSIONED_RUNTIME"
cat "$VERSIONED_RUNTIME/SHA256SUMS.txt" | head -5
```

**Rollback:**
Delete the versioned runtime if corruption is detected:
```bash
rm -rf "$VERSIONED_RUNTIME"
```

**Risk to Current Launch:**
- LOW: Creating a new versioned directory does not affect the live runtime (yet). A build-time error in copying files is the main risk.

---

### S3.2 — Atomic Symlink Switching

**Current State & Migration:**

The live path `/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer` is currently a **real directory**, not a symlink. Before atomic symlink flips can work, perform a one-time migration:

```bash
# (with EA/wine stopped, no process using the runtime)
RT="/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer"
SHA="<git-sha-or-job-id>"  # e.g., abc1def2
JOB="<job-number>"         # e.g., 475

# Step 1: Rename the live directory to versioned
mv "$RT" "/Volumes/ExT2/GameHub/Runtimes/hub-runtime-$SHA-job$JOB"

# Step 2: Create symlink pointing to the versioned directory
ln -s "hub-runtime-$SHA-job$JOB" "$RT"

# Note: Brief non-atomic gap between steps 1 and 2. Acceptable only while nothing is running.
```

After this one-time migration, the live path becomes a symlink, and future flips are atomic.

**Preconditions:**
- S3.1 complete (versioned runtime ready, SHA256SUMS verified)
- No process is currently using the old runtime (lsof check from preconditions)

**Steps (for all flips after initial migration):**

1. Verify checksums before switching:
   ```bash
   VERSIONED_RUNTIME="/Volumes/ExT2/GameHub/Runtimes/hub-runtime-$NEW_VERSION"
   cd "$VERSIONED_RUNTIME"
   
   # Verify all files match the manifest
   openssl dgst -sha256 -c SHA256SUMS.txt && echo "Checksum verification PASSED" || {
       echo "Checksum verification FAILED"
       exit 1
   }
   ```
   *Note: UNVERIFIED if openssl dgst is not available; fall back to manual spot-checks.*

2. Create the new symlink atomically:
   ```bash
   cd /Volumes/ExT2/GameHub/Runtimes
   
   LIVE_LINK="hub-0-winemacfs-dxmtrtv-noWineVer"
   NEW_TARGET="hub-runtime-$NEW_VERSION"
   
   # Create new symlink with a temporary name
   ln -s "$NEW_TARGET" "$LIVE_LINK.new"
   
   # Atomic rename (POSIX rename(2) uses a single atomic operation)
   python3 -c 'import os,sys; os.replace(sys.argv[1], sys.argv[2])' "$LIVE_LINK.new" "$LIVE_LINK"
   
   # Save the previous target for rollback
   echo "$NEW_TARGET" > "$LIVE_LINK.prev-target"
   
   # Verify the switch
   ls -la "$LIVE_LINK"
   readlink "$LIVE_LINK"
   ```

3. Do the same for the x87 sidecar if versioned separately (rare case):
   ```bash
   # Only if x87 is versioned; otherwise skip
   # LIVE_X87="/Volumes/ExT2/GameHub/Runtimes/hub-0-helpers-fpr"
   # ln -s "hub-x87-$NEW_VERSION" "$LIVE_X87.new"
   # python3 -c 'import os,sys; os.replace(sys.argv[1], sys.argv[2])' "$LIVE_X87.new" "$LIVE_X87"
   ```

**Verification:**
- Symlink points to the new versioned directory
- EA Desktop launches successfully with the new runtime
- Logs contain no "file not found" errors for .so files

**Rollback (atomic flip-back):**
```bash
LIVE_LINK="/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer"
PREV_TARGET=$(cat "$LIVE_LINK.prev-target")

# Flip back to the previous target
ln -s "$PREV_TARGET" "$LIVE_LINK.new"
python3 -c 'import os,sys; os.replace(sys.argv[1], sys.argv[2])' "$LIVE_LINK.new" "$LIVE_LINK"
```

**Risk to Current Launch:**
- HIGH if the atomic switch fails mid-operation: the symlink could point to a non-existent directory, and EA Desktop will fail to launch. Test the migration and flip procedure in a staging prefix first.

---

### S3.3 — Migrate Existing Backups into Versioned History

**Preconditions:**
- S3.1 complete (versioned scheme established)
- S3.2 complete (symlink switching practiced)

**Current Backup Inventory:**

There are 18 .bak and .orig files across the runtime:

```bash
find "$RT" \( -name '*.bak*' -o -name '*.orig*' \) -type f
```

Expected locations:
- 7 files beside ntdll.so (x86_64-unix)
- ntdll.dll.bak-20261013 and ntdll.dll.bak-20261013-prod (x86_64-windows)
- ntdll.dll.bak-20261013 (i386-windows)
- winemac.drv.orig (x86_64-unix or elsewhere)
- dxgi/dxmt/winemetal.so.orig-2217
- 6 × d3d11.dll.orig-* (dxgi/dxmt)

**Steps:**

1. Identify the hash of the currently-live ntdll.so and PE files (note from D1 in the review):
   ```bash
   # Compute hash of live Unix library
   shasum -a 256 /Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer/lib/wine/x86_64-unix/ntdll.so
   
   # Compute hashes of live PE files
   shasum -a 256 /Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer/lib/wine/x86_64-windows/ntdll.dll
   shasum -a 256 /Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer/lib/wine/dxgi/dxmt/d3d11.dll
   
   # Record these hashes for cross-referencing to D1 and for future audit
   ```

2. Migrate existing `.bak-*` and `.orig*` files into labeled versioned directories:
   ```bash
   # Create a "backups" directory
   RT="/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer"
   BACKUP_DIR="/Volumes/ExT2/GameHub/Runtimes/hub-backups"
   mkdir -p "$BACKUP_DIR"
   
   # Move all .bak* and .orig* files with descriptive names
   find "$RT" \( -name '*.bak*' -o -name '*.orig*' \) -type f | while read f; do
     basename=$(basename "$f")
     mv "$f" "$BACKUP_DIR/$basename"
   done
   ```

3. Create a README documenting the mapping:
   ```bash
   cat > "$BACKUP_DIR/README.txt" << 'EOF'
   Archived library backups from runtime deployments prior to versioned scheme.
   These files represent in-place edits and snapshots taken at various points.
   They are NOT matched pairs and do not represent complete release versions.
   
   Unix library backups (x86_64-unix/):
   - ntdll.so.bak-20261013-prod, ntdll.so.bak-20261013-regs, ntdll.so.orig-aot, etc.
   
   PE (.dll) backups (x86_64-windows, i386-windows, dxgi/dxmt):
   - ntdll.dll.bak-20261013, ntdll.dll.bak-20261013-prod
   - d3d11.dll.orig-*, winemetal.so.orig-*
   
   Note: PE backups exist but are not recorded as matched pairs to their Unix counterparts.
   
   Cross-reference to EAAC-FULL-REVIEW-20261014.md § D1 for hashes of live files.
   EOF
   ```

4. Create a manifest linking backup dates to deployed versions (if possible):
   ```bash
   cat > "$BACKUP_DIR/MANIFEST.txt" << 'EOF'
   Backup Manifest (for audit and rollback reference)
   
   Date        | File                              | Size    | Purpose
   ------------|-----------------------------------|---------|-------------------
   20261013    | ntdll.so.bak-20261013-prod        | 724632  | Daily snapshot
   20261013    | ntdll.so.bak-20261013-regs        | 721776  | Post-registry-edit
   20261010    | ntdll.so.orig-aot                 | 794304  | Original AOT build
   20261010    | winemetal.so.orig-2217            | 32MB    | dxgi/dxmt original
   ...
   EOF
   ```

**Verification:**
- All `.bak*` and `.orig*` files removed from lib/wine/x86_64-unix and other source locations
- README and MANIFEST exist in hub-backups/
- Checksums of live files recorded

**Rollback:**
Move files back to their original locations (restore based on file names):
```bash
# e.g., restore ntdll.so.bak-20261013-prod
BACKUP_DIR="/Volumes/ExT2/GameHub/Runtimes/hub-backups"
RT="/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer"
mv "$BACKUP_DIR/ntdll.so.bak-20261013-prod" "$RT/lib/wine/x86_64-unix/ntdll.so.bak-20261013-prod"
```

**Risk to Current Launch:**
- LOW: Moving historical backups does not affect the live runtime. However, ensure all files are moved (not deleted) so they can be restored for audit or recovery.

---

### S3.4 — Deploy Process Rule: Never Edit a Runtime In Place While Mapped

**Preconditions:**
- S3.1, S3.2, S3.3 complete (versioned infrastructure in place)

**Rule:**

No future patch or update shall overwrite a runtime file in place. All deploys follow this procedure:

1. **Build Phase:** Produce a new versioned runtime directory (S3.1) with all changes.
2. **Verify Phase:** Generate SHA256SUMS and verify checksums (S3.2, step 1).
3. **Atomic Switch Phase:** Use atomic symlink replacement to point `hub-0-winemacfs-dxmtrtv-noWineVer` at the new versioned dir (S3.2).
4. **Rollback:** If a post-launch issue is discovered, flip the symlink back to the previous versioned dir using the saved .prev-target file.

**Codify in a Deploy Script:**

```bash
#!/bin/bash
# deploy-runtime.sh - versioned, atomic runtime deployment

set -e

NEW_VERSION="$1"  # e.g., "abc1def2-job475"
RUNTIME_DIR="/Volumes/ExT2/GameHub/Runtimes"
RT="$RUNTIME_DIR/hub-0-winemacfs-dxmtrtv-noWineVer"

# Preconditions
echo "Checking preconditions..."

# Guard: check if runtime is in use
if lsof +D "$RT" >/dev/null 2>&1; then
    echo "ERROR: runtime in use; aborting" >&2
    exit 1
fi

# Verify versioned runtime exists and checksums match
VERSIONED="$RUNTIME_DIR/hub-runtime-$NEW_VERSION"
[ -d "$VERSIONED" ] || { echo "ERROR: Versioned runtime not found: $VERSIONED"; exit 1; }
( cd "$VERSIONED" && openssl dgst -sha256 -c SHA256SUMS.txt ) || {
    echo "ERROR: Checksum verification failed for $VERSIONED"
    exit 1
}

# Atomic switch
echo "Switching runtime to $NEW_VERSION..."
ln -s "$NEW_VERSION" "$RT.new"
python3 -c 'import os,sys; os.replace(sys.argv[1], sys.argv[2])' "$RT.new" "$RT"
echo "$(readlink "$RT")" > "$RT.prev-target"

echo "Deployment complete."
echo "Test EA Desktop launch, then confirm stable (or run: deploy-runtime.sh --rollback)"
```

**Verification:**
Deploy script runs without error; EA Desktop launches; SIGBUS/SIGSEGV errors do not appear in crash logs.

**Rollback:**
Flip symlink back using the saved previous target:
```bash
RUNTIME_DIR="/Volumes/ExT2/GameHub/Runtimes"
RT="$RUNTIME_DIR/hub-0-winemacfs-dxmtrtv-noWineVer"
PREV_TARGET=$(cat "$RT.prev-target")

ln -s "$PREV_TARGET" "$RT.new"
python3 -c 'import os,sys; os.replace(sys.argv[1], sys.argv[2])' "$RT.new" "$RT"
echo "Rolled back to: $PREV_TARGET"
```

**Risk to Current Launch:**
- MEDIUM: If the deploy script is not tested before first use, a mistake in the atomic flip could leave the symlink broken. Always test in a staging directory first before deploying to the live runtime.

---

## Safety Guards & Best Practices

The following safety practices must be applied across all steps:

1. **Variable guards:** Before any destructive operation, guard variables with `: "${VAR:?unset}"` to catch typos:
   ```bash
   : "${RT:?RT not set}"
   : "${BACKUP_DIR:?BACKUP_DIR not set}"
   rm -rf "$RT"  # Now safe: $RT will not expand if unset
   ```

2. **Dosdevices rollback:** S1.1 rollback must restore from the saved dosdevices snapshot, not hardcoded commands:
   ```bash
   # CORRECT: restore from snapshot
   while IFS= read -r line; do
     link=$(echo "$line" | awk '{print $(NF-2)}')
     target=$(echo "$line" | awk '{print $NF}')
     ln -sf "$target" "/Volumes/ExT2/GameHub/Prefix/dosdevices/$link"
   done < ~/eaac-archive/dosdevices-snapshot-20261014.txt
   
   # WRONG: hardcoded rm
   rm /Volumes/ExT2/GameHub/Prefix/dosdevices/e: /Volumes/ExT2/GameHub/Prefix/dosdevices/z:
   ```

3. **Z: investigation:** dosdevices/z: was modified on Oct 14 00:30, suggesting something recreates it. Before relying on its removal as a protection measure, investigate why Wine or another process is recreating z:.

4. **Test on a copy:** Before S1.3 (removing disable-library-validation) on the live prefix, test the signing changes and wine launch on a copy of both the runtime and prefix.

---

## Decisions Required from the User

Before executing any step:

1. **Team ID Certificate (S1.3):**
   - [ ] Is the Developer ID Application certificate (`NP94WB3P75` — Guillaume Coquard) available locally on this Mac?
   - [ ] If the certificate is on a different Mac or in a key manager, can it be imported before signing?

2. **Narrow dosdevices Mapping (S1.1):**
   - [ ] Which exact directories on GameHub does EA Desktop and the target game require? (Run the grep command in S1.1 to determine.)
   - [ ] Is a test with a narrower `e:` mapping acceptable, or must the whole volume remain accessible?

3. **Library Validation Trade-off (S1.3):**
   - [ ] Is Wine/x86 translation on Rosetta confirmed to require `allow-unsigned-executable-memory`?
   - [ ] Can camera, audio-input, and Bluetooth entitlements be removed, or are they used by the game?

4. **Launch Gate Mode (S1.4):**
   - [ ] Warn-only (print warning, continue on signature failure) or hard-fail (exit on signature failure)?
   - [ ] Recommended: Start warn-only, upgrade to hard-fail after confirming stability.

5. **Downtime (S3.2, S3.4):**
   - [ ] Is it acceptable for EA Desktop to be offline for ~30 minutes during the initial symlink-switching test?

---

## Suggested Execution Order & Dependencies

```
┌─────────────────────────────────────────────────────────────────────────┐
│ Preconditions (all steps)                                               │
│  - Quit EA Desktop                                                      │
│  - Kill wineserver                                                      │
│  - Create archive directory & snapshots                                 │
└─────────────────────────────────────────────────────────────────────────┘
                              ↓
        ┌─────────────────────────────────────────┐
        │ S1.1 — Narrow dosdevices (no blocking)  │
        └─────────────────────────────────────────┘
                        ↓
      ┌──────────────────────────────────────────────┐
      │ S1.3 — Sign all .so and re-sign wine        │
      │         (requires Team ID cert)              │
      └──────────────────────────────────────────────┘
                        ↓
   ┌──────────────────────────────────────────────────────┐
   │ S1.4 — Add launch gate to start-ea.sh (warn-only)   │
   │        Test EA Desktop launch (no hard-fail yet)    │
   └──────────────────────────────────────────────────────┘
                        ↓
   ┌──────────────────────────────────────────────────────┐
   │ S3.1 — Build versioned runtime directories          │
   │ S3.2 — Test atomic symlink switch in staging dir   │
   │ S3.3 — Migrate existing backups to archive         │
   │ S3.4 — Write & test deploy-runtime.sh script       │
   └──────────────────────────────────────────────────────┘
                        ↓
   ┌──────────────────────────────────────────────────────┐
   │ S1.2 — Make runtime read-only (after S3 ready)      │
   │ (Now that deploy automation replaces files, not edit) │
   └──────────────────────────────────────────────────────┘
                        ↓
   ┌──────────────────────────────────────────────────────┐
   │ Upgrade S1.4 launch gate to hard-fail mode (if stable)
   │ after confirming 7+ days of stable launches         │
   └──────────────────────────────────────────────────────┘
```

**Parallel execution:** S1.1 can run in parallel with S1.3 and S3 (different files). S1.4 must wait for S1.3 to complete.

---

## Out of Scope

The following are explicitly **not** addressed by this plan:

- **Wine Source Tree Changes (dlls/ntdll/*):** The C1–C10 correctness and memory-safety findings require upstream Wine commits; they are listed in the EAAC-FULL-REVIEW and tracked separately.
- **D3 — Wine Identity Masking Decision:** The 257-stub rewriter and version-string masking are already deployed and committed. The user must decide separately whether to keep, modify, or remove that component. This plan assumes it stays.
- **License File & eaanticheat.sys (CM1):** The F1 24 anti-cheat install gaps (missing .dlf file, missing driver) are prerequisite infrastructure, not security remediation. Tracked separately.
- **Debug Log Secrets (S2, S4):** World-readable `/tmp` token dumps and debug logs are being addressed (umask in start-ea.sh is already added). Not repeated here.
- **Other S/D Findings:** S5, S6, S7, D1, D2, D4, D5, D6 are listed in the review but deferred or covered elsewhere.

---

## Glossary & Notes

- **dosdevices:** Wine prefix virtual drive mappings (c:, e:, z:, etc.)
- **WINEPREFIX:** The prefix directory path (`/Volumes/ExT2/GameHub/Prefix`)
- **Entitlements:** macOS code-signing entitlements that grant capabilities (hardware access, executable memory, etc.)
- **Library Validation:** Apple's check that all loaded dylibs/frameworks are signed by the same developer.
- **SIGBUS:** Signal: bus error, caused by accessing a memory address that was unmapped while a process held a reference to it (risk with in-place .so overwrites).
- **Rosetta:** Apple's x86-64-to-ARM64 translation layer; Wine runs under it on M1/M2/M3 Macs.
- **WINE_COMPATDB:** Wine environment variable that specifies per-executable compatibility settings (used in start-ea.sh).
- **atomic rename:** `os.replace()` on a single filesystem uses POSIX `rename(2)`, which is atomic (all-or-nothing).
- **HUB_RUNTIME, HUB_X87_PATH, ROSETTA_X87_PATH:** Environment variable overrides that point to the runtime directory; can be set by a parent process to redirect where Wine loads libraries from (S7 risk).

---

**Next Steps:**
1. User reviews this plan and makes decisions (Team ID, entitlements, dosdevices paths, gate mode).
2. User approves and schedules execution (either incrementally or as a block).
3. Each step is executed only as approved by the user, with rollback procedures documented for each.
4. Post-execution validation confirms EA Desktop remains functional.
