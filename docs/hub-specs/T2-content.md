# T2: Knowledge content (data only; spec; write exactly, report, do not improvise)

Write JSON files under `Sources/HubCore/Knowledge/` matching the T1a/T1b schema (read Sources/HubCore/Model/*.swift for exact keys; every object
`schemaVersion` only where the type has it (Recipe)). File name = `<id>.json` for one-object folders. 2-space indent, keys in the order the spec lists.
Values marked FROM <source> must be copied verbatim from that source (read-only); if a source lacks the value, OMIT that entry and list it in the report.
Never read or print account data, tokens, emails. Read-only access allowed to: the repo, /Volumes/ExT2/GameHub/Runtimes/hub-0 (shasum), the BF3 bundle
`/Volumes/ExT2/Bundles/Battlefield 3 Bundled 20261009-5ee7913.app/Contents/Resources/*`, and `grep` on
/Volumes/ExT2/GameHub/Relocated/BF3Mac/Data/Prefix/system.reg (only lines of `Origin Games` keys and their DisplayName).

## capabilities.json (array of {id,title,evidenceHint}; one per Capability case)
trapFlagEmulation "Trap-flag execution-breakpoint emulation (patches 0001-0004)" hint "knob WINE_TF_EMULATION in lib/wine/x86_64-unix/ntdll.so";
rosettaRwxWxEmulation "W^X emulation for RWX pages (0008-0010)" "knob WINE_RWX_WX_EMULATION in ntdll.so"; rosettaRwxWxPageLog "Per-page W^X log" "knob WINE_RWX_WX_LOG";
crashContextBlock "Crash-context snapshot (0005)" "runtime provenance"; crashContextCodeWindows "Crash code windows (0006)" "runtime provenance";
rosettaPageExperiments "Rosetta page toggles (0007)" "runtime provenance"; x87Sidecar "x87 sidecar hook" "knob ROSETTA_X87_PATH in ntdll.so";
dxmtDXGI "DXMT DXGI/D3D11 backend" "lib/wine/dxgi/dxmt"; compatdb "Per-exe renderer rules (WINE_COMPATDB)" "lib/wine/x86_64-unix/compatdb.so";
wined3dDXGI "wined3d DXGI backend" "lib/wine/dxgi/wined3d"; mtld3dD3D9 "mtld3d D3D9 backend" "lib/wine/d3d9/mtld3d"; mtld3dD3D8 "mtld3d D3D8 front end" "lib/wine/d3d9/mtld3d/*/d3d8.dll";
dsoundSSE2 "dsound SSE2 resampler (0011)" "dsound.dll equals wine-0011's"; caseFoldCache "Case-fold lookup cache" "not built yet"; exeListSwitches "Per-exe switch lists (F1)" "not built yet".

## knobs.json
session: WINE_TF_EMULATION, WINE_TF_MAX_STEPS, WINE_TF_MAX_NS, WINE_RWX_WX_EMULATION, WINE_RWX_WX_LOG, WINE_RWX_WX_HOT_LIMIT, WINE_RWX_WX_NEAR_LIMIT,
WINE_RWX_WX_TF_RELEASE, MTLD3D_CONFIG, BFWEBHELPER_ALWAYS_ACTIVATE, BF3_RTV_NOSHIM; session+prefixMachine: DXMT_METALFX_SPATIAL_SWAPCHAIN, DXMT_CONFIG,
DXMT_LOG_LEVEL, DXMT_LOG_PATH. reason: one short sentence each (e.g. "Trap-flag emulation switch read by the fork's ntdll").

## prerequisites.json
wine-mono-10.4.1: FROM Packaging/Recipes/nfs2015.json `managedRuntime` (file, sha256, version); url `https://dl.winehq.org/wine/wine-mono/10.4.1/<file>`; kind msi; arch both.
wine-gecko-2.47.4-x86 and wine-gecko-2.47.4-x86_64: FROM any SOURCES.md / notes under the BF3 bundle Resources (grep -ri gecko); url
`https://dl.winehq.org/wine/wine-gecko/2.47.4/<file>`; kind msi. Omit if not found.

## patches.json
0001 "Rosetta debug-register state + TF execution-breakpoint delivery" trapFlagEmulation ref "development" commit 8ae3878 verified;
0002 "Configurable execution-breakpoint budgets" trapFlagEmulation development b9092a7 verified; 0003 "Decode prefixes on PUSHF/POPF in the emulator"
trapFlagEmulation development c2b2655 verified; 0004 "Execution-breakpoint regression fixture" trapFlagEmulation development f7f4dfe verified;
0005 "Crash-context snapshot" crashContextBlock ref "nfs2015-runtime-0010" no commit experimental; 0006 "Crash code windows / page history"
crashContextCodeWindows nfs2015-runtime-0010 experimental; 0007 "Rosetta exec-page toggles + page trace" rosettaPageExperiments nfs2015-runtime-0010 rejected;
0008 "Optional W^X emulation for RWX pages" rosettaRwxWxEmulation nfs2015-runtime-0010 experimental; 0009 "TF leak and straddling stores" rosettaRwxWxEmulation
nfs2015-runtime-0010 experimental; 0010 "Self-modifying pages + per-page log" rosettaRwxWxPageLog nfs2015-runtime-0010 experimental;
0011 "dsound SSE2 resampler + mixer phase cache" dsoundSSE2 ref "nfs2015-runtime-0011" commit 71133b5 experimental.

## runtimes/hub-0.json
id hub-0, title "Hub runtime 0 (BF3 bundle Wine: wine-0010 + dsound-0011)", wineVersion "wine-11.0", source {origin "Battlefield 3 Bundled 20261009-5ee7913.app/Contents/SharedSupport/Wine",
revision FROM runtime-provenance.json `sources.wine`, patchSeries ["0001".."0011"]}, manifestSHA256 "278e1d9da269c8c1f28d6a8b93451461b76a069336d9dcbea1496170163a6f9f",
keyFiles: compute `shasum -a 256` IN /Volumes/ExT2/GameHub/Runtimes/hub-0 for: bin/wine, bin/wineserver, lib/wine/x86_64-unix/ntdll.so, lib/wine/x86_64-unix/wine,
lib/wine/i386-windows/ntdll.dll, lib/wine/x86_64-windows/kernelbase.dll, lib/wine/i386-windows/kernelbase.dll, lib/wine/x86_64-unix/compatdb.so,
lib/wine/x86_64-windows/dsound.dll, lib/wine/i386-windows/dsound.dll; the first seven MUST equal runtime-provenance.json `inputRuntimeHashes` (report any mismatch and stop);
capabilities (id, evidence): trapFlagEmulation "knob:WINE_TF_EMULATION@lib/wine/x86_64-unix/ntdll.so", rosettaRwxWxEmulation "knob:WINE_RWX_WX_EMULATION@lib/wine/x86_64-unix/ntdll.so",
rosettaRwxWxPageLog "knob:WINE_RWX_WX_LOG@lib/wine/x86_64-unix/ntdll.so", crashContextBlock "doc:runtime-provenance.json runtimeCapabilities",
crashContextCodeWindows (same doc), rosettaPageExperiments (same doc), x87Sidecar "knob:ROSETTA_X87_PATH@lib/wine/x86_64-unix/ntdll.so",
compatdb "file:lib/wine/x86_64-unix/compatdb.so", dxmtDXGI "file:lib/wine/dxgi/dxmt/x86_64-windows/dxgi.dll", wined3dDXGI "file:lib/wine/dxgi/wined3d/x86_64-windows/dxgi.dll",
mtld3dD3D9 "file:lib/wine/d3d9/mtld3d/i386-windows/d3d9.dll", dsoundSSE2 "doc:dsound.dll sha256 equals wine-0011 (2026-10-11)";
helpers {"x87sidecar": {path "hub-0-helpers/x87sidecar", sha256 "43ab085ae341af782f2532caba79aed7fed2a19dd9b2c46952b8e7e4572732c6"}}.

## fixes/*.json  (P = appliesWhen; A = actions; all have reason + evidence strings as given)
Use `{"any":[{"kind":"always","value":""}]}` for "always".
1 default-renderers verified P always; requires [compatdb,dxmtDXGI,mtld3dD3D9]; A renderer * d3d9 mtld3d, renderer * dxgi dxmt. evidence "2026-10-11 BF4: 'Missing DLL: [dxgi.dll] Error: 0x7E' without a default rule; licence check passed with exe=*;d3d9=mtld3d;dxgi=dxmt".
2 ea-client-dxmt verified P target ea; A renderer EADesktop.exe dxgi dxmt; evidence "NFS 2015: full client UI on DXMT, no shared-handle failures (OVERRIDES-MATRIX §2)".
3 ea-cef-wined3d verified P target ea; A renderer EACefSubProcess.exe dxgi wined3d; evidence "STATUS-20261010: DXMT 'cross-process swapchain not supported yet' -> blank webview".
4 ea-gep-wined3d experimental P target ea; A renderer EAGEP.exe dxgi wined3d; evidence "2026-10-11: EAGEP on wined3d starts faster; EAGEP lost a 3.5 s race on DXMT".
5 ea-helpers-dxmt verified P target ea; A renderer BF3WebHelper.exe dxgi dxmt, renderer EALaunchHelper.exe dxgi dxmt; evidence "bf3.json: without a rule they failed to import dxgi and d3d11".
6 ea-igoproxy-off verified P target ea; A dllOverride dll IGOProxy32.exe mode disabled (no exe); evidence "EA 32-bit overlay faults in the 32-bit wined3d/DXGI path (NFS2015.md §5)".
7 no-menubuilder verified P always; A dllOverride dll winemenubuilder.exe disabled; evidence "policy: keep host menus clean (OVERRIDES-MATRIX §4)".
8 ea-in-process-gpu verified P target ea; A arguments EADesktop.exe ["--in-process-gpu"]; evidence "EA UI renders blank without it (NFS2015.md §5-6)".
9 tf-emulation verified P target ea; requires [trapFlagEmulation]; A env WINE_TF_EMULATION 1 session, env WINE_TF_MAX_STEPS 0 session, env WINE_TF_MAX_NS 0 session; evidence "NFS 2015 passes its protection check with TF emulation (NFS2015.md §3.2); start-ea.sh sets it for the EA session".
10 rwx-emulation experimental P target nfs2015; requires [rosettaRwxWxEmulation]; A env WINE_RWX_WX_EMULATION 1 session; evidence "default on in the -0010 NFS apps; verified on test programs only (runtime provenance)".
11 x87-sidecar verified P any [machine i386, target ea]; requires [x87Sidecar]; A sidecar enabled true; parameter {id enabled, title "x87 sidecar", type bool, default "true", binds "actions[0].enabled"}; evidence "CoD4 median 146.1 vs 79.2 FPS (OVERRIDES-MATRIX §3)".
12 retina verified P always; A window retina enabled true; parameter {id enabled, title "Retina resolution", bool, default "true", binds "actions[0].enabled"}; evidence "RetinaMode=Y in the BF3 prefix user.reg; NFS 2015 and CoD4 verified".
13 metalfx-spatial experimental optIn true P imports dxgi; requires [dxmtDXGI]; A env DXMT_METALFX_SPATIAL_SWAPCHAIN 1 session, env DXMT_CONFIG "d3d11.metalSpatialUpscaleFactor=1.5" session; parameter {id factor, title "MetalFX upscale", choice, choices ["d3d11.metalSpatialUpscaleFactor=1.25","d3d11.metalSpatialUpscaleFactor=1.5","d3d11.metalSpatialUpscaleFactor=2.0"], default the 1.5 one, binds "actions[1].value"}; evidence "known to crash NFS16 (2 of 2 launches); default off".
14 ea-gep-prewarm experimental P target ea; A companion exe EAGEP.exe after ready readiness {log "{prefix}/drive_c/ProgramData/EA Desktop/Logs/EABackgroundService.log", events [{state ready, contains "Client connected [EAGEP.exe]"}], ports [], timeoutSeconds 30}; evidence "EABackgroundService.log 2026-10-11 09:55:38.2 'EAGEP didn't respond in time'; connected 09:55:39.1".
15 ea-client-paths-after-update experimental optIn true P target ea; A registry machine "Software\\Electronic Arts\\EA Desktop" ClientPath string "{eaClientDir}\\EADesktop.exe", same key DesktopAppPath "{eaClientDir}\\EADesktop.exe", same key ErrorReporterPath "{eaClientDir}\\ErrorReporter.exe"; evidence "EADesktop.log: 'Failed to update registry keys, this may cause launch issues if there was a recent update'; ClientPath points at a missing EA Desktop\\EA Desktop folder".
16 bf3-d3d11-proxy verified P target bf3; A dllOverride exe bf3.exe dll d3d11 mode "native,builtin"; evidence "no DirectX Error after the proxy (bf3/NOTES.md:49-57); AppDefaults key present in the BF3 prefix".
17 cod4-g-drive verified P target cod4; A drive g {gameRoot}; evidence "fileSysCheck.cfg found only with G: (COD4.md:38-42)".
18 fc2-no-d3d10 code-level -> status experimental P target farcry2; A dllOverride exe FarCry2.exe dll d3d10 disabled, same for d3d10_1, d3d10core; evidence "forces the DX9 path (FARCRY2.md:159-170), not verified on the real game".
19 nfsmw-dinput8 verified P target nfsmw; A dllOverride exe speed.exe dll dinput8 "native,builtin"; evidence "ASI loader proxy; gameplay verified".
20 morrowind-d3d8 verified P target morrowind; requires [mtld3dD3D8]; A dllOverride exe Morrowind.exe dll d3d8 "native,builtin"; evidence "owner: plays well with mtld3d D3D8 (Play_Morrowind.command)".
21 ron-virtual-desktop verified P target ron; A window virtualDesktop size 1280x960; evidence "native fullscreen crashes; virtual desktop verified (FULL-REQUIREMENTS.md:52-54)".
22 ea-cef-dxmt rejected P target ea; A renderer EACefSubProcess.exe dxgi dxmt; evidence "blank webview: 'cross-process swapchain not supported yet' (STATUS-20261010); supersedes bf3.json".
23 bf3-dsound-native rejected P target bf3; A dllOverride exe bf3.exe dll dsound "native,builtin"; evidence "not mapped; builtin dsound kept loading (bf3/NOTES.md:70)".

## recipes/providers (schemaVersion 1, kind provider, provider = id)
ea: title "EA app", status verified, evidence ["Signed in and launching BF3/BF4 in the BF3 prefix (2026-10-10/11)"], location windowsPath "C:\\Program Files\\Electronic Arts\\EA Desktop",
 executable EADesktop.exe, architecture x86_64, processes [EADesktop.exe, EACefSubProcess.exe, EABackgroundService.exe, EAGEP.exe, EALauncher.exe],
 launch {method direct, executable EALauncher.exe, arguments [], urlTemplate "origin2://game/launch/?offerIds={offerIDs}"},
 stop {taskkill [EADesktop.exe, EACefSubProcess.exe, EABackgroundService.exe, EAGEP.exe]},
 readiness {log "{prefix}/drive_c/ProgramData/EA Desktop/Logs/EADesktop.log", startMarker "[STARTUP]", events [{needsSignIn "awaitingAuthentication"}, {ready "client.boot.ready"}, {failed "LaunchFailed"}], ports [3215,3216], timeoutSeconds 180},
 fixes [] (predicates select them), settings [].
steam: title "Steam", status unverified, location windowsPath "Z:\\Volumes\\ExT2\\Steam", executable steam.exe, x86_64? NO: architecture i386, processes [steam.exe, steamwebhelper.exe, steamservice.exe],
 launch {direct, executable steam.exe, arguments [], urlTemplate "steam://rungameid/{appID}"}, stop {arguments ["-shutdown"], taskkill [steam.exe, steamwebhelper.exe]},
 readiness {log "{providerRoot}/logs/bootstrap_log.txt", events [], ports [], timeoutSeconds 300}.
epic: "Epic Games Launcher", unverified, location windowsPath "C:\\Program Files (x86)\\Epic Games\\Launcher\\Portal\\Binaries\\Win64", executable EpicGamesLauncher.exe, x86_64,
 processes [EpicGamesLauncher.exe, EpicWebHelper.exe], launch {direct, executable EpicGamesLauncher.exe, [], "com.epicgames.launcher://apps/{appID}?action=launch&silent=true"},
 stop {taskkill [EpicGamesLauncher.exe, EpicWebHelper.exe]}, readiness {log "{prefix}/drive_c/users/crossover/AppData/Local/EpicGamesLauncher/Saved/Logs/EpicGamesLauncher.log", events [], ports [], 300}.
ubisoft: "Ubisoft Connect", unverified, location windowsPath "Z:\\Volumes\\ExT2\\Ubisoft Game Launcher", executable UbisoftConnect.exe, i386, processes [UbisoftConnect.exe, upc.exe, UplayWebCore.exe],
 launch {direct, UbisoftConnect.exe, [], "uplay://launch/{appID}/0"}, stop {taskkill [UbisoftConnect.exe, upc.exe, UplayWebCore.exe]}, readiness {log "{providerRoot}/logs/launcher_log.txt", events [], ports [], 300}.

## recipes/games (kind game)
bf3: "Battlefield 3", verified, evidence ["bf3.json storeClient (origin2 launch verified)"], provider ea, ids {eaOfferIDs FROM Packaging/Recipes/bf3.json storeClient.offerID}, location windowsPath "C:\\Program Files\\EA Games\\Battlefield 3",
 executable bf3.exe, i386, processes [bf3.exe, BF3WebHelper.exe], leaseTarget bf3.exe, launchChain [BF3WebHelper.exe, bf3.exe], launch {method provider, arguments []}.
bf4: "Battlefield 4", unverified, evidence ["2026-10-11 licence check passed, ~77 s session"], provider ea, ids {eaOfferIDs ["1007968"]}, location windowsPath "E:\\EA Games\\BF4\\Battlefield 4", executable bf4.exe, x86_64,
 processes [bf4.exe, BFLauncher.exe, BF4WebHelper.exe], leaseTarget bf4.exe, launchChain [BFLauncher.exe, BF4WebHelper.exe, bf4.exe], launch provider.
crysis3: "Crysis 3", unverified, provider ea, ids {eaOfferIDs [the `Origin Games\<id>` whose DisplayName is "Crysis 3" in system.reg; omit ids if none]}, location windowsPath "E:\\EA Games\\BF4\\Crysis 3", executable Crysis3.exe, i386, processes [Crysis3.exe], leaseTarget Crysis3.exe, launch provider.
nfs2015: "Need for Speed (2015)", unverified, evidence ["verified in the NFS 2015 wrapper; not yet in the shared prefix"], provider ea, ids {eaOfferIDs FROM nfs2015.json storeClient.offerID}, location windowsPath "E:\\EA Games\\Need for Speed", executable NFS16.exe, x86_64, processes [NFS16.exe], leaseTarget NFS16.exe, launch provider.
cod4: "Call of Duty 4", unverified, provider none, executable iw3sp.exe, i386, launch {method wrapper, arguments []}, legacyWrapper "Call of Duty 4 Bundled".
nfsmw: "Need for Speed: Most Wanted", unverified, none, speed.exe, i386, wrapper "Most Wanted Bundled". farcry2: "Far Cry 2", unverified, none, FarCry2.exe, i386, wrapper "Far Cry 2 Bundled".
morrowind: "The Elder Scrolls III: Morrowind", unverified, none, Morrowind.exe, i386, launch {method direct, arguments []}, no location.
ron: "Rise of Nations: Extended Edition", unverified, provider steam, ids {steamAppID "287450"}, location windowsPath "Z:\\Volumes\\ExT2\\Steam\\steamapps\\common\\Rise of Nations", executable riseofnations.exe, i386, processes [riseofnations.exe], leaseTarget riseofnations.exe, launch provider.
## rules/*.json (ProposalRule)
ea-installer: when all [marker __Installer/installerdata.xml] -> provider ea, fixes []. steam-api: when any [marker steam_api.dll, marker steam_api64.dll, marker steam_appid.txt] -> provider steam.
epic-eos: any [marker EOSSDK-Win64-Shipping.dll, marker EOSSDK-Win32-Shipping.dll, marker .egstore] -> epic. ubisoft-loader: any [marker uplay_r1_loader.dll, marker uplay_r1_loader64.dll, marker upc_r2_loader64.dll, marker uplay_r2_loader64.dll] -> ubisoft.
i386-sidecar: all [machine i386] -> fixes [x87-sidecar].
## Done
All files written; then run the HubCore tests (build command from the brief) to prove the bundled knowledge loads (T1b has a test that loads the bundled dir).
Report: files, every OMITTED value and why, any hash mismatch.

## Amendments (apply on top of the above; they win on conflict)
- cod4-g-drive: drive {letter g, target "{gameRoot}", lifetime session}.
- ron-virtual-desktop: window {mode virtualDesktop, exe riseofnations.exe, size 1280x960}.
- New fix 24 fc2-dx9-profile experimental P target farcry2; A xmlAttribute {file "{prefix}/drive_c/users/crossover/Documents/My Games/Far Cry 2/GamerProfile.xml",
  element <FROM Sources/FarCry2Core: the element that carries the `Platform` attribute; omit the fix if not found>, attribute Platform, value d3d9}; evidence "FARCRY2.md:159-170".
- ea-gep-wined3d evidence: add "review: EAGEP.exe.mdmp at 10:00:50Z under wined3d; A/B pending".
- EA provider readiness events become: [{state needsSignIn, contains "-> awaitingAuthentication", holdSeconds 20}, {state ready, contains "-> authenticated"},
  {state failed, contains "LaunchFailed"}]; startMarker "[STARTUP]".
- EA provider launchStages (ids/titles/probes exactly; logs: L = "{prefix}/drive_c/ProgramData/EA Desktop/Logs/EADesktop.log",
  B = "{prefix}/drive_c/ProgramData/EA Desktop/Logs/EABackgroundService.log"):
  client "EA app started" pass [log L "[STARTUP]"] fail [] 120;
  signed-in "Signed in" pass [log L "-> authenticated"] fail [log L "-> awaitingAuthentication" hold 20] 180;
  services "Local services answer" pass [port 3215, port 3216] fail [] 60;
    session "Game session started" scope game pass [log L "game.sess.strt"] fail [log L "LaunchFailed", process ActivationUI.exe present true] 120;
  running "Game running" pass [process {leaseTarget placeholder not allowed: use a stage only in game recipes}] -> OMIT this stage from the provider.
- bf3, bf4, crysis3, nfs2015 game recipes: launchStages [running "Game running" pass [process <their leaseTarget> present true] fail [] 180].
- crysis3 launchStages: [gep "Elevation proxy connected" pass [log B "Client connected [EAGEP.exe]"] fail [] 30, then running as above] (EAGEP-launched game).
