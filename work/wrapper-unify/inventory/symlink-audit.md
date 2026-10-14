# Wine Prefix Symlink Audit Report

**Date:** 2026-10-11  
**Repository:** /Users/gc/Developer/nfs-macos  
**Symlink Configuration:**
- `~/Library/Application Support/BF3Mac/Data/Prefix` → `/Volumes/ExT2/GameHub/Relocated/BF3Mac/Data/Prefix`
- `~/Library/Application Support/NFS2015Mac/Data/Prefix` → `/Volumes/ExT2/GameHub/Relocated/NFS2015Mac/Data/Prefix`

## Executive Summary

The codebase implements **implicit symlink following** via early resolution in `AppPaths.__init__`, which means most code paths work correctly when the external drive is connected. However, several critical failure modes exist when the external drive is unplugged or inaccessible:

1. **Prefix initialization fails** with wrong error when symlink target is unreachable
2. **Automatic re-seeding** may occur because `fileExists()` returns false for dangling symlinks
3. **Path containment checks** may reject valid paths due to symlink resolution order
4. **Backup/restore operations** explicitly reject symlink roots with "must be a real folder" error

## Detailed Findings by File

### 1. AppPaths (Symlink Resolution Entry Point)

**File:** `/Users/gc/Developer/nfs-macos/Sources/LauncherCore/AppPaths.swift`

| Location | Code | Behavior (Drive Connected) | Behavior (Drive Unplugged) | Severity |
|----------|------|---------------------------|---------------------------|----------|
| Line 11-12 | `let bundle = bundle.standardizedFileURL.resolvingSymlinksInPath()` `let support = support.standardizedFileURL.resolvingSymlinksInPath()` | Resolves ~/Library/Application Support/NFS2015Mac symlink to /Volumes/ExT2/GameHub/Relocated/NFS2015Mac. All downstream URL properties (prefix, data, etc) use resolved path. | `resolvingSymlinksInPath()` on dangling symlink: returns symlink path as-is (conservative). Result: paths constructed from dangling symlink paths. Subsequent fileExists() checks return false. | ok |

**Analysis:** AppPaths early resolution strategy is sound—it resolves symlinks once at initialization. The resolved paths are then propagated throughout the object. This is actually defensive programming that isolates symlink complexity to one location.

---

### 2. PrefixActivity.serverSocket()

**File:** `/Users/gc/Developer/nfs-macos/Sources/LauncherCore/PrefixActivity.swift`

| Location | Code | Behavior (Drive Connected) | Behavior (Drive Unplugged) | Severity |
|----------|------|---------------------------|---------------------------|----------|
| Line 10 | `guard stat(prefix.path, &info) == 0 else { return nil }` | `stat()` follows symlink, returns inode of /Volumes/ExT2 target. Wine server socket derived from dev+inode. Correct operation. | `stat()` fails (ENOENT) because symlink target doesn't exist. Returns nil. `serverSocket()` returns nil → `serverIsRunning()` returns false. | ok |

**Analysis:** Correct behavior. When the drive is unplugged, `stat()` fails gracefully, and Wine activity detection correctly reports "not running." No data loss.

---

### 3. PrefixSeed.prepare() - File Existence Decision Point

**File:** `/Users/gc/Developer/nfs-macos/Sources/LauncherCore/PrefixSeed.swift`

| Location | Code | Behavior (Drive Connected) | Behavior (Drive Unplugged) | Severity |
|----------|------|---------------------------|---------------------------|----------|
| Line 61 | `package var isSeeded: Bool { files.fileExists(atPath: recordURL.path) }` | `recordURL = paths.data.appendingPathComponent("seed.json")`. Since data is resolved external path, checks /Volumes/ExT2/.../seed.json. Returns true if exists on external drive. | `fileExists()` on /Volumes/ExT2/.../seed.json returns false (target unreachable). `isSeeded` returns false even though seed record exists on unplugged drive. | wrong-behaviour |
| Line 111-118 | `if files.fileExists(atPath: paths.data.path) { guard isSeeded, files.fileExists(atPath: paths.prefix.appendingPathComponent("drive_c").path) else { throw .operation("Player data is incomplete...") } return paths.prefix }` | When data exists: checks isSeeded and prefix contents. If both valid, returns prefix immediately without re-seeding. | When external drive unplugged: `fileExists(paths.data.path)` returns false (dangling symlink target). Code proceeds to create new prefix. Then line 139 `moveItem(stage, to: paths.data)` will fail trying to move staged data to dangling symlink location. | wrong-behaviour |

