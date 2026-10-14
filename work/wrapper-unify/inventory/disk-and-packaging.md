# Disk Layout and Packaging Inventory

## Part 1: Application Support Layout

### Directory Structure and State Files

#### BF3Mac
- **Location**: `~/Library/Application Support/BF3Mac/`
- **State Files**:
  - `Logs/client-*.log` (multiple session logs)
  - `session.lock` (26 bytes)
  - `Data/seed.json` (71 bytes) - Contains game file inventory: `{"bytes":24732634397,"version":"8b0ac09677325dd433195848","files":7861}`
  - `Data/Prefix.internal-old-20261010/` (old prefix backup with system.reg, user.reg, userdef.reg)

#### CoD4Mac
- **Location**: `~/Library/Application Support/CoD4Mac/`
- **State Files**:
  - `Logs/session-*.log` (14+ UUIDs, session logs)
  - `session.lock`
  - `launcher-state.json` (1817 bytes) - Game settings and controls: selectedProfile, graphics settings (resolution 1920x1080, gamma 0.8, vsync on), audio (khz 44, volume 0.8), keybindings, campaign save flag
  - `Data/` (directory)

#### NFS2015Mac
- **Location**: `~/Library/Application Support/NFS2015Mac/`
- **State Files**:
  - `first-run-seed.json` (60 bytes) - `{"seededAt":"2026-10-08T01:32:56Z","resolution":"2560x1440"}`
  - `metalfx.json` (68 bytes) - MetalFX settings: `{"factor":"1.5","spatialUpscaling":true,"version":1}`
  - `game-session.json` (56 bytes) - Current session: `{"microseconds":147754,"seconds":1791584240,"pid":10953}`
  - `client-log.txt` (log file)
  - `MOVED-ASIDE.log` (migration log)
  - `Logs/session-*.log` (14+ UUIDs)
  - `Logs/crash-report-*.txt` (2 crash reports: 20261008T211346Z, 20261008T023002Z)

#### GameHub
- **Location**: `~/Library/Application Support/GameHub/`
- **State Files**:
  - `Instances/.lock` (session lock)
  - `Instances/.DS_Store`

---

## Part 2: Installed App Bundles

All 6 apps in `/Volumes/ExT2/Bundles/` are signed with **Developer ID Application: Guillaume Coquard (Team NP94WB3P75)**, v20500 Code Directory with runtime flag (0x10000).

### Bundle Specifications

| App Name | Bundle ID | Executable | Version | Entitlements |
|----------|-----------|-----------|---------|--------------|
| Battlefield 3 Bundled 20261009-5ee7913.app | local.bf3.mac | BF3Launcher | 1 | audio-input, bluetooth, camera |
| Call of Duty 4 Bundled 20261002-7d108a4.app | local.cod4.mac | CoD4Launcher | 1 | audio-input, bluetooth, camera |
| Far Cry 2 Bundled 20261002-845b6c9.app | local.farcry2.mac | FarCry2Launcher | 1 | (none declared) |
| Far Cry 2 Import 20261002-7d108a4.app | local.farcry2.mac | FarCry2Launcher | 1 | audio-input, bluetooth, camera |
| Most Wanted Bundled 20261002-7d108a4.app | local.nfsmw.mac | NFSMWLauncher | 6 | audio-input, bluetooth, camera |
| Need for Speed Bundled 20261008-13d1f4f-0010.app | local.nfs2015.mac | NFS2015Launcher | 1 | audio-input, bluetooth, camera |

---

## Part 3: Packaging and Build System

### Recipes (Packaging/Recipes/)

