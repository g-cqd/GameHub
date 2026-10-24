# Far Cry 2 Launcher Wrapper Inventory

## 1. Files

### FarCry2Launcher (16 files, 1,118 lines total)
- **FarCry2App.swift** (14 lines): Main SwiftUI app entry point; creates Window("Far Cry 2") at 940×760.
- **FarCry2Model.swift** (254 lines): Core @Observable state machine with Action enum, phase tracking, settings management, operation sequencing.
- **FarCry2Model+Display.swift** (39 lines): Resolution/aspect ratio computation for display picker.
- **FarCry2Model+Dock.swift** (43 lines): Game window positioning via GameDock accessibility API; GameLease tracking.
- **FarCry2Model+Panels.swift** (55 lines): File import/export (game folder, setup.json) with NSOpenPanel/NSSavePanel.
- **FarCry2Model+ShaderCache.swift** (81 lines): Shader cache export/import, reset, status computation.
- **FarCry2Phase.swift** (15 lines): Status enum: preparing, ready, playing, needsRosetta, needsGameData, failed(String).
- **FarCry2Operation.swift** (19 lines): Helper operation types: prepare, play, configure, backups, shaderCache, importGame.
- **FarCry2Serving.swift** (11 lines): Async protocol boundary for session operations.
- **FarCry2SessionClient.swift** (124 lines): Actor implementing FarCry2Serving; launches session subprocess with --support and JSON request files; handles exit code 73 (alreadyRunning).
- **FarCry2View.swift** (105 lines): NavigationSplitView with sidebar tabs and detail panes; tabs: Play, Graphics, Shader cache, Game view, Mac & MetalFX, Game & controls, Cheats, Saves & backups, Setup.
- **FarCry2PlayView.swift** (51 lines): Welcome screen, resolution/renderer summary, Rosetta/game-data prompts, shader cache notice.
- **FarCry2GameView.swift** (97 lines): Game window embedding with DockAnchor NSViewRepresentable; accessibility permission check.
- **FarCry2GraphicsView.swift** (39 lines): Aspect ratio and resolution pickers; graphics settings form.
- **FarCry2PanelView.swift** (25 lines): Generic tab for catalog groups (Mac, Game, Cheats); notice text.
- **FarCry2RosettaView.swift** (21 lines): Rosetta availability check and install/refresh buttons.
- **FarCry2SavesView.swift** (51 lines): Backup list, restore/remove actions, set-aside folder notice.
- **FarCry2SetupView.swift** (25 lines): Import/export setup and game folder sections.
- **FarCry2SettingRow.swift** (39 lines): VStack row for choices/resolution/integer/decimal setting kinds.
- **FarCry2ShaderCacheView.swift** (45 lines): Cache summary, export/import, reset, first-launch notice.

### FarCry2Session (4 files, 308 lines total)
- **SessionMain.swift** (21 lines): Entry point; parses args, constructs AppPaths(.farcry2), runs FarCry2Session with output redirect to log; exits 73 on .alreadyRunning, else 1 or 0.
- **SessionOptions.swift** (61 lines): Struct parsing command-line: `<bundle> --support <folder> [--action] [--request <file>]`. Actions: --prepare, --play, --configure, --import-game, --backups, --shader-cache.
- **FarCry2Session.swift** (156 lines): Core session worker; SessionLock enforces exclusivity; GameLease tracks running game; prepares prefix, applies settings via FarCry2SettingsStore, runs game via ProcessCommand (arch -x86_64), harvests shader cache before/after.
- **FarCry2Session+ShaderCache.swift** (70 lines): Helper methods: shaderCache() reads ShaderCacheKey from resources, report() logs cache status (unavailable/cold/warm), perform() handles reset/export/import, attempt() wraps cache errors.

