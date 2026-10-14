# BF3 Wrapper Inventory

## 1. Files

| File | Lines | Purpose |
|------|-------|---------|
| Sources/BF3Launcher/BF3Model.swift | 217 | @MainActor @Observable model managing session helper, status polling, and state coordination |
| Sources/BF3Launcher/BF3View.swift | 105 | SwiftUI views, window setup, buttons, and NSApplicationDelegate for quit handling |
| Sources/BF3Session/BF3Session.swift | 465 | Main session helper struct implementing all CLI operations and game/EA app interaction |
| Sources/BF3Session/SessionMain.swift | 19 | Entry point catching LauncherError and exiting with appropriate codes |
| Sources/BF3Session/SessionOptions.swift | 104 | Command-line argument parsing and developer override flags |

**Total: 910 lines, 5 files.**

## 2. UI

**Window/Scene Setup:**
- BF3App: `Window("Battlefield 3", id: "launcher")` at BF3View.swift:98
- Default size: width=600, height=420 (line 103)
- `applicationShouldTerminateAfterLastWindowClosed` returns true (BF3View.swift:70)

**Title:** "Battlefield 3" (BF3View.swift:10)

**Sections/Tabs/Panels:**
- "1. EA app" GroupBox (lines 16-22)
- "2. Battlelog (press Play there)" GroupBox (lines 23-34)
- "Game settings (with the game closed)" GroupBox (lines 35-46)
- Control buttons: Stop, Show Logs (lines 47-52)

**Buttons and Actions:**
- "Install Rosetta": `Task { await model.rosetta.install() }` (line 14) — appears if RosettaSetup.state == .missing
- "Open EA App": calls `model.openClient()` (line 18)
  - Disabled when `model.busy` or `!model.status.prepared`
- "Campaign", "Multiplayer": calls `model.openStore(page:)` (lines 25-26)
  - Disabled when `model.busy` or `!model.status.prepared`
- "Windowed", "Full Screen", "Performance": calls `model.applyPreset()` (lines 37-39)
  - Disabled when `model.busy` or `!model.status.profile` or game is running
- "x87 sidecar" Toggle: calls `model.setSidecar()` (lines 40-43)
- "Stop": calls `model.stop()` (line 48)
  - Disabled when `model.busy` or `!model.status.server`
- "Show Logs": calls `model.openLogs()` (line 49)

**Status Display:**
- Message line showing status/progress (line 11): max 4 lines, secondary color
- Client status line (lines 58-66): "the Windows folder is not ready" / "signed in, Battlefield 3 ready" / "running, not signed in" / "starting" / "not running"
- Browser detection (lines 28-29): displays browser name or "needs Chrome, Chromium, Edge, Brave or Vivaldi"
- Progress indicator when busy (line 51)

**Views from SharedLauncher:**
- RosettaSetup: used at BF3Model.swift:25, provides .state and .install()

## 3. Model/State

**Model Type:** `@MainActor @Observable final class BF3Model` (BF3Model.swift:20-21)

**Status Structure: BF3Status (Decodable, Equatable)**
Fields decoded from JSON at BF3Model.swift:8-17:
- `prepared: Bool = false` — whether Windows folder is placed
- `server: Bool = false` — whether Wine server is running
- `service: Bool = false` — whether EA app's local service is answering
- `running: [String] = []` — list of running executable names
- `sidecar: Bool = true` — whether x87 sidecar is enabled
- `browser: String?` — name of installed browser (e.g., "Chrome")
- `profile: Bool = false` — whether game settings profile exists
- `client: String = "notRunning"` — one of: "notRunning", "starting", "notReady", "ready"

**Published Properties (via @Observable):**
- `status: BF3Status` — decoded from `--status` JSON output
- `message: String` — status/progress message for user display
- `busy: Bool` — whether a helper action is in progress
- `clientSeen: Bool` (private) — tracks if EA app was seen since last start
- `quietPolls: Int` (private) — polls without activity before auto-stop

