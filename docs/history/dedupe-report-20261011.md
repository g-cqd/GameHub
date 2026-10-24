# ExT2 Duplicate Game Data: Deduplication Report

2026-10-11

## 1. Summary

Deduplication scan of 21 file trees on ExT2 identified duplicate game installations bundled into GameHub (Bundles), shadowing Store backups and unregistered EA copies. Two deletion batches were executed: Store backups (cod4, farcry2, nfs-mw) totalling 1,647 files and 13.2 GB on ExT2; BF3 old prefix on the internal disk totalling 8,536 files and 24.9 GB. Free space on ExT2 dropped from approximately 149 GB (morning) to 44.2 GB before work (concurrent EA/F1 24 installs), 33.4 GB before deletions, and 45.3 GB at the end (other writers including EA, other agents continued consuming space during the session). Internal disk freed 24.9 GB from the BF3 old prefix deletion. Items held pending user decision: F1 24 copy selection, EA-unregistered Battlefield 4 recipe repointing, NFS internal copies (pending first launch from relocated prefix), and Store-20261008 residual assessment.

## 2. Method and Limits

Tool: `/Volumes/ExT2/GameHub/work/dedupe-20261011T1641/dedupe.py`, SQLite cache `inventory.sqlite`, resumable.

Scan of 21 trees: store, preserve, manifests, bundles, prefix, nfsreloc, eaunreg, eabf4, eaf1, steamf1, ubifc2, runtimes, three work trees (work/winemac-fs, work/dxmt-rtv, work/wine-fontperf), downloads, scratch, steamgames, and two internal (bf3old, nfsold, nfsstaged).

Per-file byte-exact matching via SHA256; on second pass, every file in keeper trees (bundles, prefix, nfsreloc, ubifc2, eabf4) rehashed. Files changed during read marked unstable/stale and excluded from matching. Clone-aware measurement via APFS extent maps per tree (`fcntl` F_LOG2PHYS_EXT, macOS SDK); union of device ranges = physical bytes per tree; intersection = shared (clone) bytes; exclusive = what deletion of that tree alone would free.

**Limits:**
- Excludes filesystem metadata and snapshots (none on ExT2).
- APFS-compressed files not counted.
- Live prefix churns (~30 EA Desktop/CEF files always changing); prefix physical figures are lower bounds.
- `compare` is cache-based, not deletion evidence; fresh re-hash at delete time is the ground truth.
- WAL database (`sqlite3 -readonly`) cannot open inventory.sqlite; use plain `sqlite3` SELECTs.

## 3. Physical Usage Per Tree (ExT2)

| Tree | Files | Logical (B) | Allocated (B) | Physical Unique (B) | Shared (B) | Exclusive (B) |
|---|---|---|---|---|---|---|
| bundles | 21,961 | 58,395,979,627 | 58,424,078,336 | 58,209,789,041 | 1,500,917,539 | 56,708,871,502 |
| eaf1 | 29,496 | 70,602,312,844 | 70,659,891,200 | 70,602,312,844 | 0 | 70,602,312,844 |
| eabf4 | 764 | 66,018,133,291 | 66,019,692,544 | 66,018,133,291 | 0 | 66,018,133,291 |
| steamf1 | 29,429 | 69,955,416,488 | 70,012,891,136 | 69,955,416,488 | 0 | 69,955,416,488 |
| prefix | 9,833 | 26,145,360,871 | 26,168,983,552 | 26,138,793,946 | 0 | 26,138,793,946 |
| store | 23,111 | 15,847,645,388 | 15,902,126,080 | 15,847,645,388 | 0 | 15,847,645,388 |
| nfsreloc | 6,720 | 18,049,674,868 | 18,061,053,952 | 18,049,674,868 | 0 | 18,049,674,868 |
| runtimes | 10,765 | 9,006,588,230 | 9,028,968,448 | 4,515,787,649 | 1,501,627,395 | 3,014,160,254 |
| eaunreg | 637 | 34,798,123,073 | 1,225,744,384 | 1,224,439,873 | 0 | 1,224,439,873 |
| ubifc2 | 220 | 4,856,976,946 | 4,857,475,072 | 4,856,976,946 | 0 | 4,856,976,946 |
| workwm | 21,476 | 3,511,334,224 | 3,564,560,384 | 3,511,334,224 | 1,499,691,379 | 2,011,642,845 |
| workfp | 22,201 | 3,571,995,054 | 3,626,598,400 | 3,571,995,054 | 1,501,048,883 | 2,070,946,171 |
| workdx | 2,480 | 1,523,184,209 | 1,528,745,984 | 1,523,068,914 | 0 | 1,523,068,914 |
| downloads | 6 | 525,711,379 | 525,721,600 | 525,711,379 | 0 | 525,711,379 |
| preserve | 30 | 1,987,815,989 | 1,987,866,624 | 1,987,815,989 | 0 | 1,987,815,989 |
| bmanifests | 2 | 1,159,529 | 1,163,264 | 1,159,529 | 0 | 1,159,529 |
| scratch | 34 | 6,322,171 | 6,385,664 | 6,322,171 | 0 | 6,322,171 |
| steamgames | 24 | 1,706,449 | 1,769,472 | 1,706,449 | 0 | 1,706,449 |