**Analysis:** **CRITICAL DECISION POINT**: `fileExists()` returns false for symlink targets that don't exist. When external drive unplugged, the code incorrectly decides "data is missing" and attempts to re-seed. The `moveItem()` at line 139 will then fail trying to write to the unreachable external drive path.

---

### 4. PreparedPrefixPlacement.place() - File Existence Decision Point

**File:** `/Users/gc/Developer/nfs-macos/Sources/LauncherCore/PreparedPrefix.swift`

| Location | Code | Behavior (Drive Connected) | Behavior (Drive Unplugged) | Severity |
|----------|------|---------------------------|---------------------------|----------|
| Line 165 | `package var isPlaced: Bool { files.fileExists(atPath: recordURL.path) }` | `recordURL = data.appendingPathComponent("seed.json")`. Since data is resolved external path, checks /Volumes/ExT2/.../seed.json. Returns true if placed record exists. | `fileExists()` returns false for unreachable /Volumes/ExT2 target. `isPlaced` incorrectly returns false. | wrong-behaviour |
| Line 176-183 | `if files.fileExists(atPath: data.path) { guard isPlaced, files.fileExists(atPath: prefix.appendingPathComponent("drive_c").path) else { throw .operation("Player data is incomplete...") } return prefix }` | Checks if data directory exists. If yes and prefix is valid, returns it immediately. Otherwise proceeds to create new prefix. | When external drive unplugged: `fileExists(data.path)` returns false (dangling symlink). Code proceeds to createDirectory and place new prefix. Line 201 `moveItem(stage, to: data)` fails trying to write to dangling symlink target. | wrong-behaviour |

**Analysis:** Same pattern as PrefixSeed. **Critical decision point** incorrectly triggered by `fileExists()` returning false for unreachable symlink targets.

---

### 5. GuestIsolation.restrict() - Symlink Containment Check

**File:** `/Users/gc/Developer/nfs-macos/Sources/LauncherCore/GuestIsolation.swift`

| Location | Code | Behavior (Drive Connected) | Behavior (Drive Unplugged) | Severity |
|----------|------|---------------------------|---------------------------|----------|
| Line 27-29 | `let prefix = prefix.standardizedFileURL` `let root = root.resolvingSymlinksInPath().standardizedFileURL` `guard prefix.resolvingSymlinksInPath().path.hasPrefix(root.path + "/") else { throw .operation("Wine's prefix is outside the player folder.") }` | Both prefix and root are passed as resolved external paths from AppPaths. `prefix.resolvingSymlinksInPath()` on already-resolved /Volumes/ExT2 path follows nothing. Check: `/Volumes/ExT2/...Data/Prefix` hasPrefix `/Volumes/ExT2/...Data/` → TRUE. Passes. | When drive unplugged, paths are dangling symlink paths. `resolvingSymlinksInPath()` returns symlink path as-is (cannot resolve target). Comparison still works because both sides use same dangling symlink base path. Check still passes or fails consistently. | ok |

**Analysis:** This check actually works robustly because **both sides** use the same resolution logic. However, note that prefix is **not** resolved (line 27 uses only standardizedFileURL), while root **is** resolved (line 28). This asymmetry is subtle but safe in this case because both are derived from the same AppPaths object.

---

### 6. BoundedTree.inventory() - Explicit Symlink Root Rejection

**File:** `/Users/gc/Developer/nfs-macos/Sources/LauncherCore/BoundedTree.swift`

| Location | Code | Behavior (Drive Connected) | Behavior (Drive Unplugged) | Severity |
|----------|------|---------------------------|---------------------------|----------|
| Line 30-35 | `let root = root.standardizedFileURL` `let values = try root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])` `guard values.isDirectory == true, values.isSymbolicLink != true else { throw .operation(...) }` | When called on prefix or data folder: `root.standardizedFileURL` does NOT resolve symlinks at this point. Then checks `isSymbolicLink`. If root is /Users/.../Prefix symlink, check fails with "must be a real folder." | When external drive unplugged: `resourceValues()` attempts to stat the URL. Symlink exists but target unreachable. May throw error or return inconsistent isDirectory/isSymbolicLink values. Either way, the `isSymbolicLink != true` check fails or throws. | wrong-behaviour |
| Line 48-50 | `guard attributes.isSymbolicLink != true else { throw .operation("Links are not supported in player folders.") }` | Recursively rejects any symlinks within tree. | Same. | wrong-behaviour |

**Analysis:** **MAJOR ISSUE**: BoundedTree is called for backup/restore/save operations on the Prefix. If the Prefix itself is a symlink (which it is in the current setup), the operation fails immediately with "must be a real folder." This is by design but **incompatible with the symlink-based prefix relocation**.

---

### 7. WineRuntime.performInitialization()