**Status Refresh:**
- Polling interval: 5 seconds (BF3Model.swift:148)
- Triggered by `refresh()` async method (lines 87-95), which calls `--status` and decodes JSON from helper's last output line
- Automated via `supervise()` background task (lines 146-162):
  - Polls every 5 seconds
  - Tracks when EADesktop.exe or bf3.exe are active
  - Auto-stops prefix after 2 quiet polls (no activity) following EA app/game closure (anti-cheat service cleanup)

## 4. Launcher<->Session Protocol

**How Launcher Starts Session:**

Launcher executes helper at `/BF3Launcher.app/Contents/Helpers/BF3Session` (BF3Model.swift:48).

`runHelper()` static method (lines 52-70):
- Creates Process with `executableURL = helper`
- Arguments: `[bundle.path, "--support", support.path] + arguments`
  - bundle.path: app bundle root
  - support.path: Application Support folder path
- Pipes stdout/stderr to single stream (lines 60-61)
- Waits for exit, returns (terminationStatus: Int32, output: String)

Example invocation in BF3Model:
- `perform(["--prepare"], ...)` → Session runs `--prepare` (line 102)
- `perform(["--start-client"], ...)` → Session runs `--start-client` (line 115)

**CLI Verbs (SessionOptions.swift line 14-17, BF3Session.swift line 71-86):**

Actions (from SessionOptions.actions):
- `--prepare`: place prefix, verify registry and shims
- `--start-client`: start EA app in prefix, wait for local service, optionally sign in
- `--open-store`: open Battlelog page in browser after ensuring EA app is ready
- `--status`: output JSON status line
- `--stop`: shut down Wine server for this prefix
- `--preset`: apply settings preset (windowed/fullscreen/perf)
- `--sidecar`: enable/disable x87 sidecar
- `--plan`: print what each step would do

**Valued Actions (SessionOptions.swift line 18):**
- `--open-store <page>`: "singleplayer" or "multiplayer"
- `--preset <name>`: "windowed", "fullscreen", "perf", or "show"
- `--sidecar <on|off>`: "on" or "off"

**Exit Codes (SessionMain.swift lines 11-13, BF3Session.swift referenced):**
- `0`: success
- `1`: operation failed or unrecognized error
- `2`: EA app service did not answer in time (from startClient line 204)
- `3`: EA app service answered but sign-in/game-ready check failed (from startClient line 207)
- `73`: session lock is held (special case, tried again; BF3Model.swift:196)

**Status Output Schema (BF3Session.swift lines 347-378):**

JSON output from `--status`, one line with fields:
```json
{
  "browser": "Chrome|null",
  "client": "notRunning|starting|notReady|ready",
  "prepared": true|false,
  "profile": true|false,
  "running": ["EADesktop.exe", "bf3.exe"],
  "server": true|false,
  "service": true|false,
  "sidecar": true|false
}
```

Field meanings:
- `prepared`: isPrepared (prefix placed or developer override)
- `server`: serverIsRunning() && isPrepared
- `service`: state != .notAnswering
- `running`: PrefixActivity.running() of watched programs, sorted
- `sidecar`: settings.sidecar
- `browser`: browser name if Chromium-family found, else null
- `profile`: game settings file exists
- `client`: "notRunning"/"starting"/"notReady"/"ready" based on server state and service readiness

**Socket/Lock/PID Files:**
- Session lock: `paths.support.appendingPathComponent("session.lock")` (BF3Session.swift:77)
  - Lock protects `--start-client`, `--stop`, `--preset`, `--sidecar` operations
  - `--status` and `--plan` do not take lock (line 72)
- Wine socket: implied by `PrefixActivity.serverIsRunning(prefix: prefix)` (line 139)
  - Checks via wine socket or wineserver process
- Browser profile: `paths.support.appendingPathComponent("BrowserProfile")` (line 257, from game manifest storeBrowser.profileFolder)
- Settings file: `paths.support.appendingPathComponent("settings.json")` (line 44)

## 5. Settings

**Settings Catalog:**

BF3Session.swift lines 47-49:
```swift
struct Settings: Codable {
  var sidecar = true
}
```

