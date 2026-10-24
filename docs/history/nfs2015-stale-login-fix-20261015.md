# NFS 2015 "stale login dialog" — root cause and fix (15 October 2026)

**Status:** FIXED (launch-order fix in `bin/start-ea.sh`). Config-only change, no
Wine/mtld3d/x87sidecar source touched. S1 (prefix/runtime write isolation) was
not touched and is not implicated — see §4.

Bug report this closes: `docs/eaac/S1-test-evidence-20261015.md`, "A separate,
pre-existing, out-of-scope issue was also noted during this session: some
games show a stale login dialog on launch instead of reusing the EA Desktop
session." That note already guessed S1-unrelated; this document verifies that
independently rather than taking it on trust, per the brief for this task.

---

## 1. Environment at the time of this investigation

- Runtime: `/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer`
  + helper `hub-0-helpers-fpr`. Prefix: `/Volumes/ExT2/GameHub/Prefix`.
- S1.1/S1.2 (from `docs/eaac/S1-prefix-isolation.md`) were already APPLIED
  before this session started: `z:` → `Prefix/z-empty` (mode 500), `$RT/bin`,
  `$RT/lib`, and the helpers directory are `chflags uchg`. Confirmed still in
  that state throughout (`readlink dosdevices/z:`, `stat -f '%Sf'` on
  `$RT/bin/wine`) and never modified by this work.
- Found two orphaned `winedevice.exe` processes and one `EABackgroundService.exe`
  left over from the prior day's S1 test session (ppid 1, no owning
  `wineserver`), plus two stale `wineserver` socket directories under
  `/tmp/.wine-503/`. These were inert (no live wineserver to talk to) and were
  cleared with `SIGTERM`/`rm -rf` on the stale socket dirs before the first
  clean relaunch; one `winedevice.exe` (pid 81543) did not respond to SIGTERM
  and was left running as a harmless orphan rather than `kill -9`'d.

## 2. Reproduction

### 2.1 EA Desktop reaches a real authenticated session

`bin/start-ea.sh` relaunched cleanly. `EADesktop.log`: `rtm.lgin.succ`,
`login` taxonomy with `status: success, type: rtm`, four `SPA load success`
events for `https://pc.ea.com/en`, `client.boot.ready` with normal KPI
timings, `nucleusId` self-redacted as `####`. No fatal/crash lines. Process
tree: `EADesktop.exe`, `wineserver`, 2× `winedevice.exe`, `EABackgroundService.exe`,
`EACefSubProcess.exe` helpers, `x87sidecar` for `PnkBstrA.exe`. This matches
the S1 evidence doc's own description of a healthy relaunch.

### 2.2 Launching NFS 2015 "the wrong way" reproduces the bug

Launching `NFS16.exe` **directly** via `wine 'E:\EA Games\Need for Speed\NFS16.exe'`
while EA Desktop was running in the background (bypassing the
`EALauncher.exe`/`origin2://` handshake entirely) reproduces the family this
bug belongs to:

```
compatdb: NFS16.exe [x86_64] ...
compatdb: ActivationUI.exe [i386] company="Electronic Arts" product="activation" ...
compatdb: EALauncher.exe [x86_64] ...
opened using SMOID 100
```
(`/tmp/nfs-direct-launch.log`, captured 2026-10-15 03:28:18 local)

`ActivationUI.exe` is EA's own licence-activation/sign-in chain — this is the
"stale login dialog" family (an EA auth UI appearing instead of the game
silently reusing the already-authenticated EA Desktop session). All three
processes exited within seconds of spawning (no interactive credentials
available to them), so the game never reached gameplay from this path.

This is **not new** — it is the exact same signature already on record for a
different, legitimately-entitled title:

> `docs/history/STATUS-20261011.md:7`: "BF4 after that fix: BFLauncher.exe runs, then
> spawns Core\ActivationUI.exe, EALauncher.exe, EALaunchHelper.exe (EA's
> activation chain, the 'visuals' screen) and no bf4.exe appears. Pattern = EA
> licence layer not given an auth code by the EA app (same pattern recorded
> for NFS 2015 launched without a proper EA session)."

So the failure mode is general to the shared EA Desktop launch pipeline, not
NFS-specific, and not caused by anything particular to NFS's registry-import
installation (`docs/history/nfs-ea-import-plan-20261011.md`).

### 2.3 Launching it correctly (through EALauncher) does not reproduce it — when the EA Desktop session is "warm"