### FarCry2Core (16 files, 2,545 lines total)
- **FarCry2Catalog.swift** (394 lines): Static catalog of all managed settings with groups (Display, Color, Image quality, Detail levels, Display & MetalFX, Keyboard, Renderer, Gameplay, Mouse, Audio, Launch options, Cheats). Each FarCry2Setting defines id, title, group, default, kind (choices/resolution/integer/decimal), storage (profile/renderer/registry/launcher), launch method, help text.
- **FarCry2Settings.swift** (216 lines): Codable values dict; init() reads from GamerProfileDocument (XML), renderer mtld3d.conf, registry user.reg, launcher JSON. validate() rejects unknown settings. applying() mutates profile with chosen values. launchPlan() collects environment/arguments/console for session. Normalizes D3D10 quality ids to D3D9.
- **FarCry2SettingsStore.swift** (105 lines): Loads/applies settings under session lock. Reads profile, renderer, registry, launcher options. Writes changes atomically via FileTransaction. Keeps original profile once before first edit.
- **FarCry2Setting.swift** (118 lines): One option definition; Storage enum (profile/renderer/registry/launcher); Launch enum (none/environment/argument/console); Kind enum (choices/resolution/integer/decimal). accepts() validates value format and range. canonical() formats doubles without trailing zeros.
- **FarCry2UserData.swift** (165 lines): Manages symlinks for player data outside prefix. documents = Data/Saves/FarCry2/Documents, localData = Data/Saves/FarCry2/LocalAppData. install() idempotently links both into Wine profile; migrates existing folders or keeps conflicted ones in Conflicts/. FarCry2Console enum: startupSwitch = "-cmdfile", scriptName = "starter-console.txt", script() joins console lines with newlines, windowsPath() computes C:\users\{profile}\Documents\My Games\Far Cry 2\starter-console.txt.
- **FarCry2Backup.swift** (194 lines): FarCry2Backup struct (id, created, label, files, bytes). FarCry2BackupRequest (action: create/restore/remove, id). FarCry2Backups manager: root = Data/Backups/FarCry2, limit = 20 max, originalProfile stored once. list() returns newest-first. recover() finishes interrupted restores. perform() creates/restores/removes backups with staging folders and transaction semantics.
- **FarCry2ShaderCache.swift** (231 lines): Keeps shader cache outside game folder, keyed by renderer build. root = ShaderCache/, cacheFile() = mtld3d_shaders.bin, infoFile() = info.json. status() returns ShaderCacheStatus (state: unavailable/empty/warm, bytes, saved date, origin, otherBuilds count). savedCache() validates file type and format. fileType() / fileSize() / readFile() / remove() / ensureDirectory() provide safe file ops. Prunes old builds, keeping keptOtherBuilds=2.
- **FarCry2ShaderCache+Exchange.swift** (97 lines): harvest() moves cache from game folder back to saved location; prepare() installs saved cache into game folder. export() packages cache into ShaderCacheExport file. importCache() merges or installs imported cache, tracking imported file SHA-256 to prevent duplicates.
- **FarCry2ShaderCache+Session.swift** (146 lines): Session-time helpers; shaderCache() factory creates instance with key and origin (GPU, OS version). report(launch:) logs cache readiness. attempt() wraps failures. perform() dispatcher for reset/export/import requests with user feedback.
- **FarCry2ShaderCacheRequest.swift** (36 lines): Codable action (reset/export/import) + optional path. file() validates path is absolute, < 4096 chars, ends with .btex.
- **FarCry2Snapshot.swift** (41 lines): FarCry2Snapshot struct (settings, profile state, installation metadata, backups list, keptAside count, shaderCache status). Published after preparation or play completion.
- **GamerProfileDocument.swift** (223 lines): Lossless XML editor for GamerProfile.xml. Parses element paths and attributes without re-serializing; preserves encoding, comments, whitespace. Rejects DOCTYPE. Size limit 1 MiB. set() replaces attribute values; values() extracts them. Encoding: UTF-8 (with/without BOM) or UTF-16 (LE/BE).
- **FarCry2Snapshot.swift** (41 lines): Already documented above.
- **ShaderCacheExport.swift** (122 lines): Package format for export/import; wraps payload (binary cache) with manifest (renderer key hash, payload size, checksum); fileExtension = "btex".
- **ShaderCacheFormat.swift** (138 lines): Binary format parser for mtld3d_shaders.bin. Scans header, records, validity. Validates against renderer key header. trimmed() strips trailing garbage.
- **ShaderCacheKey.swift** (91 lines): Identifies renderer build uniquely; read from resources/shader-cache-key.txt. identifier = 16-char hex. header = 4-byte magic. summary = human-readable version string.
- **XXH3.swift** (193 lines): XXH3 hash implementation; used for cache file deduplication.

## 2. UI

### Window and Scene Setup
- **FarCry2App.swift** line 7: `Window("Far Cry 2", id: "launcher") { FarCry2View(model: model) }`
- Default size 940×760 (line 12: `.defaultSize(width: 940, height: 760)`)
- Two-pane NavigationSplitView: sidebar with tabs, detail area with form/scroll view

### Tabs and Sections
**Sidebar (FarCry2View.swift lines 8–21)**:
- "Play" (default)
- **Your experience**: Graphics, Shader cache, Game view, Mac & MetalFX, Game & controls, Cheats
- **Your progress**: Saves & backups, Setup

### Detail Panes (Switched on model.tab)
- **Play**: FarCry2PlayView — title, welcome text, Rosetta prompt, game import, resolution/renderer summary, installation recognition, shader cache notice
- **Graphics**: FarCry2GraphicsView — aspect ratio and resolution pickers, graphics setting rows (Color, Image quality, Detail levels, Display options)
- **Shader cache**: FarCry2ShaderCacheView — saved summary, origin metadata, first-launch notice, export/import buttons, reset button
- **Game view**: FarCry2GameView — toggle for game embedding, accessibility permission request, game resolution display, DockAnchor area
- **Mac & MetalFX**: FarCry2PanelView with FarCry2Catalog.macGroups (Display & MetalFX, Keyboard, Renderer)
- **Game & controls**: FarCry2PanelView with FarCry2Catalog.gameGroups (Gameplay, Mouse, Audio, Launch options)
- **Cheats**: FarCry2PanelView with FarCry2Catalog.cheatGroups (Player, Weapons, World)
- **Saves & backups**: FarCry2SavesView — backup list, restore/remove, conflicted folders notice
- **Setup**: FarCry2SetupView — import/export setup, import game folder, Rosetta section

### Buttons and Actions
**Bottom bar** (FarCry2View.swift lines 57–73):
- Progress spinner if isBusy
- Phase message (with red styling if error)
- "Unsaved changes" label
- "Return to Game" button (shown when phase == .playing)
- "Save Settings" button (runs apply(), disabled if not hasPendingChanges)
- "Play" button (runs play(), disabled if not canPlay)

**Toolbar** (lines 77–81):
- "Reload" button (runs reload(), disabled if isBusy)
- "Open Log" button (runs showLog(), disabled if isBusy)

**Confirmation dialogs**:
- Discard unsaved settings
- Restore backup confirmation
- Reset shader cache confirmation
- Remove backup confirmation

### SharedLauncher Types Used
- **RosettaSetup**: Checks Rosetta availability; install() / refresh() methods; isAvailable, issue properties
- **GameDock**: requestTrust(), isTrusted check, viewSize(), place(), position(), accessibilityOrigin() for window positioning
- **GameWindow**: bringToFront(), leaseURL()
- **GameLease**: activeProcess(), record() on game start, clear() on game end
- **DisplayQuality**: maximumPreset() for display auto-detection
- **ResolutionPreset**, **AspectRatio**: Used in resolution picker

## 3. Model / State

