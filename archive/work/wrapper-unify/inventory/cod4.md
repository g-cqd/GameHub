# CoD4 Wrapper Inventory

## 1. Files: Counts and Purpose

### CoD4Core (14 files, 615 lines)
- `CoD4Bindings.swift` (49 lines): Safe keyboard and mouse action bindings with validation
- `CoD4Catalog.swift` (122 lines): Graphics, audio, gameplay settings catalog with 61 managed settings
- `CoD4GameDrive.swift` (46 lines): Wine dosdevices/g: symlink mapping for private game working directory
- `CoD4LaunchRequest.swift` (11 lines): Validated configuration applied before game session
- `CoD4Mode.swift` (8 lines): Enum for singlePlayer and multiplayer modes with executables and configs
- `CoD4Profile.swift` (15 lines): Player profile metadata (name, saves, backups, installed status)
- `CoD4ProfileFiles.swift` (85 lines): Profile inventory with symlink rejection and bounds checking
- `CoD4ProfileRequest.swift` (21 lines): Profile operations (create, remove, backup, restore, import, export)
- `CoD4ProfileStore.swift` (211 lines): Complete profile management with atomic publication and recovery
- `CoD4ProfileStore+Publication.swift` (54 lines): Interrupted publication recovery with transaction journal
- `CoD4Setting.swift` (60 lines): Single setting definition with kind (choices, number, resolution)
- `CoD4Settings.swift` (155 lines): Config parsing, validation, and application to game files
- `CoD4SettingsStore.swift` (65 lines): Load/apply settings with multiplayer/campaign separation
- `CoD4Snapshot.swift` (11 lines): Launcher state (settings, profiles list, selected profile)

### CoD4Launcher (18 files, 880 lines)
- `CoD4App.swift` (16 lines): Main app entry with Window scene and controller watching
- `CoD4View.swift` (78 lines): Navigation split view with Play/Graphics/Audio/Controls/Profiles/Setup tabs
- `CoD4Model.swift` (271 lines): Main observable model with phase state, profiles, settings, actions
- `CoD4Model+Display.swift` (37 lines): Resolution presets, aspect ratios, filtering
- `CoD4Model+Controllers.swift` (38 lines): GameController detection via notifications
- `CoD4Model+Panels.swift` (95 lines): Game/profile/setup import-export with NSOpenPanel/NSSavePanel
- `CoD4Phase.swift` (15 lines): Enum phases: preparing, ready, playing, needsRosetta, needsGameData, failed
- `CoD4Operation.swift` (30 lines): Operation types: prepare, play, configure, profile, importGame
- `CoD4Serving.swift` (11 lines): Protocol for async boundary to helper
- `CoD4SessionClient.swift` (123 lines): Actor implementing CoD4Serving, spawns session helper subprocess
- `CoD4PlayView.swift` (52 lines): Main play tab with mode/profile selection and maximum quality button
- `CoD4GraphicsView.swift` (31 lines): Graphics groups with resolution/aspect ratio pickers
- `CoD4AudioView.swift` (16 lines): Audio and gameplay settings sections
- `CoD4ControlsView.swift` (36 lines): Controller detection and keyboard/mouse binding configuration
- `CoD4ProfilesView.swift` (51 lines): Profile management (create, backup, export, remove, restore)
- `CoD4SetupView.swift` (25 lines): Portable setup import/export and game data import
- `CoD4RosettaView.swift` (21 lines): Rosetta availability and installation UI
- `CoD4SettingRow.swift` (28 lines): Reusable setting row for choices/number/resolution

### CoD4Session (3 files, 228 lines)
- `SessionMain.swift` (21 lines): Entry point, parses options, invokes CoD4Session.run()
- `SessionOptions.swift` (59 lines): CLI argument parser for --support, --mode, --profile, --request, actions
- `CoD4Session.swift` (102 lines): Helper that holds session lock, prepares prefix, configures game, runs executable