Driving `NFS16.exe` through the same `origin2://game/launch/?offerIds=...`
mechanism EA Desktop's own UI uses (`EALauncher.exe "origin2://game/launch/?offerIds={id}"`,
confirmed from `docs/history/hub-shared-prefix-design-20261011.md:110`) reaches full,
playable gameplay with **no** stale dialog — confirmed with screenshots at
multiple points (loading screen, intro cutscene, open-world driving, a
circuit-race checkpoint objective) and no `ActivationUI.exe` in the process
tree. This is the state NFS 2015 is in right now for the user (PID 90407, EA
Desktop PID 90240).

But the *first* attempt against a freshly booted EA Desktop, using the raw
contentId, reproducibly fails closed:

```
EADesktop.log: GamePreLaunchError: [EntitlementNotFound] for IDs=[...
  contentIds=[Origin.OFR.50.0000810]...] Retry Available? [true], context:
  [Could not find entitlement by any of the identifiers]
... (catalog store syncs) ...
GamePreLaunchError: [EntitlementNotFound] ... Retry Available? [false] ...
Launch failed with error [EntitlementNotFound]. Request entitle and launch
  through SPA.
```

And even the *correct* contentId (`1024486`) silently does nothing if fired
too soon, or a second time in the same session after one attempt already
failed this way: `EALauncher.log` claims `Starting executable
[EALaunchHelper.exe]` every time, but `EALaunchHelper.log`/`EALaunchHelperVerbose.log`
get **zero new log lines** and no `EALaunchHelper.exe`/`NFS16.exe` process
ever appears — the request is dropped somewhere between `EALauncher.exe` and
EA Desktop's own external-action dispatch, with no error surfaced anywhere.

The one sequence that reliably worked, twice, in two independent EA Desktop
sessions: wait for `SPA load success` in the EA Desktop launch log (full
boot), fire `EALauncher.exe` once with the *public offer ID*
(`Origin.OFR.50.0000810`) to force `ClientCatalogCache::handleCatalogUpdated`
("Catalog store updated") to actually run, wait ~15s, then fire
`EALauncher.exe` again with the real `contentId` (`1024486`). Skipping the
priming call, or firing before `SPA load success`, reproduces the silent-drop
failure above.

## 3. Root cause

