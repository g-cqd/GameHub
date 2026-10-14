# EA native helper: design and feasibility

Written 2026-10-09. Research and design only: nothing here was executed. No credentials were used, no EA or Origin endpoint was contacted by this investigation, and no third-party code was downloaded, built or run. Public web pages and public source repositories were read only.

Labels: **[verified: path or URL]** read directly from that source; **[inferred]** reasoned from verified facts, with the reasoning given; **[unknown]** not established, say so rather than guess.

Headline conclusion, for the reader in a hurry: the licence is not the obstacle, because licences come from EA's servers and would continue to. **Authentication is the obstacle.** See 2.0 and section 5.

## 1. What a game needs from the EA client at launch

Shorthand: `PFX` = `/Users/gc/Library/Application Support/NFS2015Mac/Data/Prefix/drive_c`; `LOGS` = `PFX/ProgramData/EA Desktop/Logs`; `NFSDOC` = `/Users/gc/Developer/Games/nfs-release/macos-app/docs/NFS2015.md`.

### 1.1 Summary: three local surfaces and one server-side licence

| Surface | What it is | Who uses it | Evidence |
|---|---|---|---|
| **LSX** (Origin SDK / "EbisuSDK") | XML messages over a localhost TCP socket. The client sends a challenge first [verified: a `ChallengeResponse` per connection in the owner's logs]; the link is then encrypted [inferred: public open-source implementations] | The game's statically linked Origin SDK: `bf4.exe` has `originsdk\src\impl\OriginLSXRequest.h`, `Origin::OriginSDK::RequestAuthCode`, `GetAuthCode`, `EbisuSDK` | [verified: owner's EA app log `LOGS/EADesktopVerbose.log:1-3` shows `Origin::SDK::Lsx::LSX_Handler::processRequest ... <GetPresence UserId=... version="3"/>` answered over `(TCP 51984)`], [verified: strings of `bf4.exe_DiP_Staged` on mbp23] |
| **OOA activation** (`Core/Activation64.dll`, ordinal 100; `ActivationUI.exe`) | EA's "Origin Online Activation" DRM wrapper. It asks the client for a licence and verifies EA's signature on it | NFS16.exe imports only ordinal 100 of `Core/Activation64.dll`. BF4 ships the same DLLs | [verified: NFSDOC:60-63], [verified: mbp23 `Core/Activation64.dll_DiP_Staged`, 980,488 B], [verified: `LOGS/EADesktop.log:1343` "Found OOA version: 4.11.1.275" read from the game's Activation DLL] |
| **Legacy LocalHost HTTP** `127.0.0.1:3215` | Old Origin "OriginClient-LocalHost Api" (`/ping`, `/status`, `/game/launch?offerIds=&cmdParams=`, `/killgame`). It checks only the browser `Origin` header | Battlelog web pages, which drive BF4 launches | [verified: `LOGS/EALocalHostSvcVerbose.log:59` "[Legacy] Listening on port: 3215"]. Endpoint list: [inferred: pastebin.com/xbb5q4wa, anonymous 2015 Swagger, low reliability] |
| EA app internal IPC | `EABackgroundService` IPC on a dynamic port, published in `ProgramData/EA Desktop/backgroundservice.ini` (`BackgroundServicePort=51864`). `EALocalHostSvc.exe -ipcport=63332`. The pipe backend is disabled | EA app components only. Games do not use it | [verified: `PFX/ProgramData/EA Desktop/backgroundservice.ini`; `LOGS/EABackgroundService.log:623`; `LOGS/EADesktop.log:74`; `LOGS/EABackgroundServiceVerbose.log:76`] |

**The licence is issued by EA's server and signed there** (by whom it is verified, client or game DLL, is [unknown]). On every NFS2015 launch, the activation log records `License Request Server HTTP response code=200`, `response state code=3`, `License signature is good.`, `License Grant Time MS = ...`, and `License - Local time difference of N seconds` [verified: `PFX/ProgramData/Origin/Logs/NFS16_1024486_OnlineActivation_Log.html`, 25 grants; the client-side copy at `PFX/users/crossover/AppData/Local/Electronic Arts/EA Desktop/Logs/EAapp_OnlineActivation_Log.html` has 3]. Three consequences follow:
- **The licence cannot be forged.** The game checks a signature it cannot get anywhere but EA's server, and our design does not attempt to make one.
- **The log records a grant time and a local-clock difference**; that a mismatch would block launch is [unknown], since no failure appears in these logs.
- **A grant is made at every launch.** It is not a one-off install step [verified: 25 grants in the game's own activation log].

The cached result is `PFX/ProgramData/Electronic Arts/EA Services/License/1024486.dlf` (1,889 B, named by content id) [verified]. `EABackgroundService` grants all users read/write access to that directory [verified: `LOGS/EABackgroundService.log:46`]. The file is an encrypted, EA-signed container [inferred: public open-source code treats it that way]. Which process writes the file under the real EA app (the client or the game's Activation DLL) is [unknown].

**Activation re-triggers when the Wine build changes** [verified: NFSDOC:356-358]. That the cause is machine binding is [inferred]. The EA user agreement also caps play at "no more than five unique machines in any rolling 24-hour period" [verified: https://www.ea.com/legal/user-agreement §7.B, fetched 2026-10-09, "Last Updated May 14, 2026"; quote via a summarising fetch].

### 1.2 What happens when the EA app launches a game (owner's NFS2015 evidence)
1. `EALauncher.exe origin2://game/launch/?offerIds=1024486` hands off to `EALaunchHelper.exe` with the same URI [verified: `LOGS/EALauncher.log:16-18`]. `origin` and `origin2` are registered URL classes pointing at `EALauncher.exe "%1"` [verified: prefix `system.reg:34837-34853`].
2. EA Desktop resolves the offer and logs `Processing launch request: offerId[Origin.OFR.50.0000810] contentId[1024486] exe[C:\Program Files\EA Games\Need for Speed\NFS16.exe] cwd[...] args[] locale[en_US]` [verified: `LOGS/EADesktop.log:1349`]. It sets `masterTitleId=185353` for the in-game overlay [verified: `LOGS/EADesktop.log:1341`] and reads the OOA version from the game's Activation DLL [verified: `:1343`].
3. **The licence comes before the process.** `requestLicenseAndLaunch` issues the launch, and only after that is NFS16.exe created: `exe=[...NFS16.exe], args=[], dir=[game folder], breakaway=[true], inheritEnv=[false], uac=[false] | PID: 1768`. The client then starts `compatibility32\EADesktop.exe 32` and sends `game.sess.strt` telemetry [verified: `LOGS/EADesktop.log:1336-1369`, the create at :1357]. So the client requests the licence before the game process exists [inferred: from the `requestLicenseAndLaunch` ordering]. Whether the game's Activation DLL also contacts EA itself is [unknown], and the two are not mutually exclusive. **No arguments are passed** (`args[]`, `cmdArgs=[]`), and **no environment variable is logged**. A grep for the env-var names used by the public open-source client found nothing in any log [verified]. With `inheritEnv=false`, the game gets either a minimal block or one the client builds without logging it. Which of the two is [unknown].
   - LSX requests the game actually sent, by count: GetPresence 11212, QueryPresence 54, QueryAchievements 17, GetSetting 12, GetGameInfo 12, GetProfile 5, GetConfig 4, QueryImage 3, **GetAuthCode 2**, GetBlockList 1, GetInternetConnectedState 1, QueryFriends 1. There was also a `ChallengeResponse` per connection. These counts are inflated by overlapping `.bak` copies, so read them as "at least once". **No `RequestLicense` and no `QueryEntitlements` appear for NFS2015 at all** [verified: `grep -o 'Processing request: <Name'` over LOGS, which includes overlapping .bak copies]. This list is the concrete stage-0 target for NFS2015. BF4's list is [unknown] until stage 0.
4. The game's SDK connects to LSX, and the client answers requests such as `GetPresence` [verified]. Its auth-code flow (`OriginRequestAuthCode`, `PresenceGetAuthCodeRequestParameters`, `AuthCodeClientId`) [verified: NFSDOC:62-63 strings] asks the client to mint a short-lived OAuth **authorisation code** for the game's own client id from EA's identity service [inferred from the names and from Maxima `lsx/request/auth.rs`].
5. **The game cannot start without a client.** With no EA process running, NFS16.exe exits `170`, spawns `Core/ActivationUI.exe`, and asks for an `origin2://` relaunch with an **empty** `authCode` [verified: NFSDOC:32, :65-66]. The owner's own conclusion: "the EA app is a dependency to be satisfied, not worked around" [verified: NFSDOC:80-81].
6. Before launching, the owner's app waits for EA app readiness: `Telemetry Event [login]` and then `[client.boot.ready]` after the latest `[STARTUP]` [verified: NFSDOC:2110]. An EA client self-update exits with `ClientUpdateDestaging`, which today's launcher treats as a failed start. This is unfixed board item wine-rebuild-028 [verified: NFSDOC:2357; /Users/gc/Developer/Games/publish/nfs-macos/docs/ROSETTA-SMC.md:101].

### 1.3 Registry, files, hosts and ports that matter
- **Registry, EA app.** `HKLM\Software\Electronic Arts\EA Desktop` holds `ClientPath`, `DesktopAppPath`, `LauncherAppPath`, `InstallLocation`, `InstallSuccessful`. `HKLM\Software\Electronic Arts\EA Core` holds `ClientPath=...legacyPM\OriginLegacyCLI.exe` and `ClientVersion=7.0.0.1`. `HKCU\...\Run` has `EADM` (EALauncher `-silentOs`). There is also `System\ControlSet001\Services\EABackgroundService` [verified: prefix `system.reg:66366-66374`, `user.reg:258,786`; NFSDOC:1040]. Whether the game's SDK reads `EA Core\ClientPath` to locate or start a client is [inferred: plausible from the name, untested].
- **Registry, game.** BF4 installs under `HKLM\SOFTWARE\EA Games\Battlefield 4\Install Dir`. The 64-bit or WOW6432Node view is an open question in the owner's draft [verified: installerdata lines 48-86 on mbp23; bf4-recipe-draft.json:213-217].
- **Files.** `ProgramData/Electronic Arts/EA Services/License/<contentId>.dlf`, `ProgramData/Origin/Logs/<game>_<contentId>_OnlineActivation_Log.html`, and `ProgramData/EA Desktop/{machine.ini, backgroundservice.ini}` [verified].
- **Ports.** LSX listens on 3216 by default. Evidence: EA error EC:10701 is tied to "port 3216" [inferred: help.ea.com snippet, fetch timed out]; AirportSource/EA-Port-3216-Fix README; Maxima `core/mod.rs` default 3216 [verified as read]. Note that 51984 in the owner's log is the per-connection peer port [inferred]. Port 3215 is the legacy LocalHost API [verified]. Dynamic IPC ports are internal [verified].
- **Hosts.** The owner's EA app logs contact `pc.ea.com`, `service-aggregation-layer.juno.ea.com` (GraphQL, plus a `wss` subscription), `autopatch.juno.ea.com`, `ratt.juno.ea.com`, `origin-a.akamaihd.net`, `gateway.ea.com`, `desktop-config.juno.ea.com`, `eaaccounts.akamaized.net`, `pin-river.data.ea.com` (telemetry), `s.go-mpulse.net`, and `statsigapi.net` [verified: distinct hosts in LOGS]. A separate EA-operated licence service handles OOA activation, and the open-source client identifies itself to it with a dedicated request header [verified as read: Maxima `core/endpoints.rs`, `ooa/mod.rs`]. No hosts-file entries are involved in the legitimate path [inferred].

### 1.4 What the open-source client Maxima does (public reference, summarised at a high level)
ArmchairDevelopers/Maxima: GPL-3.0, Rust, 232 stars, last push 2026-08-02. Its own README calls it "very early stage" [verified: https://github.com/ArmchairDevelopers/Maxima]. It is a real client, not an offline emulator: it signs in a real account and asks EA's servers for licences. It is reverse-engineered and unofficial. As evidence of what works it is medium-high reliability. As evidence of what EA tolerates it is low.
- It runs a localhost LSX server and handles the request types listed in 1.2, plus RequestLicense and QueryEntitlements. Licences come from EA's licence service [verified as read: `maxima-lib/src/lsx/`, `maxima-lib/src/ooa/`].
- **It works only by presenting itself as EA's own PC client.** It uses EA's client id, together with credentials and signing material that originate inside EA's software [verified as read; values deliberately not recorded here]. Section 2.0 explains why this design does not follow that route.
- Its content download fetches entries of EA's remote archive using a download URL from EA's GraphQL service [verified as read: `maxima-lib/src/content/`].

### 1.5 Battlefield 4 facts already established by the owner (bf4-tools)
- Launch chain: EA app -> `origin2://game/launch/?offerIds=...` -> `BFLauncher.exe` (x86_64) -> `BF4WebHelper.exe` (i386 local HTTP server) -> `bf4.exe` (x86_64) [verified: /Users/gc/Developer/Games/bf4-tools/PLAN.md:146-163 (from strings, not runtime)]. Strings in BFLauncher include `-forceBattlelog`, `EALaunchEnv`, `ShellExecuteExA`. Game args include `-webmode sparta -requestState State_Sparta` [verified: PLAN.md:147-162].
- BF4WebHelper env knobs `BFWEBHELPER_{DEBUG,TEST_MODE,SHOW_MESSAGE,ALWAYS_ACTIVATE,IGNORE_ORIGIN_HEADER,WAIT_ON_EXIT}`; port and bind address [unknown] [verified: PLAN.md:151-172].
- EA client's local HTTP API `127.0.0.1:3215` [inferred: PLAN.md:236, community note pastebin.com/xbb5q4wa].
- BF4 ships the same activation layer as NFS2015: `Core/Activation.dll`, `Core/Activation64.dll`, `Core/ActivationUI.exe` (i386, Qt 4) [verified: bf4-recipe-draft.json:124,127; PLAN.md:58 for the i386 ActivationUI row].
- installerdata: EAInstaller-4.05.02.00, gameVersion 1.8.2.48475, launchers `[HKLM\SOFTWARE\EA Games\Battlefield 4\Install Dir]BFLauncher.exe` (empty parameters) and `BFLauncher_x86.exe`; `enableOriginInGameAPI="0"`; 20 content ids, base `1007968` [verified: PLAN.md:184-201; bf4-recipe-draft.json:319-332, read on mbp23 by an earlier agent].
- Install state: the mbp23 tree is a DiP-staged skeleton (every file `*_DiP_Staged`, `.cas` sparse zeros, ~1.14 GiB allocated of ~32.4 GiB); the owner's plan is a fresh install by the EA app, not a resume [verified: PLAN.md:79-84, 408-442].
- Battlelog is no longer supported by EA for BF4 (EA staff, April 2025) [verified as cited: PLAN.md:223-225].

## 2. What a native Swift helper must implement

### 2.0 The structural blocker, stated first
Everything below is implementable in Swift except one thing, and that one thing gates the whole idea.

To talk to EA's identity service **as a client**, software must identify itself with an OAuth client identity that EA recognises. I found **no public EA developer programme that issues such an identity for a third-party desktop launcher** [unknown, searched: two independent searches found no registration path, no published SDK terms, and no official LSX or OOA specification]. The only working public client therefore reuses **EA's own client identity together with signing and credential material that exists only inside EA's shipped software** [verified at a high level: Maxima source, read 2026-10-09].

That material is not a licence and not an entitlement, so reusing it would not forge ownership. But obtaining and using it means extracting non-public data from EA's client, which is squarely what the user agreement addresses: "You may not reverse engineer or attempt to extract or otherwise use source code or other data from EA Services, unless expressly authorized by EA or permitted by law" [verified as quoted via a summarising fetch: https://www.ea.com/legal/user-agreement §2, Last Updated 2026-05-14].

**Design position.** This document does not specify, and the project should not build, a component whose function is to impersonate EA's first-party client using extracted client credentials. That is not a licensing bypass, but it is unauthorised client impersonation against an identity service, it is the part with real account risk (section 3), and it is the part the owner cannot make safe by being the legitimate owner of the games. Marked **REJECTED as a default route** — not on feasibility grounds, since a public project reports it working, but because the project cannot ship it honestly as "a native client for your own account" while its core depends on EA's secrets.

Two routes remain, and both are worth building:
- **Route A (recommended, no EA secrets):** a native Swift **supervisor** around the real EA app. It owns sign-in presentation, readiness, licence-grant observation, session keep, lease and launch, and it fixes the concrete defects the owner has already hit. It is "native helper" in every respect except that EA's own client remains the thing that holds the session. Safe by construction.
- **Route B (gated, requires EA's cooperation or a licence-compatible answer):** the full native client. It is only reachable if EA grants a client identity, or if a route is found that needs no extracted secrets. Keep the design slot; do not implement it speculatively.

### 2.0b Answering the question as asked: the full native client's component list
For completeness, here is what Route B would have to implement, named without parameters. Every item is [inferred from the public open-source client's structure], not from EA documentation, since none exists publicly.
1. **Sign-in** against EA's identity service, presenting EA's own login page, with PKCE, and a loopback or custom-scheme redirect to catch the authorisation code. Requires a client identity (2.0).
2. **Token exchange and refresh**, plus secure storage (Keychain, device-only).
3. **A signed machine fingerprint**, which EA's identity service appears to expect from PC clients. This is the single largest unknown in the list, and the part most clearly dependent on EA-internal material.
4. **An LSX server** on the local port: accept the connection, send the challenge, complete the handshake, enable encryption, then answer the request census from 1.2 — profile and persona, settings, config, game info, connectivity, presence, and friends.
5. **Auth-code minting**: when a game asks, use the signed-in session to obtain an authorisation code from EA for the *game's own* client id, and return it.
6. **Licence request per launch** to EA's licence service for the signed-in account, returning EA's signed result unmodified, and writing EA's own on-disk licence container.
7. **Ownership and entitlement queries** against EA's catalogue service, for the library and for launch-time checks.
8. **Launch** with whatever environment and arguments the game expects (currently [unknown] for the real client, see 1.2).
9. **No downloader** — reuse EA's delivery (2.7).

Items 4, 5, 8 and 9 are reachable without any EA secret. Items 1, 2, 3 and 6 are not, today, which is the whole of the problem.

### 2.1 Sign-in (Route A), and the WKWebView question answered
The owner asked whether to show EA's own login page in a native `WKWebView`/`ASWebAuthenticationSession` rather than drive the EA app's GUI. **Recommendation: do neither for credentials.** The comparison:

| Option | Password exposure | 2FA / captcha | Verdict |
|---|---|---|---|
| Password form in our own UI | Password passes through our process | We would have to implement challenge flows | **REJECTED.** Never build this. It also matches the login route EA has already patched out of the public client [verified as read: Maxima's password login is `unimplemented!()` and annotated "This method of login was patched"] |
| `ASWebAuthenticationSession` to EA's page | None: Safari-backed, isolated from our process | Handled by EA's page | Correct **only if** we have a registered `client_id` and redirect URI, which we do not (2.0). Keep for Route B |
| **EA app's own window (Route A)** | None | Handled by EA | **Recommended now.** It is also what the owner's shipped NFS2015 app already does [verified: NFSDOC:354-355, 561-566] |

So Route A's sign-in step is unchanged in substance and better in presentation: the helper installs the EA app into the prefix, opens it, and waits. What improves is everything around it. Note the existing app deliberately "never stores, replaces or works around the sign-in, and it checks only that an account folder exists" [verified: NFSDOC:354-355]. **Keep that property.** The helper stores **no EA credential and no EA token**, so there is nothing for the Keychain to hold. Keychain use is therefore *not* required by Route A, which is a security win, not a gap. (Route B would need it: tokens in the Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, never a plain file — note the public client writes tokens to a plain TOML file, which this project should not copy.)

### 2.2 Token refresh and session keep (Route A)
The EA app refreshes its own tokens. The helper's job is to stop the session being destroyed, which is the owner's actual observed failure:
- **`ClientUpdateDestaging`.** The EA app exits with this reason when it self-updates, and today's launcher reads that exit as a failed start and kills the session [verified: NFSDOC:2357, board wine-rebuild-028; /Users/gc/Developer/Games/publish/nfs-macos/docs/ROSETTA-SMC.md:101]. Fix: treat it as a distinct `clientUpdating` phase, let `EADestager.exe` finish, and re-wait for readiness. The assumption that the destager completes under this Wine is still [unknown] and must be tested.
- **Readiness.** Keep the existing rule (`login` then `client.boot.ready` after the latest `[STARTUP]`) [verified: NFSDOC:2110] and add the launch-side signals now known to exist: `requestLicenseAndLaunch`, `doRequestLicenseAuth`, `Processing launch request`, `game.sess.strt` [verified: LOGS/EADesktop.log:1336-1369].
- **Pinning.** `machine.ini` shows `machine.updatepending=1` and an installer URL [verified]. Decide deliberately whether to allow EA app self-update; an unpinned client can change the protocol under us.

### 2.3 Entitlement and ownership lookup
Route A does not need one: the EA app already owns this, and the game never asked for it. For NFS2015, `QueryEntitlements` was **never sent** by the game, and `RequestLicense` was not sent over LSX either [verified: full request census, 1.2]. The helper's only ownership-adjacent need is the **offer id / content id** mapping to put into a recipe, which is read statically from `__Installer/installerdata.xml` [verified: NFS2015 `1024486` / `Origin.OFR.50.0000810`; BF4 20 content ids, base `1007968`]. Any live ownership query belongs to Route B.

### 2.4 Licence acquisition: the hard constraint, and what is REJECTED
The licence **must** come from EA's servers for the signed-in account. Evidence that this is enforced: the game verifies a signature it cannot produce locally, and checks grant time against the clock [verified: activation log, 1.1].

Explicitly **REJECTED**, with reasons:
- **Forging or self-signing a licence.** Impossible (signature) and off-limits.
- **Replaying or injecting any externally supplied licence or token** in place of a live grant for the signed-in account. Off-limits, and it is also exactly the behaviour the user agreement's protection-measure clause targets [verified: §7.A "Attempting to circumvent, disable or tamper with these measures shall terminate this license"].
- **Copying `.dlf` files between machines or prefixes**, or editing one, or reusing a cached one past its grant. Off-limits.
- **Patching the game, `Activation64.dll`, or the client.** Off-limits.
- **Freezing or shifting the clock** to satisfy the grant-time check. Off-limits.
- **Offline-mode licences.** Not pursued.

Permitted, and all Route A does: let the real client obtain the grant, and **observe** that it happened by reading EA's own activation log, which gains a grant record per launch [verified: 25 grants]. Note that the `.dlf` mtime is **not** a usable signal: it reads 11:38:44 while the launch it supposedly serves was at 11:42:40 [verified: `stat` of the `.dlf` against `LOGS/EADesktop.log:1357`], so the file is a cache that is not rewritten per launch. Any mtime-based signal is [unknown] until experiment E-c runs.

### 2.5 The local server that games talk to
Route A runs none: the EA app is the LSX server. The helper's only localhost concern is **port availability**, which is a real and diagnosable failure. LSX uses port 3216, and EA's own error EC:10701 is reported when it is unavailable [inferred: EA help-centre snippet, fetch timed out; corroborated by a third-party fix tool's README and by the public client's default]. The legacy LocalHost HTTP API on 3215 is confirmed live in the owner's prefix [verified: `LOGS/EALocalHostSvcVerbose.log:59`]. **Add a preflight check** that 3215 and 3216 are free inside the prefix's network namespace before launch, and surface a clear error instead of a mystery hang. For BF4 additionally expect `BF4WebHelper.exe` to bind its own port; its number is [unknown] and its failure message is known (`Binding of port %d failed`) [verified: strings, mbp23].

A **logging LSX stub** is still worth building, but as a *diagnostic*, not as a shipped server: it is how stage 0 learns what BF4 asks for (4.1) without any credential or EA contact.

### 2.6 Game launch inside the Wine prefix
Route A keeps the existing, working mechanism and extends it:
- Launch by URL: `EALauncher.exe "origin2://game/launch/?offerIds=<ids>"` [verified: NFS2015 recipe and `LOGS/EALauncher.log:16-18`]. For BF4, `offerIds` takes the content id(s); multiple ids are comma-separated [inferred: lutris/lutris#4996, open-source issue, medium reliability]. Which of BF4's 20 ids to pass is [unknown] (stage 1 experiment E2 in the owner's plan).
- **Do not** try to pass arguments or environment to the game through the EA app: it passes none (`args[]`) and uses `inheritEnv=[false]` [verified]. BF4's own `-webmode sparta` style arguments come from `BFLauncher`, not from us [verified: PLAN.md:161-162].
- **Lease must follow the chain.** `BFLauncher.exe` likely exits straight after `ShellExecuteExA` [inferred: PLAN.md:168-170], and the EA app creates game processes with `breakaway=[true]` [verified]. So the lease cannot track the first child. It must follow to `bf4.exe` by executable name, the way the current code already probes for `EADesktop.exe` via `ProcessFamily.runs(pid:program:)` [verified: Sources/NFS2015Session/NFS2015Session.swift:269].
- Keep `GameLease` as the single mutation gate [verified: `Sources/LauncherCore/GameLease.swift`; SETTINGS-PLAN.md:7].

### 2.7 Content download and update
**A downloader is not necessary, and writing one is not recommended.** Reuse EA's own delivery by letting the EA app install and patch the game. Reasons:
- The owner's BF4 tree is a **DiP-staged skeleton**, not a resumable install: every file carries a `_DiP_Staged` suffix and the `.cas` payloads are sparse zeros, 1.14 GiB allocated against 32.4 GiB logical [verified: PLAN.md:79-84; mbp23 listing]. The owner's own plan already concluded it should be treated as evidence and the EA app pointed at a fresh folder [verified: PLAN.md:408-442]. I agree.
- EA's install needs `Touchup.exe install -locale {locale} -installPath "{installLocation}" -autologging`, prerequisites, and `Support/mnfst.txt`, all declared in `installerdata.xml` [verified: mbp23, lines 259-267]. The EA app runs these correctly; we would be reimplementing an installer for no gain.
- What is public about the format: an `installerdata.xml` DiP manifest, and content fetched as entries of a remote archive via HTTP range requests using a download URL obtained from EA's GraphQL service [verified as read, at a high level: Maxima `core/manifest/`, `content/`]. Note that the public downloader has **CRC verification commented out** [verified as read], which is a correctness smell and another reason not to copy it.
- `autopatch.juno.ea.com` and `origin-a.akamaihd.net` appear in the owner's logs [verified], confirming the EA app does its own patching.
- Disk reality: BF4 needs about 32 GiB logical, and this Mac has ~27 GiB free against a 15 GiB floor [verified: `df`]. **BF4 must be installed to the external disk, not the internal one.**

### 2.8 How this plugs into the existing app
The codebase is a single Swift 6 package, `NFSMWMac`, macOS 15, `swiftLanguageModes: [.v6]`, with per-game launcher/session executable pairs over `LauncherCore` [verified: `/Users/gc/Developer/Games/nfs-release/macos-app/Package.swift`]. The EA client layer already exists as an abstraction, which is the good news: **Route A is mostly an extension of what is there, not a new subsystem.**
- Existing pieces to reuse: `StoreClientPlan` (already carries `launchURL`, `offerID`, `clientArguments`, `signInEvidence`, `readinessLog`, `startMarker`, `readyEvents`, `readinessSeconds`), `ClientLogProbe`/`ClientWait`, `ClientLayerPolicy` (its protocol allow-list already contains `origin2` and `link2ea`), `ClientInstaller`, `GameLease`, `ProcessCommand`, `WineRuntime`/`LaunchEnvironment`, `SettingsStore` [verified: paths and signatures as reported from `Sources/`].
- New, as a target inside the same package (suggested name `EAClientKit`, depending on `LauncherCore` only): `LicenseObserver` (parses the activation log; not the `.dlf` mtime, see 2.4), `ClientPhase` extension for `clientUpdating`, `LocalPortPreflight` (3215/3216), `ProcessChainLease` (follow-to-`bf4.exe`), and `LsxTranscript` (the stage-0 diagnostic stub, debug builds only). No new external dependencies, consistent with the package today.
- Recipe schema: `storeClient` needs `offerID` to become a **list**, plus slots for the launcher chain, the game process to lease, and the expected local ports. The owner's draft already flags exactly these blockers [verified: bf4-recipe-draft.json:4-9].
- Settings: one per-game switch, `clientLayer: .eaApp | .native`, defaulting to `.eaApp`, so Route B stays switchable per game if it ever becomes available (4.4).
- Process/lease model: unchanged, one lease per game, `game-session.json`, all mutations gated [verified: SETTINGS-PLAN.md:7].

## 3. Legal and account risk

Not legal advice. The owner should read the agreement himself; what follows is what I could verify.

**Facts.** The games and the account are the owner's own. The agreement was fetched on 2026-10-09 and states "Last Updated: May 14, 2026" [verified: https://www.ea.com/legal/user-agreement; also https://tos.ea.com/legalapp/WEBTERMS/US/en/PC/]. Clause text reached me through a summarising fetch rather than raw HTML, so **wording should be re-checked against the live page before anyone relies on it**.

**What the agreement says, as fetched:**
- §2: no reverse engineering or extracting "source code or other data from EA Services, unless expressly authorized by EA or permitted by law"; the licence is "personal, limited, non-transferable".
- §7.A: "Attempting to circumvent, disable or tamper with these measures shall terminate this license."
- §7.B: authentication is one EA account per serial code, and play is capped at "no more than five unique machines in any rolling 24-hour period".
- §7.C: an "Unauthorized Third-Party Program" is defined around programs that enable cheating, let users "bypass, modify or hack the game interface, environment, protections", or intercept or mine information from the game.
- §6: "Do not engage or assist in cheating, collusion, unfair play, or using exploits."
- §8: EA may terminate or suspend for violations, and may act on accounts and entitlements without notice (§4).
- Governing law is the owner's country of residence (§13.B), and EEA/UK/Swiss residents are outside the arbitration clause (§15).

**The important negative finding:** no clause I could find **plainly** prohibits using an unofficial client that signs in to a genuine account and does nothing else. §7.C's definition turns on cheating, bypassing protections, or data mining, none of which Route A or a hypothetical clean Route B does. The nearest general bar is §2's "may not access ... any EA Service ... unless expressly authorized", which is broad enough to cover it by implication. So the honest statement is: **not clearly prohibited, not authorised either, and §8 lets EA act on its own determination.** Also note that **reverse engineering for interoperability** has statutory protection in some jurisdictions (EU Software Directive Art. 6 and similar), which is why §2 carries "or permitted by law" — but that protection is narrow, is about achieving interoperability rather than about circumventing protection measures, and whether it covers any particular step here is [unknown] and a question for a lawyer, not for me.

**Safe by construction, in the sense that the risky capability is absent rather than merely unused (Route A):**
- No credential ever touches our code: sign-in happens in EA's own window [verified: current design, NFSDOC:354-355].
- No token is stored, read, or copied by us.
- No licence is forged, replayed, moved, or edited; every grant is a live grant from EA to the signed-in account (2.4).
- No game binary, client binary, or protection measure is patched.
- No EA endpoint is contacted by our code at all. The EA app makes its own connections.
- The EA app is EA's own, installed from EA and pinned in the recipe [verified: PLAN.md:53]; that the pin covers the Authenticode signer as well as the hash is [inferred].

**Residual risk the owner must accept knowingly (Route A):**
1. **Running in Wine on Apple Silicon is unsupported by EA.** Activation is machine-bound and re-triggers when the Wine build changes [verified: NFSDOC:356-358]. Frequent re-activation consumes machine slots against the §7.B five-machines-per-24h cap, so rapid runtime iteration is itself the main practical hazard. Mitigation: pin runtime builds, batch experiments, and do not churn prefixes.
2. Anti-cheat is out of scope and unaddressed: PunkBuster and FairFight for BF4 [verified: PLAN.md:279-281]. Multiplayer carries its own risk independent of this design.
3. EA can change the client or discontinue services; Battlelog is no longer supported for BF4 [verified as cited: PLAN.md:223-225, EA staff], and Origin itself was shut down in April 2025 [inferred: PLAN.md:330, citing AppleGamingWiki].

**Additional residual risk if Route B were ever built:** client impersonation using extracted material (2.0) would move the project from "not clearly prohibited" to "squarely within §2", and would make account action a realistic rather than theoretical outcome. That is the reason it is not the default route.

**What we publish:** code only. No keys, no client ids or secrets, no tokens, no cookies, no `.dlf` files, no prefixes, no account logs, no game data or assets. The repo already has this discipline and a redaction helper with a token deny-list [verified: `Sources/NFS2015Core/NFS2015Redaction.swift:15`]. Extend the packaging gates to refuse any `.dlf`, `machine.ini`, `backgroundservice.ini`, or EA log in a payload.

## 4. Staged plan

### Stage 0 — no credentials, no EA contact, no game runs (3.5 days of work)
All of this is reading and building only. **Nothing here is to be executed against a game until the owner approves game runs**; the experiments are *listed*, not run.
- S0.1 Re-read the fetched user agreement clauses against raw HTML and record exact text (0.5 d). No EA service contact; a legal page only.
- S0.2 Build the `LsxTranscript` stub: a Swift TCP listener for 3216 that sends a challenge, logs every frame, and answers nothing. Pure local code (1 d).
- S0.3 Static census of BF4's SDK surface: which LSX messages `bf4.exe` can send, from its own strings, extending the mbp23 evidence (0.5 d).
- S0.4 Extend `ClientLogProbe` fixtures with the now-known launch markers and a `ClientUpdateDestaging` case; unit tests only, from log fixtures already on disk (1 d).
- S0.5 Port preflight (3215/3216) and `ProcessChainLease`, with tests (0.5 d).
- **Experiments to run only after the owner approves running games** (each needs an existing signed-in prefix, no new sign-in): (E-a) point a game at the stage-0 stub with the EA app absent, and **log the requests without answering any of them** — the stub is a transcriber, never a responder, so it cannot become an emulator; (E-b) confirm NFS2015's exit `170` and empty-`authCode` relaunch reproduce; (E-c) observe `.dlf` mtime and activation-log growth across one real launch; (E-d) check whether 3216 is already bound inside the prefix.

### Stage 1 — Route A supervisor for NFS2015 (3-4 days)
Harden what already ships, on the game that already works. Earliest sign-in requirement: **none new** — stage 1 reuses the owner's existing signed-in NFS2015 prefix.
- `clientUpdating` phase and the destaging fix (wine-rebuild-028), with fixtures (2 d).
- `LicenseObserver` wired into the session as a "licensed" signal, sourced from the activation log (1 d).
- Port preflight and chain-lease integrated; Settings switch `clientLayer` added, defaulting to `.eaApp` (1 d).

### Stage 2 — Battlefield 4 through Route A (4-6 days, plus download time)
- Recipe schema changes: `offerID` list, launcher chain, lease target, ports (1 d).
- **Earliest point the owner's sign-in is needed. Exact action:** open the EA app in the BF4 prefix, sign in once in EA's own window, and accept EA's "Activate Your Game" prompt; then let the EA app install Battlefield 4 **to the external disk** (a path on ExT2, not the internal SSD, which lacks the 32 GiB). The helper is not involved in the sign-in beyond opening the window, and stores nothing from it.
- Determine which `offerIds` actually launch (the owner's E2), confirm the `BFLauncher -> BF4WebHelper -> bf4.exe` chain at runtime, and lease to `bf4.exe` (1-2 d).
- Single-player first. Multiplayer, PunkBuster and Battlelog are deliberately out of scope for stage 2 (2 d of diagnosis, no promises).
- Renderer risk is independent of this design and remains the owner's R1 [verified: PLAN.md:575].

### Stage 3 — Route B, gated (no estimate: n/a until the entry conditions hold)
Entry conditions, all three: (a) EA provides or documents a client identity for third-party clients, **or** a route is found that needs no material extracted from EA software; (b) the owner accepts the §2 position in writing in the repo; (c) stage 0's transcript shows the game's demands are actually satisfiable. Until (a) holds, this stage does not start. If it ever does, the order is: loopback OAuth via `ASWebAuthenticationSession` with tokens in the Keychain -> LSX server answering the census from 1.2 -> live licence request per launch -> launch (the environment the game expects is [unknown]; stage 0 would have to establish it) -> no downloader (reuse EA's).

### 4.4 Fallbacks
Route A **is** the safe path, so the fallback is structural rather than bolted on: the real EA app layer stays, and `clientLayer` is a per-game setting defaulting to `.eaApp`. If Route B never happens, nothing is lost and stages 1-2 still deliver. If it happens and misbehaves for one game, that game flips back to `.eaApp` with one setting. Keep NFS2015 on `.eaApp` as the known-good reference even if BF4 moves.

## 5. Feasibility verdict, biggest unknowns, recommendation

**Verdict.** A native Swift helper that *replaces the EA app's GUI with native supervision* is feasible now and is worth building (Route A). A native Swift helper that *replaces the EA client itself* is **reported to work by an existing open-source project, but is not available to this project on acceptable terms** (Route B): it works only by impersonating EA's first-party client with material extracted from EA's software, and no public route exists to a legitimate third-party client identity. Licence issuance is **not** the blocker in the sense that matters: it stays with EA either way, so nothing here needs to forge anything. The gate that actually stops a third-party client is **authentication** [inferred: from the public project's need for EA's own client identity; no log of the owner's shows what credential the licence request carries, so this is reasoning from one unofficial source, not observation]. That is a sharper and more useful conclusion than "DRM makes it impossible", and it is the opposite of what one would assume going in.

**The three biggest unknowns.**
1. **Whether any legitimate client identity is obtainable.** [unknown] Everything about Route B depends on it, and I found no public answer. This is the one question worth asking EA directly.
2. **What BF4 actually demands over LSX, and whether an unprivileged server could satisfy it.** NFS2015's census shows `GetAuthCode` twice and no `RequestLicense` [verified], which suggests the game does its own activation and needs only an auth code — but BF4 is a different, older SDK generation, and its census is [unknown] until stage 0's stub transcript exists.
3. **Whether the `ClientUpdateDestaging` fix holds under this Wine** — specifically whether `EADestager.exe` completes [unknown, and the owner's docs already flag it as the unverified assumption]. This is the top risk to Route A, and it is already the owner's R3 at High.

**Recommendation: ship Battlefield 4 through the real EA app layer, and build the native supervisor in parallel — not the native client.** Concretely: do stages 0-2. They deliver BF4, fix a known session-killing defect, and add a real licence signal, with zero credential exposure and no EA contact from our code. Do **not** start Route B on a hope; put the client-identity question to EA first, and keep the design slot and the `clientLayer` switch ready in case the answer is yes. This is a partial disagreement with the brief's framing: the owner asked for "something better than driving the EA app's GUI", and stages 0-2 do deliver that — native supervision, native readiness, native licence observation, native lease — but the session itself should stay in EA's client, because the only known way to move it out is the one part of the idea the project should not ship.

**Unverified, and load-bearing:** the user agreement wording (summarising fetch, not raw HTML — re-read the live page before relying on any clause); the LSX listen port 3216 (strong but circumstantial — the owner's own logs show per-connection ports only); whether the EA app passes a constructed environment to the game (`inheritEnv=[false]`, nothing logged); who verifies the licence signature, client or game DLL; whether the grant-time check is enforced; which BF4 `offerIds` launch; BF4's LSX census; and every claim about Maxima's behaviour, which is read-from-source but is still an unofficial reimplementation.