| Recipe File | Game | Bundle ID | Launcher | Session | Editions | Store Client |
|-------------|------|-----------|----------|---------|----------|--------------|
| bf3.json | Battlefield 3 | local.bf3.mac | BF3Launcher | BF3Session | bundled only | EA app (EA Desktop) |
| cod4.json | Call of Duty 4 | local.cod4.mac | CoD4Launcher | CoD4Session | bundled, import | None (standalone) |
| farcry2.json | Far Cry 2 | local.farcry2.mac | FarCry2Launcher | FarCry2Session | import only | None |
| farcry2-bundled.json | Far Cry 2 | local.farcry2.mac | FarCry2Launcher | FarCry2Session | bundled only | None |
| nfs2015.json | Need for Speed | local.nfs2015.mac | NFS2015Launcher | NFS2015Session | import, bundled | EA app (EA Desktop) |
| nfsmw.json | Most Wanted | local.nfsmw.mac | NFSMWLauncher | NFSMWSession | bundled, import | None |

### Assembly Pipeline

#### build.py
**Command**: `python3 Packaging/build.py --game <name> --game-data bundled|import --output <path> [--identity 'Developer ID Application: ...' | --identity '-' for ad-hoc]`

**Workflow** (sequential execution order):
1. `xcrun swift test` (run tests)
2. `xcrun swift build -c release -Xswiftc -warnings-as-errors` (compile release binary)
3. `xcrun swift-format lint --strict --recursive Sources Tests` (format check)
4. Run validation gates (see below)
5. `python3 Packaging/package.py --game <name> [--with-game-data|--without-game-data] --output <app.app>` (assemble)
6. `python3 Packaging/sign.py <app.app> --identity <identity>` (sign with identity; default '-' for ad-hoc)
7. `python3 Packaging/audit.py <app.app> --runtime <runtime-path>` (security audit)
8. `/usr/bin/ditto -c -k --sequesterRsrc --keepParent <app.app> <app.zip>` (archive with ditto)
9. SHA-256 checksum to `.zip.sha256`

**Output Location**: Defaults to `Build/<GameName> Bundled|Import.app`, but `--output <path>` allows any writable location outside `/Volumes/ExT2/Bundles`.

**Signing Modes**:
- Default: `-` (ad-hoc signature)
- Distribution: `'Developer ID Application: Guillaume Coquard (NP94WB3P75)'`
- `--no-archive` flag skips ZIP creation and returns bare app

#### assemble.py / package.py
**Script**: `Packaging/assemble.py` is a thin wrapper that calls `assemble()` from `assemble.py`.

**Inputs** (via `--input NAME=PATH`):
- `game`: Game installation or payload folder
- `runtime`: Wine runtime binary (swiftc-fetched from upstream)
- `runtimeSourceTree`: Git working tree for LGPL source archiving
- `thirdPartyLicenses`: External component license URLs
- `managedRuntime`: Wine Mono .NET installer (bundled edition only)
- `clientLayer`: Pre-installed EA Desktop client (bundled edition only, BF3/NFS2015)

**Assembly Steps**:
1. Verify inputs against recipe pins (hash/path validation)
2. Copy launcher and session executables from build output
3. Strip debug maps from binaries (`/usr/bin/strip -S`)
4. Write Rosetta compatibility metadata
5. Stage runtime (Wine+mtld3d DLLs into Contents/Resources/)
6. Stage game files (if bundled) into Resources/Game/, verify against inventory SHA256
7. Stage compatibility patches and defaults
8. Collect runtime source revisions for NOTICE.md
9. Archive LGPL source (if runtimeSource declared)
10. Stage third-party licenses
11. Stage managed runtime (Wine Mono) and client layer (if bundled)
12. Write game-manifest.json, bundle-recipe.json, runtime-provenance.json, Info.plist

**Output**: Produces `.app/` structure at `--output` path; required to be new (fails if app or .zip exists).

---

## Validation Gates (Check Scripts)

All gates run **before** assembly. Repo-only gates (require no built app):