Single boolean setting for x87 sidecar enablement.

**Storage:**
- File: `paths.support.appendingPathComponent("settings.json")` (line 44)
- Format: JSON, read via JSONDecoder (line 52), written via JSONEncoder with atomic write (line 340)
- Default: `Settings()` with `sidecar = true` if file does not exist (line 52)

**Settings UI:**
- Toggle in "Game settings" GroupBox: "x87 sidecar" (BF3View.swift:40-43)
- Binding calls `setSidecar(on)` which executes `--sidecar on|off` and reloads
- Toggle disabled when game is running (line 44)

## 6. Profiles / Saves / Backups

**Game Settings Profile:**
- Game profile file: `prefix.appendingPathComponent(game.settingsProfile)`
  - From manifest: "drive_c/users/crossover/Documents/Battlefield 3/settings/PROF_SAVE_profile"
  - BF3Session.swift line 45
- Profile existence checked at line 298 before applying presets
- Profile is a text file parsed by TextProfilePreset (line 305)

**Preset Application (BF3Session.swift lines 296-332):**
- `preset()` function with name: "windowed", "fullscreen", "perf", or "show"
- Before applying, checks:
  - Profile exists (line 298)
  - Game is not running (line 313)
- Backup created: `profile.deletingLastPathComponent().appendingPathComponent(profile.lastPathComponent + ".bak-\(timestamp())")` (line 323)
- Backup format: `.bak-YYYYMMDD-HHmmss` suffix
- Applies TextProfilePreset.apply() to text (line 317), writes atomically (line 326)
- Prints before/after diff showing changed keys
- Presets from manifest: "windowed" (1920x1200 windowed), "fullscreen" (main display mode), "perf" (1920x1200 with low graphics quality)

**No user-accessible save management beyond preset backups.**

## 7. Store Client / EA App / Battlelog / Steam Flow

**Store Client: EA app (Electronic Arts/EA Desktop)**
From bf3.json storeClient section:
- Name: "EA app"
- Windows path: "Program Files/Electronic Arts/EA Desktop"
- Client executable: "EA Desktop/EADesktop.exe"
- Client arguments: ["--in-process-gpu"]
- Launcher executable: "EA Desktop/EALauncher.exe" (not used in code)
- Launch URL: "origin2://game/launch/?offerIds={offer}" with offerID "70619" or "71067"
- Sign-in evidence: "AppData/Local/Electronic Arts/EA Desktop"
- Readiness log: "ProgramData/EA Desktop/Logs/EADesktop.log"
- Readiness check: looks for "[STARTUP]" marker and "login"/"client.boot.ready" events
- Readiness timeout: 180 seconds
- Game root: "Program Files/EA Games/Battlefield 3"
- Launch chain watched: ["BF3WebHelper.exe", "bf3.exe"]
- Lease target (game process): "bf3.exe"
- Local service URL: "http://127.0.0.1:3215/ping"
- Service origin for browser auth: "https://battlelog.battlefield.com"
- Service reply expected: "pong"

**Flow in BF3Session.startClient() (lines 157-208):**

1. Check prefix is prepared (line 158)
2. If Wine server already running:
   - Check if EA app process still exists (line 165)
   - If not, throw error (lines 166-168)
   - If yes, print "already running" (line 170)
3. If Wine server not running:
   - Check Rosetta available (line 172)
   - Find EA app executable in prefix (lines 173-176)
   - Create logs and temp folders (lines 177-180)
   - Start EA app process with wine, x87 sidecar on/off per settings (lines 182-194)
   - Print start message with sidecar state and log file (lines 191-192)
4. Wait for local service to answer (lines 196-207):
   - Uses `service.wait(stillStarting: alive)` with lambda that checks process or server running
   - Timeout: service.seconds (180s)
   - If timeout, suggest user sign in and return exit code 2 (line 204)
   - If service answers, print message (line 206)
5. Call `waitUntilReady()` to check sign-in and game listing (line 207)
   - Exit code 0 on success, 3 on failure (lines 207, 252-254)

