# S1 — Prefix and Runtime Write Isolation (Corrected Plan)

**Date:** 15 October 2026
**STATUS: S1.1 and S1.2 are APPLIED (15 October 2026) to the real Prefix and runtime, verified via a clone test followed by the real apply — see `docs/eaac/S1-test-evidence-20261015.md` for full evidence. S1.3 is NOT APPLIED — still draft, needs explicit user approval before any command in §4 is run. S3 (versioned deploy manifest/signing of the whole runtime) is explicitly OUT OF SCOPE here and stays DEFERRED — nothing in this document touches S3.**

**Source finding:** `/Users/gc/Desktop/EAAC-FULL-REVIEW-20261014.md` §5, finding **S1 — HIGH — guest-writable host runtime + unsandboxed launch path with broad entitlements**.

This document replaces the S1.1–S1.3 steps of `EAAC-REMEDIATION-S1-S3.md` with corrected, empirically-grounded versions. It does not replace S1.4 (launch-gate signature verification in `start-ea.sh`) or anything under S3 in that document; those are untouched and still DEFERRED.

---

## 1. Honest scope statement

S1.1 (repoint `z:`) and S1.2 (immutable runtime directories) close the exposure paths that were actually *observed*: an installer or anti-cheat process dropping hundreds of files into the prefix by walking drive letters (per the original review's S1 finding, ~530 files were dropped this way in one capture), casual drive enumeration (`GetLogicalDrives`, Explorer-style browsing), and any code that hardcodes a `Z:\...` or wide `E:\...` path. Both steps are enforceable without root on this volume, and both were tested directly on this host before being written up below. They are worth doing on their own terms: they raise the bar substantially against the careless/automatic class of write, and they are a prerequisite for any deeper fix later.

They do **not** make this setup a sandbox against a deliberate, sophisticated attacker. Wine's own `ntdll` (`dlls/ntdll/unix/file.c`, `get_nt_and_unix_names` / `nt_to_unix_file_name_no_root`, the `is_unix` check near line 3737) treats any path beginning with the literal NT prefix `\??\unix\` or `\\?\unix\` as a direct, ungated route to the host filesystem rooted at `/`, with no dependency on any drive letter, no dosdevices lookup, and no permission gate beyond ordinary Unix file permissions for the user the Wine process runs as — open-for-write and file creation included. This path is reachable from any Windows-side process (`CreateFile` with that literal string) regardless of what `z:` points to, or whether `z:` exists at all. **Repointing or removing `z:` does not close this.** It is a labeled residual risk, not fixed here, and explicitly out of scope for today — see the follow-up item at the end of this section.

A related finding: a Windows-side process can exec a native Unix binary (e.g. `/usr/bin/chflags`) via Wine's `NtCreateUserProcess` → `fork_and_exec` → `execv` fallback for non-PE images (`dlls/ntdll/unix/process.c`), reachable through the same `\??\unix\` convention with no drive needed. A sufficiently hostile, Wine-internals-aware payload could run `chflags nouchg` on the runtime itself and defeat S1.2's protection too. So: **S1.2 is a tripwire and a raised bar against accidental or careless writes** — the actual observed threat, an installer/anti-cheat dropping hundreds of files — **not an airtight sandbox against a deliberate attacker** who already knows Wine's internals.

Despite these limits, both S1.1 and S1.2 are worth doing now: they close the easy, accidental, automatic paths that were actually observed happening, they raise the bar substantially for anything short of a deliberately hand-crafted bypass, and they are prerequisites for any later, deeper fix (such as gating the `\??\unix\` convention itself inside Wine's `ntdll`, which is a separate, higher-regression-risk change — Wine's own internal path translation and its macOS font integration both appear to rely on that same convention for legitimate purposes, so patching it needs its own dedicated review, not a drive-by edit here).

**Follow-up item (not addressed by this plan):** *S1-residual: `\\?\unix\` bypass is architectural, not configuration.* Tracked here by name only; no fix is attempted in this document.

---

## 2. S1.1 — Repoint `z:` away from the whole filesystem

### Decision: `e:` and `c:` are unchanged

- **`e:` stays pointed at `/Volumes/ExT2/GameHub` (the whole volume).** EA Desktop's own registry entries and configs hardcode `E:\EA Games\...` and `E:\Library\...` paths. No safe narrower subset of the volume was found that covers everything EA Desktop and the installed game actually touch under `E:\`; narrowing `e:` is an explicit **non-goal** of this plan. (The original remediation draft's S1.1 proposed narrowing `e:` "after testing" without having verified a safe subset — that is not repeated here.)
- **`c:` stays pointed at `../drive_c` (relative).** It already resolves inside `$PREFIX/drive_c` and does not escape the prefix. This is a verified non-issue, not something S1.1 needs to touch.

### The change: `z:` moves from `/Volumes` to a new, empty, owner-only directory

`z:` currently points at `/Volumes`, which exposes every mounted volume, including `/Volumes/SSD` — a root-owned symlink to `/`, i.e. full filesystem access to `/Users/gc` from the Windows side. `z:` is repointed to a brand-new, empty directory, `/Volumes/ExT2/GameHub/Prefix/z-empty`, mode `0500` (owner read+execute, no write for anyone — so nothing can be dropped into the `Z:` drive either).

Deleting just the `dosdevices/z:` symlink (leaving the `dosdevices/` directory itself in place) is not recreated by Wine/wineserver/wineboot on a later launch: dosdevices recreation only happens once, the very first time the `dosdevices` directory itself is created (`dlls/ntdll/unix/server.c`, `setup_config_dir`, `mkdir` with an `EEXIST` check), and wineboot's prefix-update logic is driven only by `wine.inf` mtime vs. `.update-timestamp`, never by dosdevices contents. So the repointed `z:` is expected to stick across restarts. Separately, an EA Desktop log was found showing font paths resolved as `\??\unix\Users\gc\Library\Fonts\...` with no `Z:` prefix at all even while `z:` covered `/Volumes` — meaning Wine's own internal path resolution already prefers the `\??\unix\` fallback over any drive letter for most host paths outside the drives it explicitly knows about. This is the reasoning for why the change below is *expected* to be low-risk for Wine's own internal use of `Z:`, not a guarantee — functional confirmation happens in the clone-testing phase (§7).

No `Z:\...` strings were found hardcoded in EA Desktop's `ProgramData`/`AppData` config files or in GameHub's own scripts/docs (verified via grep) — only ~631 benign Windows-system-font paths like `Z:\System\Library\Fonts\...` inside `system.reg`, which point at paths Wine manages itself, not `/Users/gc` content.

### Apply

```bash
#!/usr/bin/env bash
set -eu
PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

PREFIX="/Volumes/ExT2/GameHub/Prefix"
DOSDEVICES="$PREFIX/dosdevices"
Z_TARGET="$PREFIX/z-empty"
STATE_DIR="$PREFIX/.s1-rollback"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
STATE_FILE="$STATE_DIR/z-target-$TIMESTAMP.txt"

[ -d "$PREFIX" ] || { echo "refusing: $PREFIX is not a directory" >&2; exit 1; }

mkdir -p "$STATE_DIR"

# Record the CURRENT z: target BEFORE any change, so rollback reads the exact
# prior value instead of assuming it (the old plan's rollback recorded the
# wrong target — this avoids that bug).
if [ -L "$DOSDEVICES/z:" ]; then
  readlink "$DOSDEVICES/z:" > "$STATE_FILE"
else
  echo "__ABSENT__" > "$STATE_FILE"
fi
echo "Recorded prior z: target in: $STATE_FILE"
cat "$STATE_FILE"

# Create the new, empty, owner-only target.
mkdir -p "$Z_TARGET"
chmod 0500 "$Z_TARGET"

# Repoint z: (works whether or not dosdevices/z: currently exists as a symlink).
rm -f "$DOSDEVICES/z:"
ln -s "$Z_TARGET" "$DOSDEVICES/z:"

echo "z: now points to: $(readlink "$DOSDEVICES/z:")"
```

### Verify

This verifies the filesystem-level change only. Functional verification — launching `wine cmd /c dir Z:\`, confirming EA Desktop still starts, and running the negative escape tests (confirming `/Volumes/SSD` and sibling volumes are no longer reachable via `Z:`) — happens in the later clone-testing phase of this initiative; see "Clone Test Plan" cross-reference in §7. It is not duplicated here.

```bash
#!/usr/bin/env bash
set -eu
PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

PREFIX="/Volumes/ExT2/GameHub/Prefix"
DOSDEVICES="$PREFIX/dosdevices"
Z_TARGET="$PREFIX/z-empty"

if [ -d "$Z_TARGET" ]; then
  echo "PASS: $Z_TARGET exists and is a directory"
else
  echo "FAIL: $Z_TARGET missing or not a directory"
  exit 1
fi

RESOLVED="$(readlink "$DOSDEVICES/z:" 2>/dev/null || true)"
if [ "$RESOLVED" = "$Z_TARGET" ]; then
  echo "PASS: dosdevices/z: -> $RESOLVED"
else
  echo "FAIL: dosdevices/z: resolves to '$RESOLVED', expected '$Z_TARGET'"
  exit 1
fi

PERM="$(stat -f '%Lp' "$Z_TARGET")"
if [ "$PERM" = "500" ]; then
  echo "PASS: z-empty permission bits are 500 (owner r-x, no write, no group/other access)"
else
  echo "FAIL: z-empty permission bits are $PERM, expected 500"
  exit 1
fi
```

### Rollback

Rollback must restore the **exact** prior target recorded at apply time, read from the state file — never a hardcoded guess such as `/Volumes` (that was bug #1 in the old plan).

```bash
#!/usr/bin/env bash
set -eu
PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

PREFIX="/Volumes/ExT2/GameHub/Prefix"
DOSDEVICES="$PREFIX/dosdevices"

# Caller must set STATE_FILE to the exact file the apply script wrote, e.g.:
#   STATE_FILE="/Volumes/ExT2/GameHub/Prefix/.s1-rollback/z-target-20261015-143000.txt" bash rollback-s1.1.sh
: "${STATE_FILE:?STATE_FILE must be set to the apply-time recorded state file (see $PREFIX/.s1-rollback/)}"

[ -f "$STATE_FILE" ] || { echo "refusing to roll back: STATE_FILE '$STATE_FILE' does not exist" >&2; exit 1; }

PRIOR_TARGET="$(cat "$STATE_FILE")"

rm -f "$DOSDEVICES/z:"
if [ "$PRIOR_TARGET" = "__ABSENT__" ]; then
  echo "Rolled back: removed dosdevices/z: (it did not exist before S1.1 was applied)"
else
  ln -s "$PRIOR_TARGET" "$DOSDEVICES/z:"
  echo "Rolled back: dosdevices/z: -> $(readlink "$DOSDEVICES/z:")"
fi
```

---

## 3. S1.2 — Make the runtime directory tree immutable to guest writes

### Tested semantics

Empirically tested on this host, 2026-10-15, on `/Volumes/ExT2` (the same volume as the Prefix and Runtimes, case-sensitive APFS, not encrypted, mounted `noowners`), without root:

- `chflags uchg <file>` blocks write, `rm`, and `mv <other> <file>` (rename-over) on that file, without root.
- `chflags -R uchg <directory>` (recursive, on the directory itself) **also** blocks creating any new file inside that directory, and blocks renaming a new file into it. Both `echo x > dir/newfile` and `mv file dir/target2` failed with "Operation not permitted" when the directory itself carried `uchg`.
- `chflags uchg`/`nouchg` is settable and clearable by the owning user without root (no sudo available or needed here).

A directory-level `chflags -R uchg` on `$RT/bin`, `$RT/lib`, and `$HELPERS` is therefore a stronger protection than file-level flagging alone: it also blocks dropping a brand-new file into those directories, which is exactly how the anti-cheat/installer dropped ~530 files into the prefix per the original review's S1 finding.

Wine itself never writes into its own `lib/` or `bin/` at runtime (confirmed by source grep: no `chflags`/`fchflags` calls anywhere in `dlls/ntdll/unix`, no writes under `$RT`; wineserver's socket lives under `/tmp/.wine-<uid>`, not in the runtime), so marking `$RT/bin` and `$RT/lib` immutable does not fight Wine's own behavior. No wine/EA/game process is currently running on this machine (verified via `ps`), and the runtime has zero symlinks and zero hard-linked files (verified via `find`), so a recursive `chflags` has no surprising aliasing to worry about.

Verification must not rely on `ls -lO` (BSD-only; this machine's default `ls` is GNU and rejects `-O`). The scripted check below uses `stat -f '%Sf' <path>` (prints e.g. `uchg` or `uchg,archived`) — but that flag is **not** portable: this machine has Homebrew coreutils' `gnubin` ahead of `/usr/bin` on an operator's interactive `PATH`, so a bare `stat` resolves to GNU `stat`, whose own `-f FORMAT` flag means something else entirely ("print filesystem info," no format argument) and has no equivalent of BSD file-flags at all. Reproducing `stat -f '%Sf' <path>` on this host with GNU `stat` ahead in `PATH` was confirmed empirically to fail immediately, which would abort any script running under `set -eu` before it ever reaches the check. The scripts below therefore pin `PATH` to `/usr/bin:/bin:/usr/sbin:/sbin` (prepended) at the top of every script block, forcing `/usr/bin/stat` (BSD) regardless of the operator's own shell configuration. `/bin/ls -lO` remains available as an alternative for a human checking interactively.

### Apply

```bash
#!/usr/bin/env bash
set -eu
PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

RT="/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer"
HELPERS="/Volumes/ExT2/GameHub/Runtimes/hub-0-helpers-fpr"

[ -d "$RT/bin" ] || { echo "refusing: $RT/bin is not a directory" >&2; exit 1; }
[ -d "$RT/lib" ] || { echo "refusing: $RT/lib is not a directory" >&2; exit 1; }
[ -d "$HELPERS" ] || { echo "refusing: $HELPERS is not a directory" >&2; exit 1; }

# Canary file: locked along with everything else under $RT/bin, so verify can
# probe this instead of ever writing against the live wine binary.
: > "$RT/bin/.s1-canary"

chflags -R uchg "$RT/bin"
chflags -R uchg "$RT/lib"
chflags -R uchg "$HELPERS"

echo "Applied uchg to: $RT/bin, $RT/lib, $HELPERS"
```

### Verify

The negative-write probes are *expected* to fail (permission denied). Each is wrapped in an `if ( ... ) 2>/dev/null; then FAIL; else PASS; fi` so the expected failure does not trip `set -e` and abort the verify script itself.

```bash
#!/usr/bin/env bash
set -eu
PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

RT="/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer"
HELPERS="/Volumes/ExT2/GameHub/Runtimes/hub-0-helpers-fpr"
CANARY="$RT/bin/.s1-canary"

check_flag() {
  target="$1"
  flags="$(stat -f '%Sf' "$target")"
  case "$flags" in
    *uchg*) echo "PASS: $target has uchg (flags: $flags)" ;;
    *) echo "FAIL: $target missing uchg (flags: $flags)"; exit 1 ;;
  esac
}

