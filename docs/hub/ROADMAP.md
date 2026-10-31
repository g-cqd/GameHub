# GameHub roadmap

Status: 2026-10-31. This is the single list of open work across the hub, Wine, DXMT, mtld3d and x87sidecar. Each item
links its evidence. Order is priority. When an item is done, delete it here and put the result in the doc it concerns.

## 1. Runtime consolidation on hub-2
Every provider defaults to hub-2 since commit b2455c8 (`PROVIDER_RUNTIME`). The earlier defaults (hub-1 for EA, Ubisoft,
Epic and direct games) are still available with `--runtime hub-1`.
- **EA on hub-2:** `hub start ea` timed out at 150 s waiting for "SPA load success". This was with Steam, Ubisoft and
  downloads running, and about 6 of 7 GB of swap in use; EA booted in about 6 s on hub-1. Retest with nothing else
  running, then read `Hub/Logs/ea-*.log` and `Prefix/drive_c/ProgramData/EA Desktop/Logs/EADesktop.log`. The only
  lead so far: `WSALookupServiceBegin failed with: 0` (`network_change_notifier_win.cc`).
- **Epic on hub-2:** untested. `hub trim epic` is untested too.
- **Delete `Runtimes/hub-1`** only after EA and Epic pass on hub-2. hub-1 is not needed to assemble new runtimes:
  `assemble_runtime.sh` takes `compatdb.so` and `lib/external` from `OLD_RT`, which now defaults to hub-2.
- Remove `bin/hubenv.sh` and `bin/start-steam.sh` on ExT2.

## 2. Steam library (handoff 2026-10-31)
- **Manifests:** HITMAN 3 (1659040) and Crysis Remastered (1715130) were restored from the old `Library/SteamGames`
  library. Wolfenstein II (612880) got a hand-written manifest; Steam rewrote it (build 3329064, 52 GB on disk,
  245 files replaced) and lists it as Fully Installed.
- **Not yet launched:** none of the three has been started. Crysis Remastered has no `content_log.txt` lines yet, so
  check that Steam shows it as installed.
- **Halo MCC (976730):** the install is partial (16 GB, with empty `halo1`, `halo2` and `halo3`). It needs a reinstall
  from Steam, which needs disk space (section 6).
- **Steam overlay:** `hub doctor` fails "Steam overlay disabled". The 64-bit client put `GameOverlayRenderer*.dll` and
  `gameoverlayui64.exe` back while it ran; `prep_steam()` only moves them at start, and its list doesn't cover
  `SteamOverlayVulkanLayer*`. Make the step run before every game launch as well, or use a mechanism the client
  doesn't undo. The overlay crashes Act of Aggression after its intro.
- **To test:** Rise of Nations, Generals and Zero Hour. A game launched through the 64-bit client is still untested.
- **Unity "Zero Hour" and Rise of Nations:** Steam uninstalled both on 2026-10-30. Reinstall to test them.
- **Cleanup, after the three games are verified:**
  - `Library/SteamGames` (1.7 MB): keep its six manifests and the Rise of Nations workshop items until then. The
    symlink `/Volumes/ExT2/SteamGames` points to it.
  - `Library/Steam-legacy` (1.1 GB): the rollback to the 32-bit client.

## 3. Ubisoft Connect (handoff 2026-10-31)
- **Install directories registered:** registry install-dir values (32-bit view) were written for:
  - AC Unity: `Installs\720`
  - Far Cry 2: `UBISOFT\Far Cry 2`
  - Far Cry 3: `UBISOFT\Far Cry 3`
  - Watch Dogs 2: `Ubisoft\WatchDogs2`

  The registry backups are `Prefix/{system,user}.reg.bak-20261031-register-libraries`. Only Far Cry 3's path is
  confirmed in the UI. The value names come from `register:` entries in
  `Library/Ubisoft/cache/configuration/configurations`. Move this registration into the hub, so a fresh prefix gets
  it, instead of an ad-hoc `.reg` file.
- **Far Cry 3, Play:** fails with `HKCU\SOFTWARE\UBISOFT\Far Cry 3\ExecutableName` missing. The key is under HKCU, not
  HKLM. `FC3Updater.exe -write_registry` should write it, but it crashes in `FC3.dll` (null read near +0x1eb1).
  - First try `hub play "Far Cry 3"` (`bin/farcry3_d3d11.exe`), which goes around Connect.
  - Then fix the updater crash with `--debug`, or write `ExecutableName` and `StartArguments` from the config.
- **Far Cry 3, Verify:** fails with `VerifyGame.cpp (135) UplayService generic failure`.
- **Far Cry 3, download:** "Failed to start download" comes from a 404 on Ubisoft's CDN
  (`uplaypc/downloads/46/latest.txt`). This is server-side and we can't fix it.