**waitUntilReady() (lines 212-232):**
- Polls service state in loop, checking for `.ready` state
- States: `.ready`, `.notAnswering`, `.notReady`
- `.ready`: service answers and player is signed in and game listed (prints line 217, returns true)
- `.notAnswering`: service stopped (prints line 220, returns false)
- `.notReady`: still waiting, checks elapsed time vs service.seconds timeout (line 223)
  - If timeout, print sign-in/game-listing message (lines 224-226) and return false
  - If within timeout, sleep 3s and poll again (line 229)

**Battlelog (Browser/Store) Flow in openStore() (lines 234-278):**

1. Resolve page (name like "singleplayer" or "multiplayer") from game manifest
2. Find installed Chromium-family browser (uses NSWorkspace.urlForApplication) (lines 238-240)
   - Supported: Chrome, Chromium, Edge, Brave, Vivaldi (from manifest storeBrowser.browsers)
   - Error if none found (lines 242-244)
3. Check if service is ready:
   - If not, call startClient() first (lines 248-254)
   - Exit with code from startClient if it failed
4. Create/use browser profile folder (line 257)
5. Set up browser launch configuration (lines 259-262):
   - Arguments: storeBrowser.arguments(profile, page) with userAgent and URL
   - Creates new instance
   - Activates window
   - Does not add to recent items
6. Launch browser with DispatchSemaphore (lines 264-269):
   - Waits up to 30s for completion (line 270)
   - Propagates error if set (lines 273-274)
7. Print success message (line 276), return 0

**No Steam integration; EA app and Battlelog only.**

## 8. Error Handling

**Error Types:**
- LauncherError (from LauncherCore): only `.operation(String)` and `.alreadyRunning` used
  - `.operation`: user-facing error message
  - `.alreadyRunning`: special case, exit code 73

**Launcher Error Handling (BF3Model.swift lines 73-85, 169-180):**
- `perform()` catches helper output
- Last line of output becomes message (or default "Done." / "The operation failed (n).") (line 80)
- Logs all operations and output (line 81)
- Returns whether status == 0

**User-Facing Error Strings (verbatim):**

From BF3Model:
- Line 103-104: "Preparing the Windows folder. The first start copies about 24 GB and verifies it; this takes a few minutes."
- Line 107: "Ready. Open the EA app, sign in, then open Battlelog and press Play there."
- Line 115: "Starting the EA app and waiting for its local service."
- Line 124-125: "Opening Battlelog." / "Starting the EA app first; Battlelog opens once it is signed in and lists the game."
- Line 129: "Applying the settings preset."
- Line 133: "Saving the x87 sidecar choice."
- Line 139: "Stopping the Windows side of this app."
- Line 158: "The EA app was closed, so the Windows side was stopped."
- Line 76: Quit confirmation: "Quit and stop Battlefield 3?" + "Quitting stops the EA app and the game, so PunkBuster does not keep running."

From BF3Session:
- Line 24: "This helper belongs to a different game."
- Line 91: "Using the developer prefix in place; nothing is placed."
- Line 95: "The Windows folder is ready."
- Line 100: "The Windows folder is ready." (after placement)
- Lines 115-117: "registry X [path] Y is missing" (prefix check)
- Line 127: "game-folder file X differs or is missing" (shim check)
- Line 153: "Rosetta is not installed. Install it from the starter, then try again."
- Line 159: "Prepare the Windows folder first."
- Lines 167-168: "Windows programs of this app are still running without the EA app. Press Stop, then try again."
- Line 170: "The EA app is already running."
- Line 175: "The EA app is missing from the Windows folder."
- Line 184: "Could not create the client log."
- Line 192: "Started the EA app (x87 sidecar on/off); log client-YYYYMMDD-HHmmss.log."
- Line 196: "Waiting for its local service. Sign in in the EA window if it asks."
- Lines 202-203: "The EA app did not answer in time. Sign in in its window, then try again."
- Line 206: "The EA app local service answered after about X s."
- Line 217: "Signed in; the EA app lists Battlefield 3 as installed and ready."
- Line 220: "The EA app stopped answering."
- Lines 225-226: "The EA app runs but is not signed in, or does not list Battlefield 3 as installed. Sign in in its window, then open Battlelog again."
- Line 249: "Starting the EA app first; Battlelog opens when it is ready."
- Line 252: "Battlelog was not opened."
- Line 244: "Battlelog needs a Chromium-family browser (Chrome, Chromium, Edge, Brave or Vivaldi). Safari blocks its call to the EA app."
- Line 271: "The browser did not start in time."
- Line 274: "Could not open the browser: X"
- Line 282: "Nothing of this app is running."
- Line 292: "Stopped the Windows side of this app."
- Line 300: "The game has no settings yet: start it once from Battlelog and quit it, then apply a preset."
- Line 310: "There is no preset named X."
- Line 314: "Quit the game first: it rewrites its settings when it exits."
- Line 320: "X: the settings already match; nothing changed."
- Line 330: "Applied X. The previous settings are in Y."
- Line 335: "Use on or off."
- Line 341: "x87 sidecar X for the next start of the EA app."