### Tests (4 files, 413 lines)
- `CoD4GameDriveTests.swift` (55 lines): Symlink mapping installation and removal
- `CoD4ProfileTests.swift` (122 lines): Create, backup, restore, export, removal with save preservation
- `CoD4SettingsTests.swift` (100 lines): Settings validation, config parsing, application, renderer isolation
- `CoD4ModelTests.swift` (124 lines): Model actions, pending edits, Rosetta, profiles, display

## 2. UI: Window, Scenes, Tabs, Buttons, Views

**Window setup** (`CoD4App.swift:6-14`):
- Single Window("Call of Duty 4", id: "launcher") with default size 960×780
- Tasks: model.run(), watchControllerConnections(), watchControllerDisconnections(), watchActivation()

**Navigation** (`CoD4View.swift:5-60`):
- NavigationSplitView with sidebar list (185–250 points)
- Tabs: "Play", Graphics, Audio, Controls, Profiles, Setup
- Detail pane shows selected tab content

**Bottom bar** (`CoD4View.swift:35-51`):
- ProgressView when isBusy
- Status message (green if no error, red if failed)
- "Unsaved changes" indicator when hasPendingChanges
- "Return to Game" button when playing
- "Save Settings" button (disabled if !canPlay or !hasPendingChanges)
- "Play" button (disabled if !canPlay, styled .borderedProminent)

**Toolbar** (`CoD4View.swift:55-59`):
- Reload (disabled if isBusy)
- Open Log (disabled if isBusy)

**Confirmation dialogs** (`CoD4View.swift:61-76`):
- "Discard unsaved settings?" with Discard/Cancel
- "Remove this player profile?" with "Back Up and Remove"
- "Restore this profile backup?" with "Restore Backup"

**Tabs content**:
- **Play** (`CoD4PlayView.swift`): Rosetta check, game import prompt, mode/profile selection, resolution/renderer summaries, maximum quality button
- **Graphics** (`CoD4GraphicsView.swift`): Aspect ratio picker, resolution picker, graphics groups with setting rows
- **Audio & gameplay** (`CoD4AudioView.swift`): Audio and gameplay sections with setting rows
- **Controls** (`CoD4ControlsView.swift`): Controller detection, key binding picker, action binding picker, reset/clear binding buttons
- **Profiles** (`CoD4ProfilesView.swift`): Profile picker, campaign save status, backup/export/remove buttons, new profile name field, profile creation/import buttons, backup restoration picker
- **Setup** (`CoD4SetupView.swift`): Portable setup import/export, game folder import, Rosetta section

**SharedLauncher components used**:
- `RosettaSetup`: Rosetta availability and installation
- `ResolutionPreset`: Display resolution presets and aspect ratios
- `DisplayQuality`: Display mode detection for maximum quality
- `AspectRatio`: Aspect ratio enum
- `GameWindow`: bringToFront to switch to running game

## 3. Model/State: Type, Enum Cases, Published Properties, Refresh Mechanism

**Main model** (`CoD4Model.swift:9-271`):
```swift
@MainActor @Observable final class CoD4Model
```

**Phase enum** (`CoD4Phase.swift:1-15`):
```swift
enum CoD4Phase: Equatable {
  case preparing, ready, playing, needsRosetta, needsGameData
  case failed(String)
  var isBusy: Bool { self == .preparing || self == .playing }
}
```

**Published properties** (observable via @Observable):
- `phase: CoD4Phase` (state machine)
- `request: Int` (incremented to trigger model.run())
- `profiles: [CoD4Profile]`
- `selectedProfile: String`
- `mode: CoD4Mode`
- `hasGameData: Bool`
- `settings: CoD4Settings` (mutable, differs from appliedSettings)
- `tab: String`
- `profileSelection: String`
- `backupSelection: String`
- `newProfileName: String`
- `discardConfirmation: Bool`
- `removalConfirmation: Bool`
- `restoreConfirmation: Bool`
- `controllerStatus: String`
- `keySelection: String` (for binding picker)
- `rosetta: RosettaSetup`
- `service: any CoD4Serving`