check_flag "$RT/bin/wine"
check_flag "$RT/lib/wine/x86_64-unix/ntdll.so"
check_flag "$RT/lib/wine/i386-windows/ntdll.dll"
check_flag "$HELPERS/x87sidecar"
check_flag "$CANARY"

# Negative probe 1: writing must fail. This targets the canary file created at
# apply time, never the live wine binary itself. Belt-and-suspenders: also
# capture the canary's size before and after the probe and fail if it changed,
# in addition to checking whether the write call itself reported success.
SIZE_BEFORE="$(stat -f '%z' "$CANARY")"
if ( : > "$CANARY" ) 2>/dev/null; then
  echo "FAIL: write to $CANARY succeeded (should have been blocked)"
  exit 1
else
  echo "PASS: write to $CANARY was blocked"
fi
SIZE_AFTER="$(stat -f '%z' "$CANARY")"
if [ "$SIZE_BEFORE" != "$SIZE_AFTER" ]; then
  echo "FAIL: $CANARY size changed from $SIZE_BEFORE to $SIZE_AFTER despite blocked write"
  exit 1
else
  echo "PASS: $CANARY size unchanged ($SIZE_BEFORE bytes)"
fi

# Negative probe 2: creating a brand-new file inside a protected directory must fail.
PROBE="$RT/bin/.s1-write-probe.$$"
if ( : > "$PROBE" ) 2>/dev/null; then
  echo "FAIL: created new file $PROBE inside protected directory (should have been blocked)"
  rm -f "$PROBE"
  exit 1