**Cross-tree clone sharing (ExT2):**
- bundles ↔ runtimes: 1,500,917,539 B shared
- bundles ↔ workwm: 1,499,691,379 B shared
- bundles ↔ workfp: 1,500,339,027 B shared

Runtimes are Wine prefixes in use by EA/game launchers and test baselines; not deleted.

## 4. Duplicates Identified

All figures are from cache-based `compare` (not deletion evidence; fresh re-hash done in dry-run).

### Store Backups vs. Bundles/Ubisoft Library

| Source (A) | Against | Files | Matched Files | Matched Bytes | % of A Covered | Kept in A | Reclaimable (B) | Action |
|---|---|---|---|---|---|---|---|---|
| Store/cod4 | Bundles | 176 | 145 | 6,648,888,255 | 99.41% | 30 files 39.7 MB | 6.6 GB | Delete 146 files (verified) |
| Store/farcry2 | Bundles + ubifc2 | 94 | 76 + 43 | 3,535,518,982 | 92.84% | 16 files 272.7 MB | 3.5 GB | Delete 78 files (verified) |
| Store/nfs-mw | Bundles | 1,458 | 1,336 | 3,037,953,042 | 97.39% | 35 files 81.4 MB | 3.0 GB | Delete 1,423 files (verified) |
| Store/morrowind | Any | 21,381 | 0 | 0 | 0% | 21,381 files 2.2 GB | 0 | Keep (only copy) |

Residuals in kept files: Store/cod4 retains user save SVGs (about 2.9–3.5 MB each), cod.bmp, 7za.exe, console.log. Store/farcry2 retains installer temp (261.7 MB), manual, uninstallers, mtld3d logs. Store/nfs-mw retains d3d wrappers, shader cache, mtld3d logs (48.2 MB large).

### EA Unregistered Battlefield 4

Path: `/Volumes/ExT2/GameHub/Library/EA-unregistered/Battlefield 4`

- Files: 636 (632 are `*_DiP_Staged` sparse placeholders + 4 `.DS_Store`)
- Logical: 34,798,116,925 B (34.8 GB)
- Allocated: 1,225,736,192 B (1.2 GB)
- Content match vs. EA Games/BF4: 0% at same paths (relpath match yields 0 files)
- Status: **HELD for user decision** (see section 9, item 4)
- Reclaimable if deleted: ~1.2 GB

Caveat: Recipe drafts in `GameHub/docs/bf4-tools/bf4-recipe-*.json` cite `/Volumes/ExT2/EA Games/Battlefield 4/__Installer/installerdata.xml_DiP_Staged` as a source. If drafts are discarded or repointed to the registered EA Games copy, this tree can be deleted.