**Computed properties**:
- `isBusy`, `needsRosetta`, `needsGameData`, `hasPendingChanges`, `errorMessage`, `playProfiles`, `currentProfile`, `backupNames`, `canRestore`, `canManageProfile`, `canCreateProfile`, `canPlay`, `resolutionSummary`, `renderSummary`, `bindingCommand`, `bindingDescription`

**Action enum** (`CoD4Model.swift:11-15`):
```swift
enum Action {
  case helper(CoD4Operation)
  case importGame, importSetup, exportSetup, importProfile, exportProfile
  case installRosetta, refreshRosetta, openLog
}
```

**Refresh mechanism**:
- `run()` async method triggered by `.task(id: model.request)` when request increments
- No polling; state is refreshed after each operation completes
- Rosetta refreshed on app activation (`watchActivation()`)
- Controllers refreshed on notification (`watchControllerConnections()`, `watchControllerDisconnections()`)
- Settings snapshot loaded from helper output (JSON file written to `launcher-state.json`)

## 4. Launcher<->Session Protocol

**Launcher starts session** (`CoD4SessionClient.swift:24-99`):

1. **Executable lookup** (`CoD4SessionClient.swift:70`): 
   ```swift
   process.executableURL = paths.session  // Derived from bundle
   ```

2. **Process arguments** (`CoD4SessionClient.swift:43-68`):
   ```
   [bundle.path, "--support", support.path, action, --request, request.path, --mode, mode.rawValue, --profile, profile]
   ```
   Example: `/path/CoD4Session --support ~/Library/Application\ Support/CoD4Mac --play --request /tmp/request.json --mode singlePlayer`

3. **CLI verbs/flags** (`SessionOptions.swift:21-57`):
   - Actions: `--prepare`, `--play`, `--configure`, `--import-game`, `--profiles`
   - Options: `--support`, `--request`, `--mode`, `--profile`

4. **Exit codes** (`SessionMain.swift:12-15`):
   - `0`: Success
   - `1`: LauncherError or other exception
   - `73`: `.alreadyRunning` (from `LauncherError.alreadyRunning`)

5. **Status/JSON output schema** (`CoD4SessionClient.swift:94-96`):
   ```swift
   CoD4Snapshot {
     settings: CoD4Settings {
       values: [String: String]     // dvar values
       bindings: [String: String]   // key -> command
     }
     profiles: [CoD4Profile]
     selectedProfile: String
   }
   ```
   File: `launcher-state.json` (JSON, read after process exit)

6. **Locking**:
   - Session lock: `session.lock` in support folder (`SessionLock.withLock()`)
   - Game lease: `game-session.json` to track running game state
   - Profile transaction journal: `profile-transaction.json` for atomic operations

## 5. Settings: Catalog, Storage, UI

**Settings catalog** (`CoD4Catalog.swift:2-122`):
- 61 managed settings across 5 groups: Display, Textures & filtering, Lighting & effects, World detail, Renderer
- Audio group: master volume, cinematic volume, sample rate, equalization
- Gameplay: subtitles, blood, brass, crosshair opacity
- Mouse: sensitivity, vertical look, smoothing, acceleration, input/GPU sync

**Storage**:
- **Game config files** (within profile folder):
  - `config.cfg` (single-player)
  - `config_mp.cfg` (multiplayer)
  - Engine dvar format: `seta key "value"` or `bind key "command"`
  
- **Renderer config** (`mtld3d.conf`):
  - Stores renderer-specific settings: `render.scale`, `shader.asyncCompile`
  - Separate from game DVars to preserve Metal-specific overrides

- **Profile storage**:
  - Location: `~/Library/Application Support/CoD4Mac/Saves/profiles/{name}/`
  - Contains `config.cfg`, `config_mp.cfg`, and save folders