| Gate | Runs | Input Required | Purpose |
|------|------|----------------|---------|
| check_recipes.py | `python3 Packaging/check_recipes.py` | Recipe files | Validate paths, prevent duplicates, check payload ambiguity |
| check_game_data.py | `python3 Packaging/check_game_data.py` | (none) | Verify runtime-only mode keeps inventory |
| check_cod4_data.py | `python3 Packaging/check_cod4_data.py` | (none) | CoD4 payload excludes player state |
| check_farcry2_recipe.py | `python3 Packaging/check_farcry2_recipe.py` | (none) | Far Cry 2 import-only validation |
| check_nfs2015_recipe.py | `python3 Packaging/check_nfs2015_recipe.py` | (none) | NFS2015 bundled/import pin validation |
| check_bf4_recipe_schema.py | `python3 Packaging/check_bf4_recipe_schema.py` | (none) | BF3/BF4 64-bit helper process rules |
| check_nfs2015_settings.py | `python3 Packaging/check_nfs2015_settings.py` | (none) | Settings UI cannot access binary options |
| check_nfs2015_metalfx.py | `python3 Packaging/check_nfs2015_metalfx.py` | (none) | MetalFX JSON emits DXMT-safe options only |
| check_runtime_inputs.py | `python3 Packaging/check_runtime_inputs.py` | (none) | Verify pins, record source revisions |
| check_bundle_hygiene.py | `python3 Packaging/check_bundle_hygiene.py` | (none) | Bundled edition: no account state, pinned bytes |
| check_authenticode.py | `python3 Packaging/check_authenticode.py` | (none) | EA installer signature verification |
| check_client_layer.py | `python3 Packaging/check_client_layer.py` | (none) | EA client classification, determinism, registry merge |
| check_app_archive.py | `python3 Packaging/check_app_archive.py` | (none) | ZIP64 retains bytes, modes, symlinks |
| check_shader_cache.py | `python3 Packaging/check_shader_cache.py` | (none) | mtld3d shader cache key tracking |
| check_notice_licences.py | `python3 Packaging/check_notice_licences.py` | (none) | NOTICE.md component coverage |
| check_privacy.py | `python3 Packaging/check_privacy.py` | (none) | Privacy entitlements match Wine capabilities |
| check_signing_policy.py | `python3 Packaging/check_signing_policy.py` | (none) | Developer ID scope, Wine memory exception |
| check_runtime_optimization.py | `python3 Packaging/check_runtime_optimization.py` | (none) | Strip preserves bytes/dirs/markers |
| check_assembly.py | `python3 Packaging/check_assembly.py` | (none) | Shared assembly retains compatibility, input immutability |
| check_prepared_prefix_recipe.py | `python3 Packaging/check_prepared_prefix_recipe.py` | (none) | BF3 prepared-prefix shape validation |
| check_widescreen_compat.py | `python3 Packaging/check_widescreen_compat.py` | (none) | Light streaks resolution hook regression |

---

## Build Output

### Runtime Artifacts
**Location**: `/Volumes/ExT2/GameHub/work/bundle-out/`
- `bundle-v0.12.0-52-g9818578/` - Wine bundle directory (8 entries)
- `mtld3d.tar.xz` (3.77 MB) - Direct3D 9/10/11 emulation library
- `mtld3d-debug.tar.xz` (7.87 MB) - Debug symbols and instrumented build

---

## Summary: BF3 Assembly Command and Key Differences

### BF3 Assembly (Bundled Edition)
```bash
python3 Packaging/build.py \
  --game bf3 \
  --game-data bundled \
  --output /custom/path/Battlefield3.app \
  --identity 'Developer ID Application: Guillaume Coquard (NP94WB3P75)'
```

**Output location**: Can be written to any path outside `/Volumes/ExT2/Bundles/` (build.py enforces this and fails if the output already exists).

### Key Recipe Differences

- **BF3**: bundled-only, requires EA app store client, prepared-prefix recipe (check_prepared_prefix_recipe.py)
- **NFS2015**: supports both bundled and import, requires EA app, managed runtime (Wine Mono)
- **CoD4 / NFSMW**: support both editions, no store client (standalone)
- **Far Cry 2**: two separate recipes (farcry2.json import-only, farcry2-bundled.json bundled-only)

All signed with Developer ID; audio/bluetooth/camera entitlements declare Wine device access (Far Cry 2 Bundled omits these).