**File:** `/Users/gc/Developer/nfs-macos/Sources/LauncherCore/WineRuntime.swift`

| Location | Code | Behavior (Drive Connected) | Behavior (Drive Unplugged) | Severity |
|----------|------|---------------------------|---------------------------|----------|
| Line 87 | `try FileManager.default.createDirectory(at: prefix, withIntermediateDirectories: false)` | When prefix is /Volumes/ExT2/.../Prefix (resolved target): creates directory on external drive. Success if drive mounted and writable. | When prefix is symlink path to unreachable target: `createDirectory()` attempts to create /Volumes/ExT2/.../Prefix but volume not mounted. Fails with EACCES or EIO. Confusing error message doesn't mention drive. | wrong-behaviour |

**Analysis:** When prefix initialization runs on an unplugged drive, the error is not descriptive. The code should check drive accessibility before attempting initialization.

---

### 8. FileTransaction.checked() - Path Containment Validation

**File:** `/Users/gc/Developer/nfs-macos/Sources/LauncherCore/FileTransaction.swift`

| Location | Code | Behavior (Drive Connected) | Behavior (Drive Unplugged) | Severity |
|----------|------|---------------------------|---------------------------|---------|
| Line 14 | `package init(root: URL) { self.root = root.standardizedFileURL.resolvingSymlinksInPath() }` | Root is resolved to /Volumes/ExT2/.../Data. | Root resolved to dangling symlink path or original symlink (if resolution fails). | ok |
| Line 92-97 | `let resolved = url.standardizedFileURL.resolvingSymlinksInPath()` `guard resolved.path.hasPrefix(root.path + "/"), resolved != journal else { throw .operation("Update target is outside the player folder.") }` | Paths resolved consistently. Both use `resolvingSymlinksInPath()`. Check compares resolved paths. | Consistent behavior—both use same resolution logic. May have dangling symlink issues but containment check still valid. | ok |

**Analysis:** Robust pattern. Both URL and root use same resolution.

---

### 9. SpaceProbe.freeBytes() - Drive Detection

**File:** `/Users/gc/Developer/nfs-macos/Sources/HubCore/SpaceProbe.swift`

| Location | Code | Behavior (Drive Connected) | Behavior (Drive Unplugged) | Severity |
|----------|------|---------------------------|---------------------------|---------|
| Line 13-22 | `var path = url.standardizedFileURL.path` `while true { var info = statfs(); if statfs(path, &info) == 0 { return Int64(...) }; guard errno == ENOENT \|\| errno == ENOTDIR ... { path = ... }` | For hub path on /Volumes/ExT2, `statfs()` returns space info for external drive. Reports external drive free space correctly. | For hub path that's dangling symlink to /Volumes/ExT2: `statfs()` fails (ENOENT). Code walks up: tries Library/Application Support, then Library, then home. Eventually reaches internal drive and returns internal drive space. HubModel correctly detects this as "drive not connected." | ok |

**Analysis:** This is good detection logic. When external drive is unavailable, the code gracefully falls back and correctly signals "Game drive not connected" in HubModel.

---

### 10. SessionLock.withLock()

**File:** `/Users/gc/Developer/nfs-macos/Sources/LauncherCore/SessionLock.swift`

| Location | Code | Behavior (Drive Connected) | Behavior (Drive Unplugged) | Severity |
|----------|------|---------------------------|---------------------------|---------|
| Line 9 | `let descriptor = open(url.path, O_CREAT \| O_RDWR \| O_CLOEXEC \| O_NOFOLLOW, 0o600)` | Lock file path is paths.support.appendingPathComponent("session.lock") = /Volumes/ExT2/.../session.lock. `open()` with O_NOFOLLOW prevents following any symlink in the filename itself. Creates file on external drive. | Lock file path is dangling symlink target /Volumes/ExT2/.../session.lock. `open()` tries to create on unmounted volume. Fails with EACCES or EIO, descriptor < 0. Line 11 throws "Cannot open the session lock." | wrong-behaviour |

**Analysis:** O_NOFOLLOW is good practice but doesn't help with the core issue: the path itself is unreachable. The lock file is in the support directory (not a symlink), but the directory path is on the external drive. When unreachable, the open fails with low-level error.

---

### 11. BoundedFile.read() - Symlink Handling

**File:** `/Users/gc/Developer/nfs-macos/Sources/LauncherCore/BoundedFile.swift`

| Location | Code | Behavior (Drive Connected) | Behavior (Drive Unplugged) | Severity |
|----------|------|---------------------------|---------------------------|---------|
| Line 6 | `let metadata = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])` | Works on resolved external drive paths. Reads file properties. | When URL target unreachable (dangling symlink): `resourceValues()` may fail or return partial data. Line 7 throws "Invalid or oversized file." | wrong-behaviour |