- **Portable setup export**:
  - JSON file with only managed `values` and `bindings`
  - No profile/progress data

**Settings UI** (`CoD4SettingRow.swift`):
- Choices: Picker
- Numbers: TextField with range label
- Resolution: TextField
- Help text displayed below each setting

## 6. Profiles / Saves / Backups Features

**Profile operations** (`CoD4ProfileRequest.swift:3-4`):
- `.create`: New empty profile with default bindings
- `.remove`: Move profile to backups
- `.backup`: Create timestamped backup
- `.restore`: Copy backup over active profile
- `.importProfile`: Import from external folder
- `.exportProfile`: Copy profile to external destination

**Profile structure**:
- Location: `~/Library/Application Support/CoD4Mac/Saves/profiles/{name}/`
- Contains: `config.cfg`, `config_mp.cfg`, save folder (e.g., `save/autosave.svg`)
- Valid name: 1–16 alphanumeric chars, spaces, hyphens, underscores (case-insensitive uniqueness)

**Backups**:
- Location: `~/Library/Application Support/CoD4Mac/ProfileBackups/{name}/{uuid}/`
- Named by UUID (timestamp-like)
- Limit: 100 backups per profile
- Created automatically before removal or restoration
- Can be exported to external location

**Campaign saves detection**:
- Looks for `.svg` files (extension check in `CoD4ProfileFiles.inventory()`)
- Stored in `save/` subfolder

## 7. Store Client / EA App / Battlelog / Steam Flow

**None.** CoD4 wrapper does not interact with:
- Steam API
- EA App / Origin
- Battlelog
- Store authentication
- Online progression sync

Game is launched directly with Wine via executable path and profile name via `com_playerProfile` dvar.

## 8. Error Handling: Types, User-Facing Strings

**Error types** (`LauncherError` from LauncherCore):
- Thrown as: `throw LauncherError.operation("message")`
- Also: `LauncherError.alreadyRunning`

**User-facing error strings** (quoted verbatim):

From `CoD4GameDrive.swift`:
- "CoD4's working directory must stay inside its player folder."
- "Wine cannot reverse-map a native cwd through the C:\CoD4 directory symlink."
- "Could not map CoD4's working directory: {error}"
- "CoD4's game drive changed during play; leaving it untouched."
- "Could not remove CoD4's game drive: {error}"

From `CoD4ProfileFiles.swift`:
- "Select a real profile folder without symbolic links."
- "The profile has too many nested folders."
- "The profile contains too many files."
- "Profile links are not supported."
- "The profile contains an unsupported or oversized file."
- "The profile exceeds 512 MiB."
- "Choose a new destination outside the source profile."
- "A profile file escaped its source folder."
- "The profile changed during copying."

From `CoD4ProfileStore.swift`:
- "Use 1–16 letters, digits, spaces, hyphens or underscores for a profile name."
- "The player folder contains more than 100 profiles."
- "Invalid profile backup name."
- "That profile already exists, or the 100-profile limit was reached."
- "Export older backups before creating another backup."
- "A profile path leaves the player folder or contains a symbolic link."
- "Too many profiles or backups; export older backups before adding more."
- "Unexpected item in the profile collection."
- "The profile collection has an unsupported name."
- "Invalid profile transaction."

From `CoD4Settings.swift`:
- "The game configuration is invalid or larger than 1 MiB."
- "The setup contains too many settings or bindings."
- "The setup contains an unsupported setting value."
- "The setup contains an unsupported keyboard binding."
- "Minimum anisotropy must not exceed maximum anisotropy."

From `CoD4SettingsStore.swift`:
- "Select an installed profile."

From `CoD4SessionClient.swift`:
- "Export the setup outside the game's player data folder."

From `SessionOptions.swift`:
- "Usage: CoD4Session <app> --support <folder> <action> [--request <path>] [--mode <mode>] [--profile <name>]"
- "Choose only one operation."
- "Invalid session option."
- "The session needs a player folder, valid mode and operation."
- "This operation requires a request."