### Model Type
- **FarCry2Model** (@Observable final class in FarCry2Model.swift)
- Observation-driven: changes publish automatically via @Observable

### Phase Enum (FarCry2Phase.swift)
```swift
enum FarCry2Phase: Equatable {
  case preparing, ready, playing, needsRosetta, needsGameData
  case failed(String)
  var isBusy: Bool { self == .preparing || self == .playing }
  var message: String { ... }
}
```
Status cases:
- **preparing**: Operation in progress
- **ready**: Game data present, ready to play
- **playing**: Game is running (phase set when play action enqueued; reverted when game exits)
- **needsRosetta**: Rosetta not installed; show install prompt
- **needsGameData**: No game folder imported; show import prompt
- **failed(String)**: Error occurred; show message

### Published Properties (FarCry2Model.swift lines 17–31)
- `@ObservationIgnored var dockFrame: CGRect?` — Game view on-screen position
- `@ObservationIgnored var requestAccessibility: @MainActor () -> Void` — Accessibility dialog hook (testable)
- `phase` — Current FarCry2Phase
- `request` — Increment-on-action trigger for task(id:) in FarCry2App
- `hasGameData` — Loaded from snapshot
- `profileState` — FarCry2ProfileState (missing/ready/unrecognized)
- `installation` — InstalledGame? (recognized game metadata)
- `backups` — [FarCry2Backup] (newest-first list)
- `keptAside` — Count of conflicted folders in Saves/FarCry2/Conflicts
- `shaderCache` — ShaderCacheStatus
- `settings` — FarCry2Settings (user edits)
- `tab` — Selected sidebar tab
- `backupSelection` — Current backup ID

### Status Refresh
**No polling**. Event-driven via:
1. **watchActivation()** (FarCry2Model.swift line 225): Listens to NSApplication.didBecomeActiveNotification; refreshes Rosetta on app activation if needsRosetta and not busy.
2. **task(id: model.request)** (FarCry2App.swift line 9): Triggers run() whenever request increments (enqueued by user actions).
3. **Snapshot reload**: After each session completes, FarCry2SessionClient decodes launcher-state.json and calls model.load().

## 4. Launcher ↔ Session Protocol

### Executable Lookup
- FarCry2SessionClient.defaultSupport: `~/Library/Application Support/FarCry2Mac` (FarCry2SessionClient.swift line 11–14)
- Session helper: FarCry2Session (linked into app bundle)
- Launched via `Process` (FarCry2SessionClient.swift line 70–86)

### Process Arguments
**Format** (SessionOptions.swift lines 20–60):
```
<app.bundle> --support <folder> <action> [--request <path>]
```

### CLI Verbs and Flags (SessionOptions.swift lines 6–13)
- `--prepare` — Prepares game without playing; checks Rosetta, recovers from crashes, reads settings
- `--play` — Prepares, applies settings, runs game, harvests cache
- `--configure` — Applies settings without running game
- `--import-game` — Copies user's game folder into private prefix; validates executable and required folders
- `--backups` — Create/restore/remove backup
- `--shader-cache` — Reset/export/import shader cache

### JSON Request Files
- Written by launcher to `<support>/request-<uuid>.json` (FarCry2SessionClient.swift line 65)
- Passed via `--request <path>` argument (line 68)
- Types: FarCry2LaunchRequest, FarCry2BackupRequest, FarCry2ShaderCacheRequest (all Codable)
- Session parses and validates (FarCry2Session.swift lines 58–69)

### Exit Codes (SessionMain.swift lines 12–19)
- **0**: Success
- **1**: General error (LauncherError.operation or other exception)
- **73**: Already running (LauncherError.alreadyRunning); caught by FarCry2SessionClient.swift line 91

### Status/JSON Output Schema
**launcher-state.json** (FarCry2Snapshot, written by FarCry2Session.snapshot() line 153)
```json
{
  "settings": { "resolution": "...", ... },
  "profile": "ready" | "missing" | "unrecognized",
  "installation": {
    "fileVersion": "...",
    "build": "...",
    "markers": ["gog" | "steam" | "uplay"],
    "versionStrings": { ... }
  } or null,
  "backups": [
    { "id": "...", "created": "ISO8601", "label": "...", "files": N, "bytes": N }
  ],
  "keptAside": 0,
  "shaderCache": {
    "state": "unavailable" | "empty" | "warm",
    "bytes": N,
    "saved": "ISO8601" | null,
    "origin": { "gpu": "...", "system": "..." } | null,
    "otherBuilds": N,
    "renderer": "..." | null
  } or null
}
```

### Session Lock and PID File
- **session.lock** (SessionLock from LauncherCore): Exclusive lock at `<support>/session.lock` (FarCry2Session.swift line 13); enforces one session at a time
- **game-session.json** (GameLease): At `<support>/game-session.json` (line 14); records running game PID; activeProcess() retrieves it; record() on game start, clear() on exit

## 5. Settings

### Settings Catalog
**FarCry2Catalog.swift** (lines 11–14):
```swift
static let graphicsGroups = ["Display", "Color", "Image quality", "Detail levels"]
static let macGroups = ["Display & MetalFX", "Keyboard", "Renderer"]
static let gameGroups = ["Gameplay", "Mouse", "Audio", "Launch options"]
static let cheatGroups = ["Player", "Weapons", "World"]
```

Each group contains multiple FarCry2Setting objects with:
- **id**: Unique identifier (e.g., "resolution", "brightness", "dock")
- **title**: User-facing label
- **group**: Belongs to one of the above
- **defaultValue**: Default if not saved
- **kind**: Enum (choices/resolution/integer/decimal)
- **storage**: Where it lives (profile/renderer/registry/launcher)
- **launch**: How it reaches the game (none/environment/argument/console)
- **help**: Tooltip text