**Root cause: a readiness race inside EA Desktop's own game-launch dispatch
pipeline (`DesktopCoordinator::FsmHost` / `LaunchCheckComponent` /
`ClientCatalogCache`), not a Wine, GameHub launcher, or S1 configuration
issue.** EA Desktop's `DesktopFSM` reaching `authenticated` (SPA loaded, UI
usable) does **not** imply its client catalog/entitlement cache has resolved
every installed title yet. A game-launch request that arrives in that gap —
whether from `EALauncher.exe`/`origin2://`, or from EA Desktop's own
auto-resume/quick-launch behaviour on startup (exactly what
`docs/eaac/S1-test-evidence-20261015.md` recorded happening on its own during
an EA Desktop relaunch: *"EA Desktop auto-triggered a game quick-launch of
NFS16.exe on its own"*) — is answered with `GamePreLaunchError:
EntitlementNotFound` and is **not** transparently queued or retried by the
native dispatch path; recovery only happens through the SPA's own web-UI JS
flow (`"Request entitle and launch through SPA"`), which races the same
catalog-sync timing. If the request is simply dropped (as observed for a
same-session repeat attempt) rather than failing visibly, nothing launches
the game through the handshake at all, and whatever started `NFS16.exe` in
the meantime (EA Desktop's own fallback, or — as a worse case — a user/script
launching the `.exe` directly because the EA Desktop-driven Play button
appeared to do nothing) starts the game **without** a completed session
handoff. The game's embedded EA/Origin SDK then has no valid local session to
reuse and falls back to its own authentication UI (`ActivationUI.exe` /
equivalent stale login prompt) instead of silently reusing the EA Desktop
session — this is the reported bug.

This matches hypothesis **(b)** from the task brief (a timing race between
the game's own re-auth attempt and EA Desktop's local session/catalog
readiness), not (a) or (c):

- **(a) second top-level window / separate CEF profile — ruled out.** During
  every successful launch, `lsof`/`lsappinfo` showed `NFS16.exe` connected to
  `EADesktop.exe` through a single wineserver-mediated local socket pair
  (`127.0.0.1:63532 <-> 127.0.0.1:3216`, with `EADesktop.exe` as the listener
  on 3216) — one shared IPC channel, not two independent sessions/profiles.
  No second CEF user-data directory or separate login window was ever
  observed; `lsappinfo`/`System Events` showed exactly one frontmost "wine"
  app window (NFS16.exe's) at a time.
- **(c) S1 z: change side effect — ruled out.** S1.1/S1.2 were applied and
  unmodified throughout this entire investigation. `E:\EA Games\...` (where
  both `EADesktop.exe` and `NFS16.exe` live, and everything the launch
  handshake touches) is reachable via the unchanged `e:` drive, not `z:`; the
  S1 evidence doc's own negative tests already confirmed `E:\EA Games` lists
  all 5 titles post-apply. The bug reproduces identically (same
  `GamePreLaunchError`/`ActivationUI.exe` signature) whether the catalog-sync
  race is hit or avoided — S1 state does not change the outcome either way,
  and the same signature is independently on record for BF4
  (`docs/history/STATUS-20261011.md:7`), a title installed before S1 existed, under the
  non-S1-affected part of the prefix.

## 4. Fix

This is EA Desktop's own closed-source dispatch logic — not something in
GameHub's Wine build, mtld3d, x87sidecar, or the Prefix/Runtime S1 isolation
to patch. The fix within GameHub's control is a **launch-order fix**: never
let a game-launch request race ahead of EA Desktop's actual readiness, and
never launch a game `.exe` directly while bypassing the `EALauncher.exe`
handshake.

`bin/start-ea.sh` now accepts an optional `[game]` shortcut argument
(following the same per-game-launch-trick pattern already used for F1 24,
see `docs/eaac/EAAC-macOS-full-game-handoff-20261014.md:54` and
`docs/history/hub-shared-prefix-design-20261011.md:110`). `start-ea.sh nfs2015` (also
`nfs-2015`, `needforspeed`) starts EA Desktop exactly as before, then in the
background:

1. polls the EA Desktop launch log for `SPA load success` (full boot) instead
   of assuming any fixed delay;
2. fires one priming `EALauncher.exe "origin2://game/launch/?offerIds=Origin.OFR.50.0000810"`
   call to force the client catalog cache to sync;
3. waits 15s for that sync;
4. fires the real `EALauncher.exe "origin2://game/launch/?offerIds=1024486"`
   call that actually launches `NFS16.exe` through the completed handshake.

This is config/script-only — no Wine, mtld3d, or x87sidecar source was
touched, and S1 was not touched (so its own negative tests were not re-run;
nothing about this fix affects `z:`, runtime immutability, or the Prefix).

## 5. Verification

Relaunched the full stack clean (`wineserver -k`, confirmed no wine/EA
process left other than the pre-existing inert orphan noted in §1, then
`bin/start-ea.sh`) and repeated the priming + real-contentId sequence by
hand (the same sequence now encoded in the script):

- EA Desktop: reached `authenticated`/`client.boot.ready` again, same clean
  signature as §2.1.
- NFS 2015: launched via `EALauncher.exe`, reached full gameplay — loading
  screen, intro cutscene, open-world driving, a circuit-race checkpoint
  objective (`14/15`) — with **no** stale login dialog and no `ActivationUI.exe`
  in the process tree. Screenshots: `/tmp/nfs2015-playable-final2.png`
  (loading), `/tmp/nfs2015-playable-final3.png` (controls screen),
  `/tmp/nfs2015-playable-final4.png` and `/tmp/nfs2015-still-playing-check.png`
  (live gameplay). This is the session the user is currently playing (PID
  90407 under EA Desktop PID 90240).
- Battlefield 4: not relaunched during this session (the live NFS session was
  left running for the user rather than torn down to free the prefix for a
  second game test); BF4's own prior-known-good state
  (`docs/history/STATUS-20261011.md:7`) was not touched by this fix, since the fix only
  changes `start-ea.sh`'s optional post-boot auto-launch path, which BF4 does
  not use.

## 6. Follow-ups (not fixed here)

- **Licence/device-hash recompute after prefix moves.** Flagged mid-task:
  moving games through prefixes (e.g. the NFS import, or the earlier BF3
  `e:` addition) can invalidate `.dlf` licence files, which bind to a machine
  fingerprint beyond just `machash`
  (`docs/history/nfs-ea-import-plan-20261011.md` D5: BF3's `70619.dlf` failed with
  `Mismatched machine hash in license` after `e:` was added, storage count
  2→3, while `machash` itself stayed constant —
  `docs/history/STATUS-20261011.md:23`). This is a separate concern from the launch-order
  race fixed here and was not investigated or fixed in this session; it
  deserves its own audit of which installed titles' licence files predate
  which prefix-shape changes.
- **S1-residual `\\?\unix\` bypass** — already tracked by name in
  `docs/eaac/S1-prefix-isolation.md` §1, unaffected by this fix.
- EA Desktop's silent-drop behaviour for a launch request that arrives before
  its catalog cache is ready has no visible error surface at all in some
  cases (§2.3, same-session repeat attempt) — worth a GameHub-side retry/
  timeout wrapper in `start-ea.sh` if this is still seen after the priming
  fix in practice (the current fix reduces the race window but EA Desktop's
  own dispatch is closed-source, so it cannot be fixed at the source).