SessionOptions parsing errors (lines 22-60):
- "Usage: BF3Session <app> --support <folder> <action> [value]"
- "Choose only one operation."
- "Invalid session option: X"
- "The session needs a player folder and an operation."
- "This operation needs a value."
- (Debug builds only) "X needs an absolute path."
- "Developer overrides are not available in this build."

SessionMain (lines 12-16):
- Line 12: "Could not complete the Battlefield 3 operation: X"

## 9. Application Support Layout

**Base Folder Construction (BF3Model.swift lines 34-44):**
```swift
static func supportFolder(
  environment: [String: String] = ProcessInfo.processInfo.environment,
  home: URL = FileManager.default.homeDirectoryForCurrentUser
) -> URL {
  if let override = environment[BF3_SUPPORT_FOLDER], override.hasPrefix("/"),
    !override.split(separator: "/").contains("..")
  {
    return URL(fileURLWithPath: override, isDirectory: true).standardizedFileURL
  }
  return home.appendingPathComponent("Library/Application Support/BF3Mac")
}
```

**Default path:** `~/Library/Application Support/BF3Mac` (unless overridden by `BF3_SUPPORT_FOLDER` env var)

**Subdirectories and State Files:**

From BF3Session and manifest:

1. `Logs/session.log` — appended log of all session helper operations (BF3Model.swift:171-179, BF3Session.swift:43)
2. `Logs/client-YYYYMMDD-HHmmss.log` — EA app stdout/stderr when started (line 182)
3. `session.lock` — lock file for session operations (line 77)
4. `settings.json` — settings file containing `{ "sidecar": true|false }` (line 44, lines 340)
5. `RuntimeHome/Player` — game/EA app home directory (line 58)
6. `Temporary` — temp folder for game/EA app (line 59)
7. `BrowserProfile/` — Battlelog browser profile folder (line 257)
8. `prefix/` — the Wine prefix, placed at this path or located via `options.developer.prefix` (lines 35-36)
   - Subdirectories from placement: drive_c, system32, etc. (managed by PreparedPrefixPlacement)
   - Game files in `drive_c/Program Files/EA Games/Battlefield 3/`
   - Settings profile at `drive_c/users/crossover/Documents/Battlefield 3/settings/PROF_SAVE_profile`

**File and Path Construction Examples from Code:**