Example settings:
- **Display**: resolution (WIDTHxHEIGHT), fullscreen (0/1), vsync (0/1), refreshRate (0, 30, 50, ..., 240), showFPS, forceWidescreen, driverBuffer
- **Color**: brightness (0.5–1.5), contrast (0.5–1.5), gamma (0.5–1.5)
- **Image quality**: textureQuality, shadowQuality, waterQuality, smokeQuality, explosionQuality, fireQuality, vegetation, physics
- **Detail levels**: terrainQuality, objectQuality, characterQuality, particleQuality, realTreeQuality
- **Display & MetalFX**: hud (MTL_HUD_ENABLED env), color.space (passthrough/accurate), cursor.scale (auto/1x/2x/3x), cursor.software (auto/true/false), render.scale (1.0 or lower for reduced resolution)
- **Keyboard**: leftCommandCtrl, rightCommandCtrl, leftOptionAlt, rightOptionAlt (all Wine registry)
- **Renderer**: shader.asyncCompile, shaderCache.enable, memory settings (vramBudgetMB, vbibRetentionCapMB, pageboxPoolCapMB), adapter.spoof (nvidia/amd/none), caps, render.preserveDiscardBackbuffer, display.legacy4By3
- **Gameplay**: difficulty (0–3), autosave (0/1), subtitles, compass, roadSigns, crosshair, ambx, machete
- **Mouse**: sensitivity (0.1–5), invertY, mouseSmooth, smoothness, smoothnessIronsight
- **Audio**: music (0/1), volume (0–100)
- **Launch options**: borderless, dock, noSound (-nosound), noPad (-nopad), noExMouse (-noexmouse)
- **Cheats** (Player/Weapons/World): god mode, health, no weapon mode, diamonds, unlimited ammo, unlimited reliability, all weapons unlock, time of day, time scale, wind force, wind direction

### Storage File and Format
**FarCry2SettingsStore.swift** (line 20):
- **optionsFile**: `<support>/farcry2-options.json`
- Launcher-owned options (borderless, dock, noSound, noPad, noExMouse, cheats) stored here outside prefix
- JSON format: `{ "id": "value", ... }`
- Survives prefix rebuild

**GamerProfileDocument**:
- Game's own XML: `<wine-prefix>/drive_c/users/<profile>/Documents/My Games/Far Cry 2/GamerProfile.xml`
- Profile attributes in nested elements (RenderProfile, CustomQuality, GameProfile, SoundProfile)
- Lossless in-place editor: only attribute values changed

**mtld3d.conf**:
- Renderer config at `<game>/bin/mtld3d.conf` (copied from defaults on import)
- Key-value INI format; written by FarCry2SettingsStore.rendererConfig() (FarCry2Settings.swift)

**user.reg** (Wine registry):
- At `<prefix>/user.reg`
- Mac Driver section: `Software\\Wine\\Mac Driver`
- Keyboard mapping options as REG_SZ values

### Settings UI
**FarCry2SettingRow.swift**: Renders one setting based on kind:
- **choices**: Picker with labeled options
- **resolution**: TextField (WIDTHxHEIGHT)
- **integer**: Stepper with range
- **decimal**: Slider with step 0.05

**FarCry2GraphicsView.swift**: Aspect ratio picker, resolution picker, graphics setting rows.

**FarCry2PanelView.swift**: Reusable panel for any catalog group.

## 6. Profiles / Saves / Backups Features