### Internal Disk: BF3 Old Prefix

Path: `~/Library/Application Support/BF3Mac/Data/Prefix.internal-old-20261010`

- Files: 8,536 (3 symlinks)
- Logical: 24,904,076,789 B (24.9 GB)
- vs. Shared prefix (/Volumes/ExT2/GameHub/Prefix):
  - 1,872 files under drive_c/Program Files/EA Games/Battlefield 3: 100% identical by relpath (fresh re-hash before deletion)
  - 6,367 other files identical
  - 293 superseded files (registry user.reg/system.reg, EA Desktop logs and CEF cache, PunkBuster binaries, old single-player checkpoints PROF_SAVE_body and meta.xml; live copies newer)
  - 4 orphans (EA Desktop CEF browser-cache/storage files absent from live prefix)
- User-data-at-risk rule: no superseded file under Documents/Saved Games/AppData or registry is newer or larger in old copy; cleared for deletion
- **Action: DELETED per user step-4 rule** (authorised deletion, ground truth verified immediately before execution via delete_verified.py)
- Freed: 24.9 GB on internal disk

### Internal Disk: NFS Old Prefix

Path: `~/Library/Application Support/NFS2015Mac/Data/Prefix.internal-old-20261010`

- Files: 6,720
- Logical: 18,049,674,868 B (18.0 GB)
- vs. Relocated prefix (Volumes/ExT2/GameHub/Prefix.relocated):
  - 6,699 files 100% identical by content
  - 144 game files 100% identical by relpath
  - 2 files (12.3 KB) differ
- Status: **KEEP until NFS has been run once from relocated prefix**
  - Newest relocated file: 2026-10-10 00:26 UTC (no run since move)
  - Will delete after first launch to confirm relocated prefix is functional
- Reclaimable later: 18.0 GB

### Internal Disk: NFS StagedUpdate

Path: `~/Library/Application Support/NFS2015Mac/Data/StagedUpdate-aside-20261008` (internal)

- Files: 967
- Logical: 893,412,645 B (0.9 GB)
- Matches: 963 in bundles (70.51%), 827 in relocated prefix (14.51%)
- Status: **KEEP** (paired with nfsold; same retention rule)
- Reclaimable later: 0.9 GB

### F1 24: EA Games vs. Steam

EA copy: `/Volumes/ExT2/GameHub/EA Games/BF4/F1 24` (29,496 files, 70.6 GB)

Steam copy: `~/Library/Steam/steamapps/common/F1 24` (29,429 files, 70.0 GB)

- 29,386 files (98.24% of EA copy) identical in content
- 29,362 files identical at relpath
- No shared blocks (separate volumes)
- EA copy unique: 110 files 1.2 GB (root 16 files 1.1 GB, __Installer 57 files 82 MB)
- Steam copy unique: 49 files 750 MB
- Status: **NEITHER DELETED** (user decision pending; see section 9, item 1)
- Caveat: EA install does not run under Wine (EA AntiCheat service crashes); Steam copy also requires EA app and AntiCheat, so neither copy is playable as-is. Recommendation: drop EA copy (via EA app Uninstall, not rm); Steam copy is the one that runs if anticheat is ever fixed.

### Other Trees: No Duplicates

- **Preserve** (git bundles, knowledge tarballs, patches): 30 files, 1 of 30 matches bundles (896 B); keep (unique knowledge)
- **Manifests, deleted-20261010.log**: logs/metadata; keep
- **Downloads**: 6 files 525.7 MB, only .bak is MANIFEST.json.bak (1.9 KB, older version); keep
- **Scratch-bf3-native**: 34 files 6.3 MB, no duplicates; keep
- **Steam library** (Library/SteamGames): 6 manifests 1.7 MB, shadercache/temp/workshop empty; no games in steamapps/common; keep (re-registration is a Steam UI action)
- **Work trees** (winemac-fs, dxmt-rtv, wine-fontperf): report only; other agents' areas; newest mtimes 15:22–17:39 today

## 5. What Was Deleted