**Analysis:** `BoundedFile.read()` doesn't explicitly check for symlinks, only that files are regular files of valid size. When the target is unreachable, `resourceValues()` fails.

---

### 12. PreparedPrefix.copyTree()

**File:** `/Users/gc/Developer/nfs-macos/Sources/LauncherCore/PreparedPrefix.swift`

| Location | Code | Behavior (Drive Connected) | Behavior (Drive Unplugged) | Severity |
|----------|------|---------------------------|---------------------------|---------|
| Line 216-220 | `let flags = copyfile_flags_t(COPYFILE_ALL \| COPYFILE_RECURSIVE \| COPYFILE_CLONE \| COPYFILE_NOFOLLOW)` `guard copyfile(template.path, target.path, nil, flags) == 0 else { throw ... }` | COPYFILE_NOFOLLOW prevents following symlinks in template. Clones/copies to target. When target is /Volumes/ExT2 path, copies to external drive. | When target path is dangling symlink: `copyfile()` tries to create files on unmounted volume. Fails with EACCES or EIO. | wrong-behaviour |

**Analysis:** COPYFILE_NOFOLLOW is good, but the destination path itself is unreachable.

---

## Decision Points: "Prefix Missing" → Re-Seed/Re-Create

When external drive is unplugged, `FileManager.fileExists()` returns **false** for symlink targets that don't exist. This triggers several decision points:

### Path 1: PrefixSeed.prepare() (Line 111)
```
if files.fileExists(atPath: paths.data.path) {  // FALSE when drive unplugged
  guard isSeeded, ... // not reached
} else {
  // Code attempts to create new prefix and moveItem to paths.data (dangling symlink)
  // moveItem fails with low-level I/O error
}
```

### Path 2: PreparedPrefixPlacement.place() (Line 176)
```
if files.fileExists(atPath: data.path) {  // FALSE when drive unplugged
  guard isPlaced, ... // not reached
} else {
  // Code attempts to place new prefix and moveItem to data (dangling symlink)
  // moveItem fails with low-level I/O error
}
```

**Common Outcome:** When external drive is unplugged, these decision points incorrectly trigger prefix recreation attempts, which fail at `moveItem()` with confusing low-level I/O errors instead of clear "drive not connected" messages.

---

## Summary by Severity

### data-loss / wrong-behaviour
- **PrefixSeed.prepare()** (lines 111-118, 139): `fileExists()` returns false for unreachable symlink; code attempts to re-seed and fails at moveItem.
- **PreparedPrefixPlacement.place()** (lines 176-183, 201): Same pattern.
- **BoundedTree.inventory()** (lines 30-35): Explicitly rejects Prefix if it's a symlink with "must be a real folder" error.
- **WineRuntime.performInitialization()** (line 87): `createDirectory()` fails with low-level error when trying to initialize prefix on unreachable drive.
- **SessionLock.withLock()** (line 9): `open()` fails with low-level error when lock file path is on unreachable drive.

### cosmetic / ok
- **PrefixActivity.serverSocket()** (line 10): Correctly returns nil when drive unreachable.
- **GuestIsolation.restrict()** (line 29): Symlink containment check works robustly.
- **FileTransaction** (line 14, 92-97): Consistent symlink resolution.
- **SpaceProbe.freeBytes()** (line 13-22): Correct detection and fallback.

### architectural insight
- AppPaths' early symlink resolution strategy is sound and isolates complexity.
- BoundedTree's symlink rejection is intentional security/safety policy but **incompatible** with prefix symlink relocation strategy.
- HubModel correctly detects disconnected drive via SpaceProbe behavior.

---

## Recommendations

1. **Prefix Initialization Guard:** Check drive accessibility before `createDirectory()` at WineRuntime line 87. Use SpaceProbe pattern or access-check before attempting creation on external path.

2. **Clear Error Messages:** When operations fail on unreachable external drive paths, wrap low-level I/O errors with context like "Game drive not connected" or "Prefix location is inaccessible."

3. **BoundedTree Compatibility:** Decide whether BoundedTree should accept symlink roots when they point to valid directories. If not by design, document that backup/restore of relocatable prefixes is not supported.

4. **Dangling Symlink Detection:** Add helper to explicitly detect unreachable symlink targets before operations. Current pattern of "try and fail" is confusing.

5. **Prefix Existence Check:** Add explicit check for prefix accessibility (e.g., `stat()` on prefix path) before decision points in PrefixSeed and PreparedPrefixPlacement.