### Player Data Organization
**FarCry2UserData** (FarCry2UserData.swift):
- `documents = <support>/Data/Saves/FarCry2/Documents` → symlinked to `<wine-prefix>/drive_c/users/<profile>/Documents/My Games/Far Cry 2`
- `localData = <support>/Data/Saves/FarCry2/LocalAppData` → symlinked to `<wine-prefix>/drive_c/users/<profile>/AppData/Local/My Games/Far Cry 2`
- `profileFile = documents/GamerProfile.xml` (game's settings file)
- `conflicts = <support>/Data/Saves/FarCry2/Conflicts` (kept-aside folders if conflicts during link)

**install()** (line 61): Idempotent symlink installation:
1. Creates documents and localData folders
2. Finds Wine's user profile folder (not Public, unique, real directory)
3. For each link (Documents/My Games/Far Cry 2, AppData/Local/My Games/Far Cry 2):
   - If absent: create symlink
   - If already symlink to correct target: skip
   - If directory with existing files: move to persistent, create symlink
   - If directory empty: remove, create symlink
   - If conflict: move to Conflicts/<uuid>, create symlink
4. Returns Outcome (migrated list, conflicts list)

**keptAside()** (line 28): Returns count of folders in conflicts/ directory.

### Backups
**FarCry2Backups** (FarCry2Backup.swift):
- root = `<support>/Data/Backups/FarCry2`
- limit = 20 max concurrent backups
- parts: [(name, live)] = [("Documents", documents), ("LocalAppData", localData)]
- originalProfile = `<root>/GamerProfile.original.xml` (kept once before first edit)

**list()** (line 51): Newest-first; skips unreadable metadata.

**recover()** (line 75): Idempotent recovery after interrupted restore; rolls back staging folders.

**perform()** (FarCry2Backup.swift lines 101+): 
- **create**: Snapshot documents and localData into `<root>/<uuid>/backup.json` + tree tar
- **restore**: Back up current, stage from backup, commit atomically
- **remove**: Delete backup folder

Each backup stores:
- `backup.json`: FarCry2Backup metadata (id, created date, label, file count, byte size)
- Compressed copies of documents and localData trees

## 7. Store Client / Steam / Ubisoft Flow

**Not implemented for Far Cry 2.** 
- Requires user import of retail game folder (farcry2.json "import" edition)
- Bundled edition (farcry2-bundled.json) carries pre-installed game data
- No store client activation or update hooks
- Detection: FarCry2Catalog markers (gog, steam, uplay) are informational only, reported in installation metadata

## 8. Error Handling

### Error Types
**LauncherError** from LauncherCore (used throughout):
- `.alreadyRunning` — Exit code 73
- `.operation(String)` — User message on exit code 1

### User-Facing Error/Status Strings

**FarCry2Phase messages** (FarCry2Phase.swift lines 5–14):
- "Preparing Far Cry 2…" (.preparing)
- "Ready to play" (.ready)
- "Far Cry 2 is running. Close the game to return here." (.playing)
- "Rosetta is required to run this Intel game." (.needsRosetta)
- "Import your installed Far Cry 2 folder to begin." (.needsGameData)
- Custom error message from `.failed(String)`

**Model properties** (FarCry2Model.swift):
- line 60–62: `errorMessage` — Extracted from phase if `.failed`
- line 75–82: `profileNotice` — Explains game's profile status (ready/missing/unrecognized)

**Confirmation dialogs**:
- "Discard unsaved settings? The game's saved settings will be loaded again."
- "Restore this backup? Your current settings and saves are backed up first, then replaced."
- "Reset the shader cache? The saved shaders are deleted. The next launch compiles them again and may pause."
- "Remove this backup? Only this backup is deleted. Your current saves are not changed."

**Export/import panels**:
- "Export the setup outside the game's player data folder." (FarCry2SessionClient.swift line 114)
- "Choose a .\(ShaderCacheExport.fileExtension) file." (FarCry2ShaderCacheRequest.swift line 31)
- Shader cache errors wrapped via attempt() with context like "Shader cache: could not take back the previous cache: ..."

**Session errors** (SessionMain.swift lines 13–18):
- "Install Rosetta from the starter before preparing this game." (FarCry2Session.swift line 40)
- "The imported game has no bin/FarCry2.exe. Import it again." (line 74)
- LauncherError.operation() messages from deeper layers

## 9. Application Support Layout

### Base Path
`~/Library/Application Support/FarCry2Mac` (FarCry2SessionClient.defaultSupport)

### Directory Structure
```
FarCry2Mac/
├── session.lock                     (SessionLock; exclusive)
├── game-session.json                (GameLease; PID of running game)
├── launcher-state.json              (FarCry2Snapshot; loaded after each operation)
├── farcry2-options.json             (Launcher-owned settings; survives prefix rebuild)
├── Logs/
│   └── session-<uuid>.log           (Stdout/stderr of FarCry2Session subprocess)
├── RuntimeHome/
│   └── Player/                      (Wine user profile placeholder; created if missing)
├── Temporary/                       (Temp files during operations)
├── ShaderCache/
│   ├── <key-hash>/                  (One dir per renderer build; <key-hash> = 16-char hex)
│   │   ├── mtld3d_shaders.bin       (Saved shader cache; binary format)
│   │   └── info.json                (Metadata: saved date, origin GPU/system, imported hashes)
│   └── <old-key>/                   (Kept caches from prior renderer versions; max 2 older kept)
├── Data/
│   ├── Backups/FarCry2/
│   │   ├── <uuid>/                  (One backup per create)
│   │   │   ├── backup.json          (FarCry2Backup metadata)
│   │   │   └── <tree.tar.bz2>       (Compressed Documents and LocalAppData)
│   │   ├── GamerProfile.original.xml (Game's untouched profile; kept once before first edit)
│   │   └── <staging-uuid>/          (Temp folders during restore; cleaned on recovery)
│   └── Saves/FarCry2/
│       ├── Documents/               (Symlink to Wine profile's My Games\Far Cry 2)
│       │   ├── GamerProfile.xml     (Game's own settings file)
│       │   └── Saved Games/         (Game's savegames)
│       ├── LocalAppData/            (Symlink to Wine profile's AppData\Local\My Games\Far Cry 2)
│       │   └── input.xml            (Game's input map)
│       └── Conflicts/               (Set-aside folders if symlink conflicts during install)
│           └── <uuid>/              (Each conflict: old Documents or LocalAppData)
└── <game-version>/                  (Prepared game copy; managed by GameInstaller in LauncherCore)
    ├── bin/
    │   ├── FarCry2.exe              (Main executable)
    │   ├── Dunia.dll                (Engine DLL)
    │   ├── mtld3d.conf              (Renderer config; written by FarCry2SettingsStore)
    │   └── mtld3d-logs/             (Renderer debug logs, if enabled)
    └── Data_Win32/                  (Game data; .fat/.dat paired archives on FAT32-sized media)
```

### State Files
- **launcher-state.json** (FarCry2Snapshot): Updated after prepare/play; read by UI to reload model
- **farcry2-options.json** (FarCry2Settings.launcherData()): Launcher-owned options (dock, cheats, etc.)
- **session.lock** (SessionLock): Ensures exclusive session
- **game-session.json** (GameLease): PID of running game for GameDock window management
- **Logs/session-<uuid>.log**: Subprocess output; log location URL provided to user

### Bundle Flavor Distinction
**Two editions share same launcher code; distinguished via BundleManifest:**

1. **farcry2.json ("import" edition)**:
   - editions: ["import"]
   - shaderCache: true (optional; depends on renderer key presence)
   - No "game" input in recipe
   - User imports their own game folder via UI
   - On import: GameInstaller.prepare() copies game to `<support>/<version>/`
   
2. **farcry2-bundled.json ("bundled" edition)**:
   - editions: ["bundled"]
   - "game" input: `{games}/FarCry2` (pre-built game copy in build environment)
   - originalFiles: ["bin/Dunia.dll", "bin/farcry2.exe", ...] (verified hashes)
   - originalDirectories: {game data patterns}
   - on first launch: BundleManifest guides GameInstaller to seed game into support folder

**Code does not explicitly check edition**; instead, AppPaths and GameInstaller automatically discover whether game exists and is prepared. Both editions converge on same support folder layout and launcher-state.json output.

## 10. Logs

### Location
Logs written to `<support>/Logs/` directory.

### File Names
- **session-<uuid>.log**: Named with UUID; stdout + stderr of FarCry2Session subprocess redirected here (FarCry2SessionClient.swift line 30)
- Rotation: No explicit rotation; files accumulate
- Access: logURL stored in FarCry2SessionClient; logLocation() async getter; UI "Open Log" button invokes NSWorkspace.open(url)

### Log Content
- Session startup/shutdown messages
- Shader cache status (unavailable/cold/warm, bytes saved, import results)
- Settings applied (profile state changes)
- Installation recognition (file version, build, markers, version strings)
- Backup operations (migrated/conflicted folders)
- Rosetta checks and failures
- Game launch arguments and console script
- Cache harvest results
- Any LauncherError or exception messages

## 11. First Run / Seed / Prefix Preparation

### First Launch Sequence
1. **FarCry2App** loads FarCry2Model; creates task(id: model.request) to run() on any request increment
2. **Model.run()** with action `.helper(.prepare)`:
   - Checks rosetta.isAvailable; if not, phase = .needsRosetta
   - Checks hasGameData; if not, phase = .needsGameData
   - Otherwise: calls service.perform(.prepare)
3. **FarCry2SessionClient.perform(.prepare)** launches session with `--prepare` flag
4. **FarCry2Session.run()**:
   - SessionLock.withLock() acquires exclusive lock
   - GameLease.check() ensures no game already running
   - FileTransaction.recover() and GuestIsolation.recover() clean up crashes
   - FarCry2Backups.recover() finishes interrupted backups
   - Creates RuntimeHome/Player and Temporary folders
   - ShaderCache.harvest() moves cache from old game folder (if present)
   - ProcessCommand(arch -x86_64 /usr/bin/true) verifies Rosetta
   - BundleManifest.read() loads recipe
   - GameInstaller.prepare() with optional import URL:
     - If import: copies user's game folder into `<support>/<version>/`; validates bin/FarCry2.exe, Data_Win32, required files
     - If bundled: discovers pre-seeded game
     - Returns InstalledGame metadata (file version, build, markers)
   - runtime.initialize() (if first time): Creates Wine prefix with Windows environment
   - GameDrive setup (symbolic links and mounts)
   - GuestIsolation.restrict() locks prefix permissions
   - FarCry2UserData.install() links player folders; migrates/conflicts any old data
   - FarCry2SettingsStore.load() reads current game profile, renderer, registry, launcher options
   - Snapshot written to launcher-state.json
5. **UI updates**: Model.load(snapshot); phase = .ready if hasGameData, else .needsGameData

### Prefix Initialization
- **Wine runtime**: Extracted from bundle's Resources/runtime or specified in recipe
- **First install**: runtime.initialize() runs wineboot, creates `drive_c/users/<profile>/` folder
- **Subsequent launches**: Wine prefix reused; GuestIsolation.restrict() ensures permissions
- **Versioning**: Each game update gets a new prefix version; old prefix archived/deleted per GameInstaller policy

### Game Import (First-Run for Import Edition)
- User selects folder via NSOpenPanel
- FarCry2Model.importGameFolder() calls service.perform(.importGame(url))
- Session validates: bin/FarCry2.exe exists, >= 1 MiB; Dunia.dll exists, >= 1 MiB; Data_Win32 >= 1 GiB
- Copies game tree into support folder
- On success: finishGameImport(snapshot); hasGameData = true; phase = .ready

## 12. Update / Verification of Bundle or Game Files

### Game Verification
**On import** (GameInstaller.prepare() in LauncherCore):
- Scans executable for: fileVersion, internalVersion, productVersion (PE header VERSIONINFO)
- Matches against FarCry2 known builds (none configured in farcry2.json; could be added)
- Detects markers: GOG (goggame-*.info), Steam (steam_api.dll), Ubisoft (uplay*.dll, upc.exe)
- Validates required files: bin/FarCry2.exe, Dunia.dll, Data_Win32
- Reports installation metadata in InstalledGame struct

**No online verification**; detection is local file scanning only.

### Bundled Edition Verification
**farcry2-bundled.json** (Packaging/Recipes/farcry2-bundled.json lines 62–65):
- Executable hashes for verification:
  - `"bin/farcry2.exe"`: SHA-256 = 2f93751b...
  - `"bin/Dunia.dll"`: SHA-256 = 7b82f200...
- Verified during packaging; not checked at runtime (LauncherCore verifies at install time)

### Game Data Integrity
- No checksum checking on per-file basis
- Size and structure validated on import (Data_Win32 >= 1 GB)
- Paired-file detection (FAT32 era: .fat and .dat companions matched)

### Shader Cache Validation
**ShaderCacheFormat.scan()** (ShaderCacheFormat.swift):
- Validates binary format: magic header, record layout, checksums
- Rejects mismatched renderer key headers
- Trims corrupted trailing data

## 13. Renderer / Sidecar / Experiment Switches

### DXVK
Not explicitly configured; D3DMetal used instead (mtld3d renderer).

### D3DMetal (mtld3d)
**Renderer configuration** (FarCry2Catalog.swift lines 237–273, FarCry2Settings.rendererConfig()):
- Written to `<game>/bin/mtld3d.conf` (INI format)
- Owned by FarCry2 via FarCry2Settings (always owned renderer keys):
  - render.scale: Full resolution (1.0) or reduced (< 1.0)
  - shader.asyncCompile: Async compilation (true/false)
  - present.maxFps: FPS cap (0 = unlimited)
  - adapter.spoof: GPU vendor (nvidia/amd/none) for vendor database queries
- Other mtld3d options exposed as settings:
  - memory.vramBudgetMB, memory.vbibRetentionCapMB, memory.pageboxPoolCapMB
  - caps.dfFormats, render.preserveDiscardBackbuffer, display.legacy4By3

### MetalFX
- **Display & MetalFX group**: Settings expose renderer and Mac driver options
  - render.scale: Integrated rendering scale toggle (1.0 = full, < 1.0 = reduced)
  - color.space: passthrough vs. sRGB accurate
  - cursor.scale, cursor.software: UI scaling

### Rosetta (x86-64 Translation)
- Check: ProcessCommand(arch -x86_64 /usr/bin/true) during prepare (FarCry2Session.swift line 33)
- Install: RosettaSetup.install() opens Apple's installer (FarCry2RosettaView button)
- Refresh: RosettaSetup.refresh() rechecks availability on app activation

### Wine Flags
**Environment variables** (FarCry2Settings.LaunchPlan.environment; set in FarCry2Session.swift line 78):
- Keyboard mapping options trigger Wine registry edits (not env vars directly, but set via SettingsStore)
- MTL_HUD_ENABLED: Metal performance overlay toggle
- No explicit Wine debug flags or WINE_CPU_TOPOLOGY; defaults from bundled runtime

### Shader Cache
**Enabled by default** (FarCry2Catalog.swift line 244):
- `shaderCache.enable = "true"` (renderer option)
- Compile mode: async by default (shader.asyncCompile = "false" = waits per pipeline)
- First launch compiles; saved cache reused per renderer key
- Reset button clears saved cache; next launch recompiles

## 14. Game Data: Copied or Run In Place

**Copied** (not run in place).

- **GameKind.farcry2.copiesGameData = true** (LauncherCore/GameKind.swift line 61)
- **FarCry2 is prepared to a versioned folder** within support directory
- **GameInstaller.prepare()** (LauncherCore):
  1. If import edition: Copies user's game folder into `<support>/<version-hash>/`
  2. If bundled edition: Seeds from pre-packaged game in recipe
  3. Validates and extracts to FarCry2-friendly structure
- **Why copied**: Shader cache moves in/out of game folder; prefix must remain clean and isolated; data must survive app updates

### Data Preparation Functions
- **GameInstaller.prepare()**: Main entry point; handles both import and bundled editions
- **GameDrive.install()** (LauncherCore): Sets up symlink mounts if needed
- **FarCry2UserData.install()**: Links player data folders (Documents, LocalAppData) into prefix

## 15. Symlink / Unplugged-Volume Handling

### Symlink Detection and Handling
**FarCry2UserData.install()** (FarCry2UserData.swift lines 102–146):
- state() checks resourceValues for .isSymbolicLinkKey and .isDirectoryKey
- Refuses to follow links: "A Far Cry 2 player folder link points somewhere unexpected; leaving it untouched."
- Validation: destinationOfSymbolicLink(atPath:) decodes current link; compares to expected relativePath()
- On conflict: keeps existing link or moves conflict to Conflicts/

**Path resolution** (FarCry2UserData.swift line 140–141):
- relativePath(from:to:) uses resolvingSymlinksInPath() and standardizedFileURL to compute safe relative paths
- symlinks resolved to identify true directory structure

### ShaderCache Symlink Checks
**FarCry2ShaderCache.otherBuilds()** (FarCry2ShaderCache.swift lines 165–175):
- Filters out any entries that resourceValues[.isSymbolicLinkKey] == true
- Prevents following stale or malicious links in cache directory

### ExportURI Validation
**FarCry2ShaderCache+Exchange.swift** (lines 81–83):
```swift
let target = destination.standardizedFileURL
let support = paths.support.standardizedFileURL.resolvingSymlinksInPath().path
let parent = target.deletingLastPathComponent().resolvingSymlinksInPath()
```
- Exports resolved to detect if destination is inside support folder (refuses in-place overwrites)

### Unplugged Volume Handling
**No explicit checks for missing volumes.** 
- **Assumption**: Application Support folder is on the main macOS volume and always mounted
- If external drive containing Saves or ShaderCache becomes unplugged:
  - Session operations will fail with FileManager exceptions (caught and reported as LauncherError.operation)
  - UI shows error message; phase = .failed(...)
  - On reactivation, fresh prepare() attempt (no retry loop)

### State on Missing Volume
- **If support folder unmounts**: Session fails immediately when creating directories or reading launcher-state.json
- **If game folder unmounts** (during play): ProcessCommand.run() fails (game exits); lease.clear() fails; error logged
- **Recovery**: Remount volume, tap "Reload" button or reactivate app to trigger watchActivation()

## 16. Code Duplication / Reuse from Other Wrappers

### Shared Patterns from LauncherCore
- **AppPaths** (GameKind.farcry2): Centralizes support/data/prefix paths
- **GameKind enum**: Defines executable, folder, helper, title, rendererConfiguration, copiesGameData, etc. for all games
- **GameInstaller**, **GameDrive**, **GuestIsolation**: Reused for game preparation and prefix isolation
- **SessionLock**, **GameLease**, **FileTransaction**: Serialization and recovery
- **BoundedFile**, **BoundedTree**: Safe file reading with limits

### Shared Patterns from SharedLauncher
- **RosettaSetup**, **RosettaState**: Rosetta availability and installation
- **GameDock**, **GameWindow**, **GameLease**: Window management and PID tracking
- **DisplayQuality**, **ResolutionPreset**: Resolution detection and picker

### Game-Specific vs. Shared Code
**FarCry2-specific in FarCry2Core**:
- **FarCry2Settings**, **FarCry2Catalog**: Far Cry 2's 50+ managed options (profile/renderer/registry/launcher)
- **GamerProfileDocument**: XML editor for GamerProfile.xml (game's own format)
- **FarCry2UserData**, **FarCry2Backups**: Player data symlink and backup logic specific to Far Cry 2's folder structure
- **FarCry2ShaderCache**, **FarCry2ShaderCacheRequest**: Shader cache management with renderer build keying
- **FarCry2Console**: Console script generation for cheats and world options

**Counterpart in other wrappers**:
- NFS2015Model, CoD4Model: Similar @Observable + @State pattern
- NFS2015SessionClient, CoD4SessionClient: Same Process + JSON protocol
- NFS2015SettingsStore, CoD4SettingsStore: Settings file lifecycle
- BF3Launcher: Comparable architecture but with prepared prefix instead of dynamic import

## 17. Tests

**FarCry2CoreTests** (13 test files):
- **FarCry2SettingsTests.swift**: Validates FarCry2Settings parsing from profile/renderer/registry/launcher; range/value validation; applies-to-profile logic
- **FarCry2SettingsStoreTests.swift**: Load/apply round-trip; transaction atomicity; original profile backup
- **FarCry2UserDataTests.swift**: Symlink install; migration of existing folders; conflict handling; relative path computation
- **FarCry2BackupsTests.swift**: Create/restore/remove; staging and rollback on error; metadata persistence; limit enforcement
- **FarCry2ShaderCacheTests.swift**: Save/load; cache key identifier; other-build pruning; file validation
- **FarCry2ShaderCacheExchangeTests.swift**: Export/import; manifest verification; duplicate detection via SHA-256
- **FarCry2ShaderCacheRequestTests.swift**: Path validation (absolute, no null bytes, .btex extension)
- **FarCry2SnapshotTests.swift**: Codable round-trip; snapshot completeness
- **FarCry2RendererDefaultsTests.swift**: Defaults loaded from Packaging/FarCry2Defaults/
- **FarCry2OptionsTests.swift**: FarCry2Console console script generation
- **FarCry2Fixture.swift**: Test fixtures for paths, settings, profiles, backups
- Plus 2 additional fixture/integration files

**FarCry2UITests** (1 file):
- **FarCry2ModelTests.swift**: Model state transitions; action queuing; settings edits; shader cache status updates; backup selection; rosetta checks; display detection; ServiceStub mock

**FarCry2SessionTests** (1 file):
- **SessionOptionsTests.swift**: CLI argument parsing; validation of --support, --action, --request flags; error messages for bad input

**LauncherCoreTests** (1 file):
- **FarCry2GameKindTests.swift**: GameKind.farcry2 properties (executable, folder, helper, copiesGameData, rendererConfiguration)

---

## Summary for Key Sections

### Section 3: Model/State
FarCry2Model is @Observable with phase (enum: preparing/ready/playing/needsRosetta/needsGameData/failed). No polling; event-driven via NSApplication.didBecomeActiveNotification for Rosetta refresh and task(id: model.request) for operation triggers. Settings loaded from profile/renderer/registry/launcher.json after each snapshot.

### Section 4: Launcher<->Session Protocol
FarCry2SessionClient launches FarCry2Session subprocess with `<bundle> --support <folder> <action> [--request <file>]`. Actions: --prepare, --play, --configure, --import-game, --backups, --shader-cache. JSON request files (FarCry2LaunchRequest, etc.) written to support folder. Exit code 73 = alreadyRunning; 0 = success; 1 = error. launcher-state.json (FarCry2Snapshot) encodes settings, profile state, installation metadata, backups, keptAside count, shader cache status. SessionLock and GameLease enforce exclusivity.

### Section 8: Error Handling
LauncherError.alreadyRunning (exit 73) and LauncherError.operation(String) for user messages. Phase messages: "Preparing Far Cry 2…", "Ready to play", "Far Cry 2 is running…", "Rosetta is required…", "Import your installed Far Cry 2 folder…", custom on .failed(String). Errors from shader cache, symlink conflicts, missing files caught and reported in UI.

### Section 9: Application Support Layout
~/Library/Application Support/FarCry2Mac contains: launcher-state.json, farcry2-options.json, session.lock, game-session.json, Logs/, ShaderCache/, Data/Saves/FarCry2/{Documents,LocalAppData,Conflicts}, Data/Backups/FarCry2/, RuntimeHome/Player/, <game-version>/ (prepared game copy). Bundle flavors (import vs. bundled) distinguished via BundleManifest; code converges on same support layout.

### Section 14: Game Data
Copied (not in-place). GameInstaller.prepare() copies user's game folder (import) or seeds from recipe (bundled) into <support>/<version>. FarCry2 has copiesGameData=true. Shader cache moves in/out of game/bin/. Player data symlinked separately.

### Section 15: Symlink / Volume Handling
FarCry2UserData.install() refuses to follow symlinks; uses resolvingSymlinksInPath() + standardizedFileURL for path validation. Rejects links where directories should be ("player folder link points somewhere unexpected"). FarCry2ShaderCache filters out links in cache directory. FarCry2ShaderCache+Exchange validates export destination. No explicit unplugged-volume checks; session fails with FileManager error if volume missing; UI shows error message; user remounts and retries.

### Section 16: Code Duplication
FarCry2Model mirrors NFS2015Model pattern. FarCry2SessionClient follows same Process + JSON protocol as NFS2015SessionClient. GameKind enum (LauncherCore) centralizes game constants. Shared infrastructure: AppPaths, GameInstaller, GameDrive, GuestIsolation, SessionLock, GameLease, FileTransaction, RosettaSetup, GameDock, GameWindow, DisplayQuality. FarCry2-specific: FarCry2Settings/Catalog (50+ options), GamerProfileDocument (XML editor), FarCry2UserData/Backups (player data mgmt), FarCry2ShaderCache (keyed caching), FarCry2Console (cheat scripts).
