# Per-program fixes: inventory, move into the runtime, and a pre-launch detection layer

Status: proposal, 2026-10-24. Nothing below is built yet unless the row says "in runtime".
Builds on `docs/bundler-plan/BUNDLER-DESIGN.md` §5 (knowledge rules) and `OVERRIDES-MATRIX.md` (91 recorded overrides).

## 1. Inventory: where each per-program fix lives today

| Fix | Programs | Lives in | Target home |
|---|---|---|---|
| Backend per exe: `steamwebhelper.exe` dxgi=dxmt; `EACefSubProcess.exe`, `EAGEP.exe`, `EpicWebHelper.exe` dxgi=wined3d; AoA dxgi=dxmt/wined3d | Steam, EA, Epic, AoA | `launcher/hub` `compat_db()` (WINE_COMPATDB string) | runtime rules file |
| `dxgi/gptk -> dxmt` alias (compatdb built-in `steam-web-helper` rule asks for gptk) | steamwebhelper | runtime dir, created by `scripts/assemble_runtime.sh` | in runtime |
| Default `d3d9=mtld3d;dxgi=dxmt` | all | `launcher/hub` | runtime rules file |
| `WINEDLLOVERRIDES=mscoree,mshtml=d` (all) / mscoree kept for Epic (EOS MSI .NET custom actions) / `IGOProxy32.exe=d` (EA) | all, Epic, EA | `launcher/hub` `session_env()` | runtime rules file (`dll_overrides` per exe) |
| `WINE_TF_EMULATION=1`, `WINE_TF_MAX_*=0`, `MTL_HUD_ENABLED=0`, `WINE_RWX_WX_EMULATION=1` (uncommitted removal pending) | EA | `launcher/hub` | runtime rules file (`env` per exe) |
| `--in-process-gpu` for EADesktop | EA | `launcher/hub` | runtime rules file (`arguments`) |
| x87sidecar on every i386 process | all 32-bit | Wine fork `ntdll/unix/loader.c`, `process.c` (attach unless compatdb.so says no; our compatdb.so has no query, so always) | in runtime |
| BOOLEAN syscall arguments read from the low byte (EA 13.813 hang) | all (2 syscalls so far) | Wine fork `51430b514f7` | in runtime; extend to all BOOLEAN syscalls |
| Raw Windows syscalls from native code (SIGSYS path) | protectors, EAAC | Wine fork `winsyscall.c` | in runtime |
| EAAC Zw stub patching, TF emulation | EA games | Wine fork | in runtime |
| CrossOver hacks keyed on exe name (177 `CW HACK` sites; exe checks for upc.exe, UplayWebCore.exe, EpicGamesLauncher.exe, Fallout4.exe, Diablo IV.exe, ...) | various | Wine fork (inherited) | in runtime |
| Steam overlay DLLs moved aside, `steam.cfg` bootstrap block | Steam | `launcher/hub` `prep_steam()` | stays in the launcher (store-client setup, not per process) |
| NFS 2015: prime the catalog with the public offer id before the content id | NFS 2015 | `launcher/hub` `EA_KNOWN.prime` | stays in the launcher (EA client protocol) |
| Licence `.dlf` bound to an old machine hash: move aside so EA fetches a new one | EA games | manual (2026-10-24) | launcher check (detect `ActivationUI.exe` after launch, or machine-hash change) |
| Epic installs registered from `.egstore` | Epic games | `launcher/hub` `adopt_epic_installs()` | stays in the launcher |
| AoA `Option.ini` kept across sessions | AoA | `launcher/hub` `SETTINGS` | stays in the launcher |
| Heaven's-gate selector 0x33 (Rosetta has no GDT index 6) | upc.exe (Ubisoft packer `.ubx2`), likely other protected i386 programs | not fixed: proven by patching `push imm32; ljmp 0x33:imm32` to selector 0x2B in a copy | runtime (see §3) |
| ARPL instruction in 32-bit protected code | upc.exe | not fixed: x87sidecar aborts ("stock has no ARPL implementation") | x87sidecar |

Rule of thumb: what changes how a **process** runs (backend, DLL overrides, env, arguments, sidecar, CPU-level emulation) belongs in the
runtime; what drives a **store client** (sign-in, catalog priming, install registration, settings files) stays in the launcher.

## 2. Pre-launch detection layer (runtime-side)

Where: the Wine fork's ntdll, at the existing per-process decision point (`preloader_exec` for the first process, `NtCreateUserProcess`
for children), which already decides the x87sidecar and applies compatdb rules before the process image runs.

Why there and not in `hub`: children started by launchers (EALauncher -> EADesktop -> NFS16.exe, Steam -> game) never pass through `hub`,
and the decision must hold for every process. Why not by extending `compatdb.so`: it has no licence (see `docs/compatdb-provenance.md`),
so its source cannot be changed or vendored; our layer runs first and stays independent of it.

Inputs, read from the PE file only (no game content stored): machine (i386/AMD64), imports (d3d8/9/10/11, dxgi, dsound, xinput,
steam_api, EA/Origin DLLs), section names and entropy (`.ubx*`, `.bind`, UPX, "protected"), company/product version strings, exe name.

Rules: one file in the runtime (`share/wine/hub-rules.txt`), same `name=;exe=;key=value` syntax as WINE_COMPATDB, plus predicate keys
(`machine=`, `imports=`, `section=`, `company=`). Keys it can set: `dxgi`, `d3d9`, `dll_overrides`, `env`, `arguments`, `x87_sidecar`,
`gate_selector_fixup`, `arpl`. Order: built-in defaults < runtime rules file < WINE_COMPATDB from the launcher (user override wins).
Every decision is logged in one line per process (`hubrules: <exe> rules=... dxgi=... sidecar=...`), like compatdb does today.

## 3. Ubisoft Connect: findings so far

1. upc.exe is packed (`.text`/`.rdata`/`.data` have raw size 0; the `.ubx2` section unpacks them). The unpacker switches to 64-bit code
   with `push cs; push <ret>; ljmp 0x33:<target>` (10 sites). Rosetta rejects selector 0x33 ("invalid gdt selector index 6") and wedges.
2. With the selector rewritten to 0x2B in a scratch copy, the unpacker's 64-bit code ran and its raw Windows syscalls (0x50, 0x19, 0x0d)
   were serviced by the SIGSYS path. Wine needs no other change for that part.
3. The next blocker is an ARPL instruction: the x87sidecar aborts on it. Without the sidecar, Rosetta raises SIGILL on ARPL, which Wine
   could emulate; with the sidecar (required for performance), the sidecar must translate or trap it.

Runtime fix candidates: (a) rewrite `68 imm32 EA imm32 33 00` to selector `cs64_sel` when an i386 image section is made executable,
gated by the detection layer (`gate_selector_fixup`); (b) ARPL support in the x87sidecar.

## 4. Phases

1. Detection layer skeleton in ntdll: PE probe, rules file, logging; move `compat_db()` and `session_env()` per-exe parts of `launcher/hub` into the rules file. Gate: every process in `hub list` launches with the same backends/env as today (compare the log lines).
2. Extend the BOOLEAN low-byte read to all BOOLEAN syscalls; Wine tests in `dlls/ntdll/tests`.
3. Heaven's-gate selector fixup behind a rule; ARPL in the x87sidecar; Ubisoft Connect end to end.
4. Launcher checks: licence machine-hash detection (EA), Epic install adoption already done.