From `CoD4Session.swift`:
- "Install Rosetta from the starter before preparing this game."
- "This installation does not include the selected game mode."

From `CoD4Model.swift`:
- "A supported display resolution could not be detected. Select a resolution in Graphics."
- "No session log is available yet."
- "Enter a profile name using 1–16 letters, digits, spaces, underscores, or hyphens."
- "Select the player profile folder containing config.cfg and its save folder."
- "Choose your installed Windows Call of Duty 4 game folder. The starter keeps its working copy and profiles outside the app."

From `CoD4Phase.swift`:
- "Preparing Call of Duty 4…"
- "Ready to play"
- "Call of Duty 4 is running. Close the game to return here."
- "Rosetta is required to run this Intel game."
- "Import your Call of Duty 4 Windows game folder to begin."
- (failed phase shows the error message)

From `CoD4SessionClient.swift` (operation outcome):
- "The operation ended with status {status}. Open Log for details." (if exit status != 0 and != 73)

## 9. Application Support Layout: Paths, State Files, Prefixes

**Support folder base**:
```swift
~/Library/Application Support/CoD4Mac
// Created by: CoD4SessionClient.perform() -> FileManager.createDirectory()
```

**Directory structure**:
```
CoD4Mac/
├── session.lock                      // SessionLock.withLock()
├── game-session.json                 // GameLease for running game tracking
├── launcher-state.json               // CoD4Snapshot (settings, profiles, selected)
├── profile-transaction.json          // Active transaction journal (if interrupted)
├── Logs/
│   └── session-{uuid}.log           // Per-session log (from CoD4SessionClient.perform())
├── Saves/
│   └── profiles/
│       ├── {profile-name}/
│       │   ├── config.cfg           // Single-player config
│       │   ├── config_mp.cfg        // Multiplayer config
│       │   └── save/                // Campaign saves
│       │       └── autosave.svg     // Campaign progress
│       └── active.txt               // Currently selected profile
├── ProfileBackups/
│   └── {profile-name}/
│       └── {uuid}/                  // Timestamped backup
│           ├── config.cfg
│           ├── config_mp.cfg
│           └── save/
├── RuntimeHome/
│   └── Player/                       // Wine runtime data
├── Temporary/                        // Temporary files
└── Prefix/                           // Wine prefix (symlinked to external storage)
    ├── dosdevices/
    │   ├── c: → ../Current/Game/
    │   └── g: → ../../Current/Game/ (installed by CoD4GameDrive)
    └── ... (Wine directory structure)
```

**Current/Game symlink**:
- Actual game data resides in `Prefix/Current/Game`
- Symlink: `dosdevices/c:` points to game data
- CoD4GameDrive additionally creates `dosdevices/g:` pointing to `../../Current/Game`

**State files**:
- `session.lock`: Exclusive lock held during any operation
- `game-session.json`: GameLease (tracks running game)
- `launcher-state.json`: Last committed state (settings, profile list, selected profile)
- `profile-transaction.json`: Transaction journal for atomic profile updates (recovered on startup)
- `.profile-{uuid}/`: Staging area for profile operations
- `.backup-{uuid}/`: Staging area for backup operations
- `.cod4-export-{uuid}/`: Staging area for profile exports

**Path construction** (from code):
- Logs: `support.appendingPathComponent("Logs")` → `CoD4SessionClient.swift:28`
- Profiles: `paths.saves.appendingPathComponent("profiles")` → `CoD4ProfileStore.swift:9`
- Backups: `paths.support.appendingPathComponent("ProfileBackups")` → `CoD4ProfileStore.swift:10`
- Journal: `paths.support.appendingPathComponent("profile-transaction.json")` → `CoD4ProfileStore.swift:11`
- Active profile: `paths.saves.appendingPathComponent("profiles/active.txt")` → `CoD4SettingsStore.swift:44`

## 10. Logs: Location, File Names, Rotation