- Line 43: `support.appendingPathComponent("Logs")` → `~/Library/Application Support/BF3Mac/Logs`
- Line 44: `paths.support.appendingPathComponent("settings.json")` → `~/Library/Application Support/BF3Mac/settings.json`
- Line 45: `prefix.appendingPathComponent(game.settingsProfile)` → `~/Library/Application Support/BF3Mac/prefix/drive_c/users/crossover/Documents/Battlefield 3/settings/PROF_SAVE_profile`
- Line 49: `support.appendingPathComponent("Logs")` → logs directory
- Line 58: `paths.support.appendingPathComponent("RuntimeHome/Player")` → home folder
- Line 59: `paths.support.appendingPathComponent("Temporary")` → temp folder
- Line 120-121: `root.appendingPathComponent("drive_c").appendingPathComponent(game.storeClient.gameRoot)` → `~/Library/Application Support/BF3Mac/prefix/drive_c/Program Files/EA Games/Battlefield 3`
- Line 257: `paths.support.appendingPathComponent(plan.profileFolder)` → `~/Library/Application Support/BF3Mac/BrowserProfile`
- Line 323-324: `profile.deletingLastPathComponent().appendingPathComponent(profile.lastPathComponent + ".bak-\(timestamp())")` → `~/Library/Application Support/BF3Mac/prefix/drive_c/users/crossover/Documents/Battlefield 3/settings/PROF_SAVE_profile.bak-YYYYMMDD-HHmmss`

## 10. Logs

**Log Files:**

1. **session.log** (BF3Model.swift lines 169-180, BF3Session.swift line 43)
   - Location: `~/Library/Application Support/BF3Mac/Logs/session.log`
   - Format: appended text, each operation records: `== <Date> <arguments>\n<output>\n`
   - Created if missing, appended if exists
   - Contains all helper invocations and their output

2. **client-YYYYMMDD-HHmmss.log** (BF3Session.swift lines 182-194)
   - Location: `~/Library/Application Support/BF3Mac/Logs/client-YYYYMMDD-HHmmss.log`
   - Format: EA app stdout/stderr combined
   - Created fresh for each `--start-client` operation
   - Opened with FileHandle and passed to ProcessCommand as output stream

**Log Rotation:**
- No explicit rotation; logs are appended indefinitely
- Client logs use timestamp suffix so new start creates new file
- Session.log accumulates all operations

**Log Access:**
- `openLogs()` (BF3Model.swift lines 164-166): creates Logs directory and opens it in Finder

## 11. First Run / Seed / Prefix Preparation

**Prefix Template Source:**
From bf3.json prefixSeed:
- Input: "tunedBundle" → `/Volumes/ExT2/Bundles/Battlefield3-Tuned-20261009`
- Source: "prefix"
- Path in bundle: "Game"
- Settings profile: "drive_c/users/crossover/Documents/Battlefield 3/settings/PROF_SAVE_profile"

**Preparation Steps (BF3Session.prepare() lines 89-101):**

1. Check if developer override prefix in use (line 90-92)
   - If yes, print "Using the developer prefix in place; nothing is placed." and return 0
2. Check if placement already done (line 94)
   - If yes, print "The Windows folder is ready." and return 0
3. Place prefix via PreparedPrefixPlacement.place() (line 98)
   - Prints progress messages
4. Check prefix for problems (line 99)
   - Verifies registry records (line 115-118)
   - Verifies game shim files (line 122-129)
   - Prints "Check: X" for each problem found
5. Print "The Windows folder is ready." (line 100)

**Prefix Problems Check (lines 105-130):**
- Registry hives: reads each hive file and checks for required records
  - From manifest prefixRegistry: system.reg and user.reg entries
  - Prints "registry X [Y] Z is missing" for each missing entry
- Game shims: verifies d3d11.dll checksum
  - From manifest gameShims: d3d11.dll with SHA256 hash
  - Prints "game-folder file X differs or is missing"

**No explicit first-run seed state file; readiness is inferred from whether prefix is placed and checks pass.**

## 12. Update / Verification of Bundle or Game Files

**Verification in Prefix Problems (BF3Session.prefixProblems() lines 105-130):**

Registry verification (lines 109-118):
- Reads hive files (system.reg, user.reg) from prefix
- For each required registry record from manifest, checks if it's recorded
- Uses `record.isRecorded(in: hiveText)` to detect presence
- Reports missing as "registry X [Y] is missing"

Game shim verification (lines 122-129):
- From manifest gameShims: d3d11.dll
- Checks SHA256 hash via FileDigest.sha256(of: url, size: size)
- Compares to expected sha256 from manifest
- Reports differences as "game-folder file X differs or is missing"

**No automatic update mechanism; verification only on `--prepare` or `--plan` commands.**
**No bundle version checking or signature verification in code.**

