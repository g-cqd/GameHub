---
status: in-progress
blocked-by: []
date: 2026-10-31
---

# 0020: Free space on ExT2, and remove scratch and superseded files

ExT2 has 16 GB free of 932 GB, and swap reaches 6 of 7 GB with several launchers open.

## Delete
- **Prefix `C:\` probes:** pcs, dbch, wins, pcsall, dump, dienum, dipad, fmt, center, `loop.bin`.
- **Scratch in `/tmp`:**
  - `/tmp/dxmt-base`;
  - `/tmp/ubi-register.reg` and `/tmp/wh2.py`;
  - `/tmp/screen*.png`. These show other apps on the owner's desktop, so delete them first.
- **Old scripts on ExT2:** `bin/hubenv.sh` and `bin/start-steam.sh`.
- **With the owner's agreement:**
  - `Backups/prefix-pre-merge-20261022`;
  - `Library/Steam-legacy` (1.1 GB);
  - `Library/SteamGames` (1.7 MB), keeping its six manifests and the Rise of Nations workshop items until roadmap 0006
    passes. Remove the `/Volumes/ExT2/SteamGames` symlink with it.

## Done when
These are gone and ExT2 has room for the Halo MCC reinstall.

## Progress (2026-10-31)
**Deleted:**
- The ten probe copies in the prefix's `C:\`.
- In `/tmp`: `/tmp/dxmt-base`, `/tmp/kusd` (its sources are kept in `archive/probes/20261031-activation-input-display/`),
  `/tmp/ubi-register.reg` (its values are in roadmap 0008), `/tmp/wh2.py`, the `/tmp/screen*.png` screenshots, and
  the review's `/tmp/review`.
- `bin/hubenv.sh` and `bin/start-steam.sh` on ExT2, copied first to `archive/work/ext2-bin-20261031/`.

**Left for the owner to decide** (`C:\` files from earlier sessions):
- `bf3-rtv.log` (19 MB, from the removed BF3 d3d11 proxy);
- `click_eaac.exe`, `mtest17.exe`, `replay.exe`, `wguest.exe`, `winspy.exe`;
- `epic_install.log`;
- the `eaanticheat` folder.

The backups and `Library/Steam-legacy` and `Library/SteamGames` also need the owner's agreement, as above.