**Log location**:
```swift
let logs = support.appendingPathComponent("Logs")  // ~/Library/Application Support/CoD4Mac/Logs
let log = logs.appendingPathComponent("session-\(UUID().uuidString).log")
```

**File naming**: `session-{uuid}.log`
- Each operation creates one log file
- UUID ensures uniqueness

**Log content**:
- Standard output and standard error from session helper process
- Session helper inherits stdout/stderr redirection from launcher

**Rotation**: None. Logs accumulate until user manually deletes them.

## 11. First Run / Seed / Prefix Preparation

**First run flow** (`CoD4Session.swift:9-43`):

1. **Acquire session lock** (`CoD4Session.swift:12`):
   ```swift
   SessionLock.withLock(at: paths.support.appendingPathComponent("session.lock"))
   ```

2. **Check game lease** (`CoD4Session.swift:13-14`):
   ```swift
   let lease = GameLease(url: paths.support.appendingPathComponent("game-session.json"))
   try lease.check()
   ```
   Ensures no game is currently running.

3. **Recover transaction** (`CoD4Session.swift:15`):
   ```swift
   try FileTransaction(root: paths.support).recover()
   ```
   Restores any interrupted file operations.

4. **Recover profile transaction** (`CoD4Session.swift:18`):
   ```swift
   let profiles = CoD4ProfileStore(paths: paths)
   try profiles.recover()
   ```
   Recovers interrupted profile operations (via `profile-transaction.json`).

5. **Initialize runtime folders** (`CoD4Session.swift:19-22`):
   ```swift
   for folder in ["RuntimeHome/Player", "Temporary"] {
     try files.createDirectory(at: paths.support.appendingPathComponent(folder), ...)
   }
   ```

6. **Prepare Wine runtime** (`CoD4Session.swift:23-34`):
   ```swift
   let runtime = WineRuntime(paths: paths, output: output)
   let environment = try runtime.environment(prefix: paths.prefix)
   // Verify Rosetta via: arch -x86_64 /usr/bin/true
   ```

7. **Load and prepare game bundle** (`CoD4Session.swift:35-39`):
   ```swift
   let manifest = try BundleManifest.read(from: paths.resources/game-manifest.json)
   let game = try GameInstaller(paths: paths, manifest: manifest).prepare(
     importing: options.action == "--import-game" ? options.request : nil,
     initializePrefix: runtime.initialize)
   ```
   Copies game data from bundle into prefix or imports from user-supplied folder.

8. **Stop runtime and restrict prefix** (`CoD4Session.swift:40-41`):
   ```swift
   try runtime.stop(paths.prefix)
   try GuestIsolation.restrict(prefix: paths.prefix, root: paths.support)
   ```

9. **Create default profile if empty** (`CoD4Session.swift:42-44`):
   ```swift
   if try profiles.list().isEmpty {
     try profiles.perform(.init(action: .create, name: "Player"))
   }
   ```

## 12. Update / Verification of Bundle or Game Files

**Bundle manifest**:
```swift
let manifest = try BundleManifest.read(from: paths.resources.appendingPathComponent("game-manifest.json"))
```
Location: `Resources/game-manifest.json` in bundle.

**Game installer**:
```swift
let game = try GameInstaller(paths: paths, manifest: manifest).prepare(
  importing: options.action == "--import-game" ? options.request : nil,
  initializePrefix: runtime.initialize)
```
- Verifies bundle game data against manifest
- Imports from user-supplied Windows folder if `--import-game` is passed
- Returns URL of prepared game directory

**Verification**:
- Executable check before play (`CoD4Session.swift:64-65`):
  ```swift
  guard files.fileExists(atPath: game.appendingPathComponent(mode.executable).path) else {
    throw LauncherError.operation("This installation does not include the selected game mode.")
  }
  ```
  Ensures `iw3sp.exe` or `iw3mp.exe` exists.

## 13. Renderer/Sidecar/Experiment Switches

**Renderer switches** exposed via settings:

From `CoD4Catalog.swift`:
- `render.scale`: Rendering scale (0.5, 0.67, 0.75, 1) → "Lower scales trade detail for less rendering work."
- `shader.asyncCompile`: Compile shaders asynchronously (false, true) → "On can temporarily omit draws."

**Marked as renderer** (`CoD4Setting.swift:25`):
```swift
var isRenderer: Bool { id == "render.scale" || id == "shader.asyncCompile" }
```

**Renderer config storage**:
- Stored in separate `mtld3d.conf` file (not game config)
- Applied by `CoD4SettingsStore.load()` and `CoD4SettingsStore.apply()`
- Preserved across profile changes

**Wine/Rosetta/MetalFX/DXVK/D3DMetal**:
- Rosetta: Checked and installed via `RosettaSetup`
- Wine: Invoked via `/usr/bin/arch -x86_64 /path/to/wine`
- Runtime environment: Set via `WineRuntime.environment(prefix:)`
- No explicit DXVK, D3DMetal, MetalFX, or other experiment switches in launcher code
- Configuration likely in `mtld3d.conf` (Wine/Metal renderer configuration)

## 14. Game Data: Bundle vs. Application Support

**Game data location**: Copied into Wine prefix at `Prefix/Current/Game/`

**Copy mechanism** (`CoD4Session.swift:37-39`):
```swift
let game = try GameInstaller(paths: paths, manifest: manifest).prepare(
  importing: options.action == "--import-game" ? options.request : nil,
  initializePrefix: runtime.initialize)
```

**Function**: `GameInstaller.prepare()` from LauncherCore
- If `importing` is nil: Copies from bundle `Resources/` to prefix
- If `importing` is URL: Copies from user-supplied Windows folder to prefix
- Returns: URL of the prepared game directory

**Prefix layout**:
```
Prefix/
├── Current/ → (symlink) pointing to Versions/{latest}
│   └── Game/
│       ├── iw3sp.exe
│       ├── iw3mp.exe
│       ├── main/
│       └── zone/
├── dosdevices/
│   ├── c: → ../Current/Game/
│   └── g: → ../../Current/Game/ (installed by CoD4GameDrive at play time)
└── Versions/
    └── {hash}/
        └── Game/  (actual game data)
```

**Game data vs. Saves separation**:
- Game data: `Prefix/Current/Game/` (executable, zones, assets)
- Saves: `Saves/profiles/{name}/` (config.cfg, config_mp.cfg, save/)
- Completely separate paths; saves are never inside prefix

**Symlinks used**:
- `Prefix/Current/` → symlink to `Versions/{hash}/`
- `dosdevices/c:` → symlink to `../Current/Game/`
- `dosdevices/g:` → symlink to `../../Current/Game/` (created by `CoD4GameDrive.install()`)

## 15. Symlink / Unplugged-Volume Handling

**Symlink validation**:

From `CoD4ProfileFiles.swift:6-11`:
```swift
let root = root.standardizedFileURL
guard root.isFileURL, root == root.resolvingSymlinksInPath(),
  try root.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
else { throw LauncherError.operation("Select a real profile folder without symbolic links.") }
```
Rejects profile folders that are symbolic links.

From `CoD4ProfileFiles.swift:33-34`:
```swift
guard values.isSymbolicLink != true else {
  throw LauncherError.operation("Profile links are not supported.")
}
```
Rejects any symlinks within profile tree.

From `CoD4ProfileStore.checked()`:
```swift
let standard = url.standardizedFileURL
guard standard == standard.resolvingSymlinksInPath(),
  standard.path.hasPrefix(paths.support.path + "/")
else {
  throw LauncherError.operation(
    "A profile path leaves the player folder or contains a symbolic link.")
}
```
Ensures profile paths are canonical and don't contain symlinks.