## 13. Renderer/Sidecar/Experiment Switches

**Renderer Configuration:**
From bf3.json renderers section: all use DXGI->DXMT backend for bf3.exe, BF3WebHelper.exe, EALaunchHelper.exe, EAGEP.exe, EADesktop.exe, EACefSubProcess.exe

**Environment Variables (BF3Session.environment() lines 55-65):**
- Built via LaunchEnvironment.make() from LauncherCore (line 56)
- Parameters:
  - paths: bundle, resources, support paths
  - prefix: Wine prefix root
  - home: RuntimeHome/Player
  - temporary: Temporary folder
  - tuning: game.runtimeTuning (WINE_TF_EMULATION env vars from manifest)
  - renderers: all DXGI->DXMT rules
  - usesSidecar: settings.sidecar boolean

**x87 Sidecar Switch:**
- Exposed via `--sidecar on|off` CLI (lines 334-343)
- Stored in settings.json as `sidecar: bool` (line 339)
- Default: true (line 48)
- UI Toggle in "Game settings" (BF3View.swift:40-43)
- Passed to LaunchEnvironment via `usesSidecar: settings.sidecar` (line 60)
- If sidecar on, `ROSETTA_X87_PATH` set to developer override path if provided (lines 61-63)
- EA app launched with `--in-process-gpu` argument (from manifest storeClient.clientArguments)
- x87 sidecar toggled with game closed (line 44 in BF3View disables toggle if bf3.exe running)

**Runtime Tuning (from manifest runtimeTuning):**
- WINE_TF_EMULATION=1
- WINE_TF_MAX_STEPS=0
- WINE_TF_MAX_NS=0

## 14. Game Data: Copied or In-Place

**Prefix Template Placement (not game data installation):**
- Prefix placed via PreparedPrefixPlacement (BF3Session.swift lines 30-34)
- Template source from manifest prefixSeed: "Game" folder in tuned bundle
- Manifest specifies 24 GB copy as first start (BF3Model.swift line 104: "The first start copies about 24 GB and verifies it")

**Game Data Location:**
From manifest storeClient.gameRoot: "Program Files/EA Games/Battlefield 3"
- Game data placed in prefix under `drive_c/Program Files/EA Games/Battlefield 3/`
- No copyGameData call in code; game data is part of the bundled prefix template

**Game Executable:**
- From manifest gameExecutable: "bf3.exe"
- Located at: `drive_c/Program Files/EA Games/Battlefield 3/bf3.exe`
- Found via `game.clientWindowsPath(prefix: prefix)` (line 173)

**No runtime game file copying; all files bundled in prefix template and verified on first run.**

## 15. Symlink / Unplugged-Volume Handling

**Path Resolution:**

In BF3Model.supportFolder() (lines 34-44):
- Uses `.standardizedFileURL` on override path (line 41) — resolves symlinks
- Default path constructed directly without symlink checking

**Support Path Used Directly:**
- No resolvingSymlinksInPath or attributesOfItem calls for support folder
- Volume checks: none visible in BF3 code

**Prefix Volume Handling:**
- Prefix can be developer override (options.developer.prefix) (line 35)
- No symlink detection or volume mount checks on prefix path
- PrefixActivity.serverIsRunning() checks for wine socket/process, not path validity

**What Happens if Volume Missing:**
- prefixProblems() would fail to read hive files (line 112: try? String(contentsOf:)) — returns "" on error
- Registry checks would find "missing" for all required records (line 116)
- Game shim checks would report "differs or is missing" (line 127)
- serverIsRunning() would return false, so status reports server=false
- startClient() would fail with "Prepare the Windows folder first" (line 159)

**No explicit volume mount detection or offline-volume handling logic.**

## 16. Duplicated Code from LauncherCore/SharedLauncher