**Executed deletions** (re-verified immediately before removal via delete_verified.py; path form validation, no symlinked components, protected/allowed lists checked, reference grep of 59 launcher/record files, not in use via lsof/ps, fresh SHA256 of both file and counterpart, symlink-race-safe via parent directory fd):

Batch 1 — Store backups (ExT2):
- Store/cod4: 146 files, 6,648,888,255 B (6.6 GB) — 203 plan entries including cod4, farcry2, nfs-mw directories: 127 directories, 76 single files, totalling 1,647 files and 13,222,360,279 B (13.2 GB); all files SHA256-identical to files in /Volumes/ExT2/Bundles (Call of Duty 4 Bundled, Far Cry 2 Bundled, Most Wanted Bundled) or Ubisoft library Far Cry 2; 203 entries DELETED, 0 skipped, exit 0; `df` ExT2 available increased by 13,222,084,608 B, matching logical bytes; plan-20261011.tsv sha256 dcdabe5bfffd62027ca071281259a9a358443c6bd31d05fc99e5d8464e021e6b, run with --only for 203 dup lines. Independent verifier re-hashed 15 random files and bundle counterparts: all identical.

Batch 2 — BF3 old prefix (internal disk):
- BF3 old: 8,536 files, 24,904,076,789 B (24.9 GB), 3 symlinks; class superseded-prefix (user's step-4 rule); 1,872 game files 100% identical at relpath to shared prefix, 6,367 others identical, 293 superseded (registry, logs, PunkBuster, checkpoints; live copies newer), 4 orphans (CEF cache); DELETED, exit 0; `df` internal Data available increased by 24,339,504 KiB = 24,923,652,096 B (24.9 GB); plan-bf3-20261011-v3.tsv sha256 d4d0a642c8370dff0deb6bc49ac4127710e4811d8c1d35aa1463ef4bf7c67df6, orphans sha256 2a86df8e99358a853b29953c8d8e162442dccc9b451cbac150eb9041c52c1874. Two earlier attempts refused without deleting (running EA session rewrote cache); final recheck narrowed to game-file counterparts verified exactly, other successor files re-evaluated against user-data rule. Deletion log: `/Volumes/ExT2/GameHub/docs/dedupe-actions-20261011.log`

**Totals freed:** ExT2 13.2 GB (12,912,192 KiB by df); internal disk 24.9 GB (24,339,504 KiB by df). ExT2 free space at session end is 45.3 GB (45,309,768 KB) due to concurrent EA and other agents' work consuming space during the session.

## 6. Kept, and Why

| Tree | Files | Bytes | Reason |
|---|---|---|---|
| Store/cod4 | 30 | 39,745,099 | Player saves (SVGs), game bmp, mod exe, logs |
| Store/farcry2 | 16 | 272,732,054 | Installer temp (261.7 MB), manual, uninstallers, mtld3d logs |
| Store/nfs-mw | 35 | 81,438,267 | D3D wrappers, shader cache, mtld3d logs |
| Store/morrowind | 21,381 | 2,231,363,218 | Only copy; unique game content |
| Bundles | — | — | Keeper tree; no deletions |
| Prefix (shared) | — | — | Keeper tree; no deletions |
| Nfsreloc (relocated) | — | — | Keeper tree; no deletions |
| Ubifc2 (Ubisoft) | — | — | Keeper tree; no deletions |
| Eabf4 (BF4 registered) | — | — | Keeper tree; no deletions |
| Preserve (git/patches) | 30 | 1,987,815,989 | Knowledge backup; unique |
| Bmanifests (logs) | 2 | 1,159,529 | Metadata; keep |
| Downloads (6 files) | 6 | 525,711,379 | Manifest cache, unique; keep |
| Scratch-bf3-native | 34 | 6,322,171 | Test data; keep |
| Steamgames (manifests) | 24 | 1,706,449 | Manifests; keep (re-register via Steam UI) |
| NFS old prefix | 6,720 | 18,049,674,868 | Hold until relocated runs once |
| NFS StagedUpdate | 967 | 893,412,645 | Paired with nfsold; hold same |
| F1 24 EA copy | 29,496 | 70,602,312,844 | Hold pending user decision |
| F1 24 Steam copy | 29,429 | 69,955,416,488 | Hold pending user decision |
| Runtimes (Wine) | 10,765 | 9,006,588,230 | Active (EA) and test baselines; in use |
| Work trees (wm/dx/fp) | 46,157 | 8,606,513,487 | Other agents' areas; report only |

## 7. Dedupe-by-Clone (Not Executed; Report Only)

APFS clone deduplication (via `cp -c`) within ExT2 can free space without removing either tree. Cloning is reversible per-block if either copy is edited; launcher verification passes since byte content is identical.

| Pair | Est. Freed (GB) | Precondition |
|---|---|---|
| F1 24 EA ↔ Steam | ~69.2 | Stop EA app and Steam; EA install cannot run anyway |
| Bundles BF3 → Shared Prefix BF3 folder | ~21.4 | Stop EA/wineserver; bundle is read-only source |
| Bundles NFS → Relocated Prefix NFS folder | ~14.6 | Stop NFS; await NFS-to-EA import work ownership |
| wine-0010 ↔ hub-0, wine-0011 ↔ hub-0 | ~3.0 | Test baselines; requires owner sign-off |
| Work prefixes (winemac-fs, dxmt-rtv, wine-fontperf) | ~2.9 | Other agents' areas; requires owner sign-off |

**Total clone-dedupe potential: ~111 GB**

Cross-volume clones (internal disk ↔ ExT2) are not possible on APFS.

## 8. Free Space Before/After

**ExT2 volume:**
- Morning: ~149 GB free
- Before work started: 44.2 GB free (44,162,744 KB)
- Before deletions: 33.4 GB free (33,426,088 KB) — concurrent EA Desktop/F1 24 growth consumed ~11 GB
- After Store batch deletion: 46.2 GB free (46,241,300 KB); df delta 12,912,192 KiB = 13,222,084,608 B, matching logical bytes deleted
- Session end: 45.3 GB free (45,309,768 KB) — concurrent writers (EA, other agents) consumed space during session

**Internal disk (Data):**
- Before BF3 deletion: 58.7 GB free (58,721,288 KB)
- After BF3 deletion: 83.1 GB free (83,060,792 KB); df delta 24,339,504 KiB = 24,904,076,789 B

**Note:** df deltas are measured immediately post-deletion via delete_verified.py; they reflect logical byte counts and confirm no shared blocks remain. Concurrent writers (EA app, other agents' work) consumed additional space during the session, so ExT2 free space dropped from 46.2 GB back to 45.3 GB by session end.

## 9. Decisions Needed from User

1. **F1 24: Which copy to keep?**
   - **Recommendation:** Drop EA copy (via EA app Uninstall, not rm) and keep Steam copy.
   - **Rationale:** EA install does not run (EA AntiCheat crashes under Wine); Steam copy is the one that would work if anticheat is fixed. Caveat: Steam copy has no appmanifest (Steam does not list it); re-register via "install to existing folder."
   - **Alternative:** Keep both and clone-dedupe (~69.2 GB freed, but without gameplay fix).
   - **Reclaimable:** 1.2 GB (EA unique files) if EA copy is dropped.

2. **Dedupe-by-clone timing:**
   - Is clone deduplication acceptable (~111 GB potential)?
   - When can the EA session be stopped (F1 24 ↔ Steam, Bundles ↔ Prefixes)?

3. **NFS internal copies (18.0 GB + 0.9 GB):**
   - Delete `Prefix.internal-old-20261010` and `StagedUpdate-aside-20261008` only after NFS has been launched once from the relocated prefix on ExT2.
   - Confirm relocated folder location before deletion.

4. **EA-unregistered Battlefield 4 (1.2 GB allocated):**
   - Repoint the recipe drafts in `/Volumes/ExT2/GameHub/docs/bf4-tools/` to the registered BF4 at `/Volumes/ExT2/GameHub/EA Games/BF4/Battlefield 4/__Installer/installerdata.xml` (if the source is still needed).
   - If recipes may lose that source, confirm deletion is acceptable.
   - Once repointed or confirmed safe, delete via `ea-staged-stub` plan line (line 216 of plan-20261011.tsv; dry run already OK).

5. **Store-20261008 residual (2.6 GB kept):**
   - Morrowind (2.23 GB): only copy; unique game content, kept permanently.
   - Cod4, farcry2, nfs-mw residuals (81 unique small files, 0.37 GB): player saves (Call of Duty 4 SVG saves), installer temp, manuals, uninstallers, d3d wrappers, shader cache, mtld3d logs. All kept alongside their store trees to preserve user data and metadata.
   - **Decision:** Can the residual metadata (manuals, uninstallers, shader cache, logs) be deleted? Or should they stay as historical archives with the store trees?

## 10. Files: Tool, Database, Plans, Logs

**Scripts (reviewed twice by independent reviewer; used in deduplication and deletion):**
- **dedupe.py:** `/Volumes/ExT2/GameHub/work/dedupe-20261011T1641/dedupe.py` (read-only; resumable; generates database and plan)
- **delete_verified.py:** deletion tool (re-verifies each entry before removal: path form, no symlinked components, protected/allowed lists, reference grep of 59 launcher/record files, not in use via lsof/ps, fresh SHA256 of both sides, counterpart exists in kept tree, final recheck, symlink-race-safe deletion via parent directory fd; used for Batches 1 and 2)

**Database & analysis:**
- **Inventory cache:** `/Volumes/ExT2/GameHub/work/dedupe-20261011T1641/inventory.sqlite` (SHA256 cache; WAL mode not supported by sqlite3 -readonly)
- **Compare output:** `/Volumes/ExT2/GameHub/work/dedupe-20261011T1641/compares-summary.txt`, `out-compares.txt`, `out-compares3.txt` (cache-based; ground truth at deletion time)
- **Physical extents:** `phys-ext2.json`, `phys-internal.json`, `phys-runtimes.json` (APFS extent maps and clone analysis)

**Plans & execution records:**
- **Store batch plan:** `/Volumes/ExT2/GameHub/work/dedupe-20261011T1641/plan-20261011.tsv` (203 entries; run with --only for dup lines); executed; sha256 dcdabe5bfffd62027ca071281259a9a358443c6bd31d05fc99e5d8464e021e6b; output `out-exec-store.txt`
- **BF3 batch plan:** `plan-bf3-20261011-v3.tsv` (executed; sha256 d4d0a642c8370dff0deb6bc49ac4127710e4811d8c1d35aa1463ef4bf7c67df6); output `out-exec-bf3-3.txt`
- **BF3 orphans list:** `orphans-bf3old-v3.tsv` (sha256 2a86df8e99358a853b29953c8d8e162442dccc9b451cbac150eb9041c52c1874)
- **BF3 plan generator:** `mkplan-bf3-v3.py` (in work/dedupe-20261011T1641)

**Residuals & metadata:**
- **Store residuals:** `store-residual-paths.txt` (paths kept in each Store tree)
- **BF3 residuals & orphans:** `bf3old-residual.tsv`, `orphans-bf3old-v3.tsv` (superseded files and absent counterparts)
- **Launcher reference grep:** `refs-files.txt` (59 launcher and record files checked for references; none matched deleted paths)

**Deletion log:**
- **Execution log:** `/Volumes/ExT2/GameHub/docs/dedupe-actions-20261011.log` (Store and BF3 batch execution, timestamps, verification notes, exit codes)

---

**Report perspective:** Deduplication executed in two batches (Store and BF3) with all figures traced to execution logs and immediate post-deletion verification. Items held pending user decision appear in section 9; all factual claims in sections 1-8 are verified through deletion logs, `df` measurement, and independent hash validation.