From `CoD4SessionClient.writeSetup()`:
```swift
let resolved = url.standardizedFileURL.resolvingSymlinksInPath()
let privatePath = support.standardizedFileURL.resolvingSymlinksInPath().path
guard resolved.path != privatePath, !resolved.path.hasPrefix(privatePath + "/") else {
  throw LauncherError.operation("Export the setup outside the game's player data folder.")
}
```
Ensures setup exports don't end up back in the private folder.

**Volume handling**:
- No explicit volume checks
- No resolvingSymlinksInPath() on prefix paths (Wine prefix is expected to be local)
- If prefix volume goes offline: Operation would fail when trying to access Wine files or game data
- No graceful handling; errors propagate as `LauncherError.operation()`

**Code for symlink detection**:
- `isSymbolicLink` property check (`CoD4ProfileFiles.swift:31`, `:33`)
- `resolvingSymlinksInPath()` (`CoD4ProfileFiles.swift:9, :16, :63-64, :70`)
- `standardizedFileURL` (`CoD4ProfileFiles.swift:8, :58, :63`)

## 16. Code Duplication / Re-implementation

**Shared with other wrappers**:
- `RosettaSetup`: Also used by NFS2015Launcher (from SharedLauncher)
- `ResolutionPreset`: Shared across all launchers
- `AppPaths`, `LauncherError`, `WineRuntime`, `ProcessCommand`: Core infrastructure
- `SessionLock`, `GameLease`, `FileTransaction`, `GuestIsolation`: Session management
- `BoundedFile`, `ConfigText`: Config file utilities

**CoD4-specific implementations**:
- `CoD4Settings`: Game config parsing (completely tailored to CoD4; NFS games use registry)
- `CoD4Bindings`: Keyboard action bindings (unique to CoD4)
- `CoD4Catalog`: Settings catalog (game-specific)
- `CoD4ProfileStore`: Profile management with `profile-transaction.json` recovery (pattern similar to other launchers but config format varies)
- `CoD4GameDrive`: Creates `dosdevices/g:` symlink (unique to CoD4 layout)

**No duplication detected**: Model structure mirrors NFS2015Model and other launchers but game-specific logic is properly isolated in CoD4Core.

## 17. Tests

**Test coverage** (4 test files, 413 lines):

1. **CoD4GameDriveTests.swift** (2 tests):
   - Game drive maps only the private game and is removed after play
   - External game targets are rejected and existing mappings are preserved

2. **CoD4ProfileTests.swift** (6 tests):
   - Fresh profiles have clean settings and no inherited progress
   - Backup restore removal and export preserve campaign bytes
   - Invalid profile names cannot reach the filesystem (parameterized test)
   - Symlink imports are rejected without creating a profile
   - Interrupted replacement restores the original profile before another operation

3. **CoD4SettingsTests.swift** (11 tests):
   - Maximum quality changes graphics without changing sound or bindings
   - Config editing removes duplicate owned assignments and retains progress and custom binds
   - Untrusted numeric settings are rejected (parameterized)
   - Unknown settings and executable binding commands cannot be imported
   - Imports only managed config fields without copying private or mission data
   - Renderer settings are separate from game dvars and preserve other renderer options
   - Multiplayer leaves campaign-only settings unchanged
   - Anisotropic filtering minimum cannot exceed its maximum
   - Oversized config and invalid resolutions fail before editing

4. **CoD4ModelTests.swift** (8 tests):
   - Preparation respects missing Rosetta and never starts a helper
   - Play uses the chosen mode profile and edited settings
   - Reload and profile selection require explicit discard of pending edits
   - Maximum quality uses physical display pixels and preserves audio
   - Invalid settings fail before helper execution
   - Archived profiles are restorable but absent from play choices
   - Profile backup retains multiplayer mode in the helper request

**Test infrastructure**:
- SessionStub: Captures operations without executing helper
- RosettaStub: Mocks Rosetta availability
- Fixtures: CoD4DriveFixture, CoD4ProfileFixture (temporary folders)
- Testing framework: Swift Testing (@Test, #expect, #require)