**RosettaSetup Usage:**
- From SharedLauncher, used in BF3Model (line 25)
- BF3Model.rosetta.state checked against .missing (BF3View.swift:13)
- BF3Model.rosetta.install() called on button press (line 14)
- BF3Session.requireRosetta() reimplements check: runs `/usr/bin/arch -x86_64 /usr/bin/true` (lines 144-155)
  - Counterpart: SharedLauncher likely has RosettaSetup struct with same logic
  - Duplication: BF3Session reinvents the check instead of calling a LauncherCore helper

**Process Management:**
- BF3Model.runHelper() manually creates Process, sets up pipes, waits for exit (lines 56-69)
- BF3Session.startClient() manually creates ProcessCommand and starts (lines 187-190)
- BF3Session.stop() manually creates ProcessCommand (lines 287-290)
- ProcessCommand from LauncherCore is used directly
- Counterpart: LauncherCore.ProcessCommand likely wraps Process setup; not fully unified in BF3

**Status JSON Encoding:**
- BF3Model.refresh() manually decodes JSON (line 91)
- BF3Session.status() manually builds and encodes Status struct (lines 346-378)
- Counterpart: likely StatusEncoder/Decoder in LauncherCore for other wrappers

**Session Lock:**
- BF3Session uses SessionLock.withLock (line 77) from LauncherCore
- Properly delegated, no duplication

**Wine/Prefix Operations:**
- PrefixActivity used consistently (BF3Session, BF3View) for process querying
- AppPaths, PreparedPrefixGame, PreparedPrefixPlacement from LauncherCore
- No apparent duplication

**No Core Module Specific to BF3:**
- Unlike NFS2015 (NFS2015Core), CoD4 (CoD4Core), FarCry2 (FarCry2Core), BF3 has no BF3Core target
- All game-specific data sourced from manifest (bf3.json)
- Unlike other wrappers, BF3 does not have game-specific types in a Core module

## 17. Tests Covering This Wrapper

**No tests found for BF3.**

From Package.swift targets (lines 42-65), test targets listed:
- LauncherCoreTests
- LauncherUITests
- HubCoreTests
- CoD4CoreTests
- NFS2015CoreTests
- NFS2015SessionTests
- NFS2015UITests
- FarCry2CoreTests
- FarCry2SessionTests
- FarCry2UITests
- CoD4UITests

**No BF3SessionTests or BF3UITests defined.**
**BF3 has no test coverage in the suite.**

---

## Summary of Key Facts

**Model/State (Section 3):**
- Single status: BF3Status with 8 fields (prepared, server, service, running, sidecar, browser, profile, client)
- Refresh: 5-second polling via supervise() task calling --status
- Auto-stop: after 2 quiet polls once EA app/game exits

**Launcher↔Session Protocol (Section 4):**
- 7 CLI verbs: --prepare, --start-client, --open-store, --status, --stop, --preset, --sidecar, --plan
- Exit codes: 0=success, 2=service timeout, 3=readiness fail, 73=lock held
- Status JSON: prepared/server/service/running/sidecar/browser/profile/client fields
- Lock: session.lock prevents concurrent ops (except --status/--plan)

**Error Handling (Section 8):**
- User-facing strings: "Prepare the Windows folder first", "EA app did not answer in time", "Battlelog needs a Chromium-family browser", etc.
- No structured errors; strings from service output or exceptions
- Helper output last line becomes user message

**Application Support (Section 9):**
- Base: ~/Library/Application Support/BF3Mac (or BF3_SUPPORT_FOLDER override)
- Files: Logs/session.log, Logs/client-*.log, session.lock, settings.json, BrowserProfile/, prefix/
- Settings: JSON { "sidecar": bool }

**Game Data (Section 14):**
- Bundled in prefix template (24 GB, verified on first run)
- No runtime copying; prefixProblems() verifies registry/shims only

**Symlinks (Section 15):**
- supportFolder() uses standardizedFileURL on override
- No volume mount checks; would fail gracefully if prefix unreachable

**Duplication (Section 16):**
- RosettaSetup from SharedLauncher, but BF3Session.requireRosetta() duplicates check
- Process creation scattered; ProcessCommand from LauncherCore not fully unified
- Status JSON manual encode/decode; likely duplicates LauncherCore pattern