else
  echo "PASS: creating a new file inside $RT/bin was blocked"
fi
```

### Rollback

```bash
#!/usr/bin/env bash
set -eu
PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

RT="/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer"
HELPERS="/Volumes/ExT2/GameHub/Runtimes/hub-0-helpers-fpr"

[ -d "$RT/bin" ] || { echo "refusing: $RT/bin is not a directory" >&2; exit 1; }
[ -d "$RT/lib" ] || { echo "refusing: $RT/lib is not a directory" >&2; exit 1; }
[ -d "$HELPERS" ] || { echo "refusing: $HELPERS is not a directory" >&2; exit 1; }

chflags -R nouchg "$RT/bin"
chflags -R nouchg "$RT/lib"
chflags -R nouchg "$HELPERS"

echo "Rolled back (nouchg) on: $RT/bin, $RT/lib, $HELPERS"
# Note: nouchg on the whole bin/ directory also unlocks the .s1-canary file
# created at apply time; it is harmless and may be left in place.
```

### Deploy-interplay subsection

The existing atomic-rename deploy procedure for `ntdll.so` in `EAAC-BUILD-AND-DEPLOY-20261014.md` §4 does `cp` to a temp file inside `$RT/lib/wine/x86_64-unix/`, then `mv -f` onto `ntdll.so`. Once S1.2 is applied, that directory is covered by the recursive `uchg` on `$RT/lib` and the deploy will fail. The deploy procedure's own steps are **not changed**; they are wrapped in a single cohesive pattern — an unlock immediately followed by a `trap` registration — scoped to just that one subdirectory, not the whole of `$RT/lib`, so `i386-windows`, `x86_64-windows`, `d3d9`, `dxgi`, and `external` stay locked throughout an `ntdll.so`-only deploy. The `trap`, not a second manually-placed snippet after the steps, is what guarantees the directory is relocked on **any** exit path — success, failure, or an early `exit` partway through the deploy steps — which is strictly stronger than placing a relock snippet "after the steps complete": that placement has no enforcement at all if something fails midway, since a script aborting under `set -eu` would simply skip over it and leave the directory unlocked.

```bash
RT_SUBDIR="$RT/lib/wine/x86_64-unix"
chflags -R nouchg "$RT_SUBDIR"
trap 'chflags -R uchg "$RT_SUBDIR"' EXIT
# ... existing deploy steps from EAAC-BUILD-AND-DEPLOY-20261014.md §4 (cp + mv) go here, unchanged ...
```

This is a required amendment to `EAAC-BUILD-AND-DEPLOY-20261014.md` — out of scope for this document to edit directly; flagged here as a follow-up to apply there too.

---

## 4. S1.3 — Host entitlements (sign libraries, drop unused device entitlements, re-enable library validation)

> **STATUS: WRITTEN FOR REVIEW ONLY. NOT APPLIED. Needs explicit user approval before any command below is run.**

### The risk

Removing `com.apple.security.cs.disable-library-validation` from `bin/wine`'s entitlements requires **every** `.so`/`.dylib` the signed `wine` binary loads to be signed with the **same Team ID** (`NP94WB3P75`) as `wine` itself, or the dynamic loader refuses to load it once library validation is re-enabled, and Wine fails to start entirely. Specifically, as of this review:

- `lib/wine/x86_64-unix/ntdll.so` and `winemac.so` are **completely unsigned**.
- `lib/wine/x86_64-unix/compatdb.so` has a Team ID (`NP94WB3P75`) but **no Authority chain** — its signing state needs re-verification, not just a Team ID string match, before being trusted.
- Everything under `lib/wine/d3d9`, `lib/wine/dxgi` (including the nested DXMT `winemetal.so`), and `lib/external/*.dylib` must also be confirmed signed with the same Team ID.

Separately, `allow-unsigned-executable-memory` likely needs to stay: Rosetta/JIT/DXMT shader translation may depend on executable-memory allocation at runtime, independent of library validation. Removing it is a separate, even riskier change, not proposed here at all.

### Draft commands (NOT TO BE RUN against the live runtime)

Sign every `.so`/`.dylib` under `$RT/lib` with the Team ID identity (idempotent: only re-signs files whose Team ID doesn't already match):

```bash
#!/usr/bin/env bash
set -eu
PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

RT="/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer"   # MUST be a CLONE path when this is actually run — see testing order below

# Enforced guard, not just a comment: refuse to run against anything that does
# not look like a clone path.
case "$RT" in
  *clone*|*Clone*|*CLONE*) ;;
  *) echo "refusing: RT does not look like a clone path (must contain 'clone'): $RT" >&2; exit 1 ;;
esac

TEAM_ID="NP94WB3P75"
IDENTITY="Developer ID Application: Guillaume Coquard (${TEAM_ID})"

[ -d "$RT/lib" ] || { echo "refusing: $RT/lib is not a directory" >&2; exit 1; }

count=0
while IFS= read -r -d '' f; do
  count=$((count + 1))
  tid="$(codesign -dv "$f" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
  if [ "$tid" != "$TEAM_ID" ]; then
    codesign --force --options runtime --timestamp -s "$IDENTITY" "$f"
  fi
done < <(find "$RT/lib" -type f \( -name '*.so' -o -name '*.dylib' \) -print0)

[ "$count" -gt 0 ] || { echo "no .so/.dylib files found under $RT/lib — aborting, this would otherwise report false success" >&2; exit 1; }

echo "Signed/verified Team ID on $count file(s)."
```

Verify every file now matches, using process substitution (`< <(...)`) rather than a piped `| while read` loop, so the failure count is visible after the loop ends instead of being lost in a subshell (the old plan's bug #4):

```bash
#!/usr/bin/env bash
set -eu
PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

RT="/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer"   # CLONE path

# Enforced guard, not just a comment: refuse to run against anything that does
# not look like a clone path.
case "$RT" in
  *clone*|*Clone*|*CLONE*) ;;
  *) echo "refusing: RT does not look like a clone path (must contain 'clone'): $RT" >&2; exit 1 ;;
esac

TEAM_ID="NP94WB3P75"
FAIL_COUNT=0
count=0

while IFS= read -r -d '' f; do
  count=$((count + 1))
  tid="$(codesign -dv "$f" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
  if [ "$tid" = "$TEAM_ID" ]; then
    echo "PASS: $f"
  else
    echo "FAIL: $f (Team ID: $tid)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
done < <(find "$RT/lib" -type f \( -name '*.so' -o -name '*.dylib' \) -print0)

[ "$count" -gt 0 ] || { echo "no .so/.dylib files found under $RT/lib — aborting, this would otherwise report false success" >&2; exit 1; }

echo "Failures: $FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ]
```

Dump `wine`'s entitlements, strip `disable-library-validation` only (leave every other key untouched for the first isolated test), and re-sign:

```bash
#!/usr/bin/env bash
set -eu
PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

RT="/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer"   # CLONE path

# Enforced guard, not just a comment: refuse to run against anything that does
# not look like a clone path.
case "$RT" in
  *clone*|*Clone*|*CLONE*) ;;
  *) echo "refusing: RT does not look like a clone path (must contain 'clone'): $RT" >&2; exit 1 ;;
esac

TEAM_ID="NP94WB3P75"
IDENTITY="Developer ID Application: Guillaume Coquard (${TEAM_ID})"
PLIST="/tmp/wine-entitlements-$(date +%Y%m%d-%H%M%S).plist"

[ -f "$RT/bin/wine" ] || { echo "refusing: $RT/bin/wine not found" >&2; exit 1; }

codesign -d --entitlements ":$PLIST" "$RT/bin/wine"

# Manual edit step (human, not scripted): open "$PLIST" and delete only the
# com.apple.security.cs.disable-library-validation key/value pair. For the
# first isolated test, leave allow-unsigned-executable-memory and the
# camera/audio-input/bluetooth device entitlements untouched, so only one
# variable changes at a time (see testing order below).

codesign --force --options runtime --timestamp \
  -s "$IDENTITY" \
  --entitlements "$PLIST" \
  "$RT/bin/wine"
```

A later, separate test (step 4 below) repeats this same dump/edit/re-sign pattern against a plist with the `com.apple.security.device.camera`, `com.apple.security.device.audio-input`, and `com.apple.security.device.bluetooth` keys removed one at a time, after the library-validation test has already passed in isolation.

### Testing order — required before this is ever applied to the real runtime

1. Sign every `.so`/`.dylib` in a **clone** of the runtime only.
2. On that clone, re-sign `wine` with only `disable-library-validation` removed — leave `camera`/`audio-input`/`bluetooth` and `allow-unsigned-executable-memory` untouched, to isolate the variable.
3. Launch EA Desktop against a clone prefix + that clone runtime; confirm the `wine` process starts and stays alive; check Console/log for AMFI or code-signing library-validation denials.
4. Only if that passes, test removing `camera`/`audio-input`/`bluetooth` entitlements one at a time, checking for TCC denials or EAGEP/overlay misbehavior.
5. Specifically re-test the Rosetta x87 sidecar path (per `/Users/gc/Developer/GameHub/docs/mtld3d-x87.md`), since removing `disable-library-validation` is a specific risk to x87sidecar loading.
6. Only after all of the above pass on cloned artifacts does this become a candidate — with explicit user sign-off — for the real runtime.

---

## 5. Summary table

| Sub-step | What it changes | Security value | Residual risk | Status |
|---|---|---|---|---|
| S1.1 | Repoints `dosdevices/z:` from `/Volumes` to a new empty, owner-only, no-write directory; `c:` and `e:` left unchanged | Removes casual/automatic access to every mounted volume (including `/Volumes/SSD` → `/`) via drive-letter browsing or hardcoded `Z:\` paths | Does not block the `\??\unix\` convention, which reaches the same files regardless of `z:` | APPLIED 2026-10-15 — see S1-test-evidence-20261015.md |
| S1.2 | Recursive `chflags uchg` on `$RT/bin`, `$RT/lib`, `$HELPERS` | Blocks both overwriting existing runtime files and dropping new files into those directories — closes the exact mechanism (anti-cheat/installer file-drop) observed in the original S1 finding | Does not block a deliberate payload that execs a native `chflags nouchg` via Wine's unix-exec fallback | APPLIED 2026-10-15 — see S1-test-evidence-20261015.md |
| S1.3 | Signs all runtime `.so`/`.dylib` with Team ID `NP94WB3P75`; removes `disable-library-validation` from `wine`'s entitlements; evaluates removing camera/audio-input/bluetooth entitlements | Closes the "unsigned library loaded by a signed, broadly-entitled host" exposure named in the original S1 finding | Requires exhaustive library coverage (including `compatdb.so`'s unverified Authority chain and all of `d3d9`/`dxgi`/`external`) or Wine fails to start; `allow-unsigned-executable-memory` is explicitly kept, so this is not a full sandbox either | Not applied — needs approval |

---

## 6. Cross-reference

Clone-based functional testing of S1.1 and S1.2 happens in a separate test-execution phase of this initiative, not in this document; see the orchestrating task for results.