- **`GameCatalogExtensionRegistration.cpp (571) Error: 5`:** access denied, in every session since 2026-10-24 (hub-1
  and hub-2).
- **Other games:** check Play or Install for Far Cry 2, AC Unity and Watch Dogs 2.
- **"Connection issues":** reported, never seen. The Wine logs have no DNS, TLS or timeout errors. Capture the
  message, then compare it with `Library/Ubisoft/logs/{launcher_log,service_log}.txt`.
- **Heaven's-gate selector fixup and ARPL** for the 32-bit Ubisoft games (Wine 73516bb, x87sidecar dbda79a): not yet
  confirmed in a game.

## 4. Games
- **Watch_Dogs:**
  - The Bad Blood DLC has no dialogue. Next steps: the per-stream format log in `unix_create_stream` (uncommitted in
    the Wine tree), then the loaded DLLs after the DLC loads.
  - Crackling audio.
  - Flashing screen and textures. This is not the staging allocator.
  - winecoreaudio's channel layout always fails (-10851, `kAudioChannelLayoutTag_UseChannelBitmap` on AUHAL).
- **GTA V** (`gtav-graphics.md`): DX11 `itrproj` failure, crash at MSAA 8x, texture streaming and swaps,
  magenta/white artifacts.
- **Crysis 3:** performance; the tessellation factor 8 clamp; the 32-bit rename budget stall.
- **Battlefield 3 on hub-2:** tessellation pipeline signature mismatch; it sets the display mode 8 times.
- **Act of Aggression:** settings bisect and a MetalFX preset.
- **Unity "Zero Hour":** an uncommitted MetalFX rule in `runtime/hub-rules.txt` (`zero-hour-metalfx`). Commit it once
  the game is reinstalled and tested.
- **EAAC / F1 24:** E111000D is unresolved and the syscall gate fails (`docs/eaac/EAAC-IMPLEMENTATION-ROADMAP.md`).

## 5. Platform: Wine, DXMT, mtld3d, x87sidecar
- **Fullscreen:**
  - DXMT's cached HMONITOR goes stale ("Failed to query monitor info", "EnterFullscreenMode: Cannot query
    containing output").
  - winemac's Enter→fullscreen quirk.
- **Activation:** games started by Steam don't become the active macOS app. The handoff helper works
  (`/tmp/kusd/handoff.swift`); move it into the hub.
- **Audio:** winecoreaudio should follow changes of the macOS default output device (`DefaultOutput` unit or a
  property listener).
- **Display:** winemac should report the native 3840x2160 instead of the 5120x2880 HiDPI backing store. The launcher
  now reads the native size from the main display's native mode (b2455c8).
- **Input:** MX Master 4 buttons 5 and up, and `SM_MOUSEHORIZONTALWHEELPRESENT` (`mx-master-4.md`).
- **Rules layer:** move the per-exe logic left in `compat_db()`/`session_env()` into `runtime/hub-rules.txt`, and add
  tests for the BOOLEAN low-byte syscall read.
- **DXMT:**
  - Keep one base ring instead of creating and dropping rings.
  - The finishing thread spins in `atomic::wait`.
  - Border colour falls back to opaque white.
- **mtld3d:** the D3D8/9 gaps (`docs/knowledge/mtld3d-x87.md`).
- **x87sidecar:** allocation and performance work.
- **Bundler:** CoD4 release gates and the adapter contract (`apps/bundler/docs/`).

## 6. Machine and housekeeping
- **ExT2 is 99% full** (16 GB free of 932 GB), and swap reaches about 6 of 7 GB with several launchers open. Both
  block reinstalls (Halo MCC) and make timing tests unreliable (EA). Free space before any big download.
- **Delete:**
  - The probe copies in the prefix's `C:\`: pcs, dbch, wins, pcsall, dump, dienum, dipad, fmt, center, loop.bin.
  - `/tmp/dxmt-base`.
  - The handoff's scratch files: `/tmp/ubi-register.reg`, `/tmp/wh2.py`, and `/tmp/screen*.png`. The screenshots
    show other apps on the desktop.
  - `Backups/prefix-pre-merge-20261022`, once the owner agrees.
- **Shutdown:** `hub stop` kills the whole prefix (`wineserver -k`), so Steam never shuts down cleanly. Add a polite
  `steam.exe -shutdown` run with the session environment, and wait for it before the kill.
- **Concurrent agents:** two agents committing in the same tree at once mixed one agent's uncommitted edits into the
  other's commit. That is how the hub-2 defaults landed in b2455c8. Only one agent should commit at a time.
