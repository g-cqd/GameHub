# macOS system fonts in the shared prefix break every CEF/GUI app

Incident of 2026-10-26, resolved the same day. `hub start ea` timed out at "EA Desktop to finish booting"
("SPA load success" never appeared in EADesktop.log), `hub start steam` never reached "Logged On", and the
Epic launcher crashed in libcef at browser creation. All fresh launches after 03:26 that morning failed the
same way; everything before 03:21 worked.

## Cause

At 03:21:22 on 2026-10-26, 36 non-Wine font files appeared in `drive_c/windows/Fonts` of the shared prefix —
among them byte-identical copies of macOS Supplemental fonts (`Arial.ttf`, `Arial Unicode.ttf` (23 MB),
`Tahoma.ttf`, `Verdana.ttf`, `Georgia.ttf`, `Impact.ttf`, Comic Sans, Courier New, Times New Roman, Trebuchet).
The prefix then held two different fonts for the same face names (Wine's set plus Apple's), which is what the
apps choked on at startup: Steam's vgui logged `Win32Font.cpp: Couldn't get string length`, EA's Qt logged
`QWindowsFontEngineDirectWrite` failures and its UI thread stopped servicing the CEF message pump right after
"Creating Qml view [Spa]", so the SPA never loaded. The 13.805-era EA client (unchanged), the runtime, the
compat rules and the registry were all innocent; each suspect was A/B-tested (old `winemac.so`, no
`UsePreciseScrolling`, committed rules file, cleared CEF cache) and the failure stayed until the fonts were
removed.

Nothing in the hub, the Wine fork or wineboot copies Mac fonts into the prefix; the files came from outside
(the hub script and hub-rules.txt were being edited at 03:22, one minute later). Do not copy macOS fonts into
`drive_c/windows/Fonts`; Wine's own set (56 files from `Runtimes/hub-1/share/wine/fonts`) is all the prefix
needs.

## Fix

The 36 extra files were moved to `Backups/prefix-windows-Fonts-extras-20261026/` (safe to delete after a
while). With only Wine's 56 fonts in place, EA boots ("SPA load success" in ~4 s), Steam logs on with
steamwebhelper running, and the prefix is otherwise unchanged. The CEF profile cache
(`.../EA Desktop/CEF/2/EADesktop/BrowserCache`) was also cleared during diagnosis; EA rebuilt it and its
login (kept in EA's own cookie jar) survived. The old cache is in
`Backups/cef-cache-before-clear-20261026/`.

## Diagnosis notes

- `EADesktop.log` accumulates sessions; `grep -n "\[STARTUP\]" | tail -1` finds the current one, and the hub's
  success marker is "SPA load success".
- The `mtld3d-logs/EADesktop-*.log` lines `fault outside mtld3d.so ... __wine_unix_call_dispatcher` (4 per
  process) appear in every mtld3d process, working or not — they are normal and not a crash indicator.
- Sampling a hung EADesktop shows idle waits (Cocoa runloop / message waits); the CEF renderer subprocess
  sits idle waiting for the browser process, which is blocked before the first SPA navigation.
