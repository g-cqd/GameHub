# ntdll: stop passing the x87sidecar's ROSETTA_DISABLE_AOT on to child processes (2026-10-11 19:07)

## What it fixes

The x87sidecar starts every process it hooks with `ROSETTA_DISABLE_AOT=1`, so that Rosetta
JIT-translates the whole process. Rosetta reads the variable once, at process start, but Wine left
it in the environment. Every process the hooked one started inherited it, and so on down the tree.

In the EA session the first process, `EADesktop.exe`, is started by a DOS path. This runtime's
loader cannot read that file's PE header, so it takes the 64-bit EADesktop for a 32-bit program and
hooks it. Seen live today:
`x87sidecar --cooperative .../wine C:\...\EADesktop.exe --in-process-gpu`.

The whole session inherits the variable from it: services, the 64-bit `EABackgroundService.exe`,
the CEF processes, and `EAGEP.exe`. EAGEP is EA's elevation proxy. It must connect back to the
background service within 3.5 s of being started.

Without AOT, EAGEP JIT-translates all of Wine's unix libraries at every start. That doubles its CPU
time and puts about 0.5 s on the critical path.

With the fix, the hooked process puts the variable back as soon as it runs. Its children get
Rosetta's AOT cache again. The hooked process itself keeps JIT, and with it its x87 acceleration.

## Files

| File | Install as | SHA-256 |
|---|---|---|
| `x86_64-unix/ntdll.so` | `<Wine>/lib/wine/x86_64-unix/ntdll.so` | `2d3be8db858eaf76658233d4d833abe594e72dcc9779cec4eb243371e1546b7a` |
| `x86_64-unix-base-ab-only/ntdll.so` | for A/B comparison only: the same build without the fix | `004d50ab2bdd07611652c062f50ba6330e0edb417cd0e66dabf50a675947f7ac` |
| `patches/…runtime-lineage-3d6ed34a4bf.patch` | the change as built here | |
| `patches/…development-dbbd488da82.patch` | the same change for the `development` line | |

The original in `Runtimes/hub-0` and its clones has SHA-256
`52dc25c5085b961c9a13a724743a2748cfea3aebfd5c8d1cc66151a0a019bad8`. Only the unix `ntdll.so`
changes; the PE `ntdll.dll` files stay as they are.

## Source and build

This runtime's ntdll is not built from `development`. That line lacks the runtime's ntdll patches
0005–0010, the W^X emulation for NFS2015, so a `development` ntdll.so must not go into `hub-0`.

The package is built from the runtime's own lineage, in the detached worktree
`/Volumes/ExT2/GameHub/work/wine-gepperf/rt-src`:

- `1a7b0c76` (athei/wine cx-26-patched)
- plus nfs-macos `Packaging/NFS2015Runtime/patches/0001-0010` (applied with `git am`)
- plus commit `3d6ed34a4bf`

The configure and make steps are `configure-rt.sh` and `make-rt.sh` in this folder: x86_64 Apple
clang, macOS 15.0, `--with-unwind`, both architectures, out of tree in `../rt-build`.

How it compares with the shipped `52dc25c5…`:

- **Same:** the set of strings (1770), apart from the fix's two new ones, and the exported symbols.
- **Different:**
  - The shipped file was built against an older SDK. It waits with `__ulock_wait`; this build uses
    `__ulock_wait2` and the os_sync path.
  - The shipped file has a few arm64ec strings.
- **Measured effect of the rebuild alone:** none. Rebuilt base 1414 ms against shipped 1456 ms,
  within the spread (table below).

The `development` commit `dbbd488da82` is in the detached worktree
`/Volumes/ExT2/GameHub/work/wine-gepperf/src`, on top of `825fdbcacc9`. Neither commit is pushed,
and no branch was moved.

## Install (into a runtime CLONE, never into a runtime in use or into /Volumes/ExT2/Bundles)

Quit EA and every Wine process of the prefix first, so the new ntdll.so is used by the whole
session. A mix of processes would keep the leak alive from the old ones.

```bash
PKG=/Volumes/ExT2/GameHub/work/wine-gepperf/20261011-1907
SRC=/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv   # or any hub-0 lineage runtime
DST=/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-aotfix
/bin/cp -c -R "$SRC" "$DST"
L="$DST/lib/wine/x86_64-unix"
mv "$L/ntdll.so" "$L/ntdll.so.orig"
/bin/cp "$PKG/x86_64-unix/ntdll.so" "$L/ntdll.so"
shasum -a 256 "$L/ntdll.so"    # expect 2d3be8db…
```

A new clone has new inodes, and Rosetta's AOT cache is keyed per file, so the first processes from
`$DST` translate its unix libraries again. A first `EAGEP.exe` from a fresh clone took 8–10 s in
tests, which fails EA's 3.5 s limit. Before the first game launch from the clone, warm the cache:

- Start the EA app from `$DST` and wait until it is up; its 64-bit processes translate most
  libraries.
- Or use the Hub's `gamehub-cli runtime warm-eagep`, below; this has not been validated end to
  end yet.

## Rollback

```bash
L="$DST/lib/wine/x86_64-unix"; mv "$L/ntdll.so.orig" "$L/ntdll.so"
```

Or point the Hub back at the old runtime. The environment variable the fix uses
(`WINE_X87_SAVED_ROSETTA_DISABLE_AOT`) exists only between the exec of the sidecar and the start of
the hooked process, so nothing persists.

## Measurements (all medians over interleaved runs; harness in `bench/`)

**EA's real path, modelled in a throwaway prefix.**

- **Setup:**
  - A 32-bit launcher (`bench/launch32.c`) runs under the sidecar and `CreateProcess()`es EAGEP,
    as the hooked session does.
  - A stand-in service (`bench/standin.c`) under the name `EABackgroundService` satisfies EAGEP's
    liveness check.
  - The harness listener on 127.0.0.1:50999 plays the background service's IPC port.
- **Metric:** wall time from the `CreateProcess` call to the accepted IPC connect.
- **Conditions:** warm caches, machine load 4.2–5.7 (10 cores shared with other agents).

| arm | n | median | IQR | p90 | min–max |
|---|---|---|---|---|---|
| shipped ntdll.so | 8 | 1456 ms | 35 | 1481 | 1417–1695 |
| rebuilt base (no fix) | 8 | 1414 ms | 122 | 1527 | 1360–1646 |
| rebuilt with fix | 8 | **932 ms** | 22 | 955 | 867–1027 |

**The same mechanism in isolation.** EAGEP started directly, without sidecar, with and without
`ROSETTA_DISABLE_AOT=1`; n=5 each, load 4.5–5.8:

| arm | median | IQR | p90 | CPU of the EAGEP process |
|---|---|---|---|---|
| AOT on | 1069 ms | 645 | 1703 | 952 ms |
| AOT disabled | 1738 ms | 186 | 2009 | 1800 ms |

**Functional checks.**

- **The child now uses AOT.** A fresh runtime copy got 23 new AOT cache entries, one per unix
  library EAGEP loads, with the fix, and none without it.
- **x87 acceleration is unchanged.** A 32-bit x87 loop takes 160–162 ms hooked with either
  ntdll.so, against 2.33 s unhooked. A 32-bit grandchild of a hooked process is hooked again
  (162 ms). The results are bit-identical.

**Cold-ish series.** These had 4 min of idle before every run. A run after idle still pays a large
start-up penalty in this throwaway setup (EAGEP's first log line at 2.2 s instead of 0.35 s, with
hundreds of major faults), with or without the fix. Only n=2–3 per arm finished. Two series were cut
short when another job and then the orchestrator stopped all Wine processes, so there is no cold
distribution for the fix.

**Live, before the fix.** The real background-service launches today, createProcess to 'Client
connected', from the EA logs:

- Since the font-list cache was deployed: n=13, median 1330 ms, p90 3360 ms (3025, 3360 and a
  failed 3501).
- From 15:53Z on: n=10, all 1006–1934 ms.

There is no live after-measurement yet, because the fix has not run in the live session.

## Not part of this package (findings)

- **The DOS-path weakness is the root of the hooked EADesktop.** `development` already resolves DOS
  paths for the first process (`get_first_process_target`, commit `73e7054dfbc`). This runtime
  lineage lacks that, so 64-bit EADesktop runs JIT-only and twice as slow. Porting that fix would
  also make EADesktop and the brief's manual `gep-run.sh` runs use AOT.
- **crypt32 imports the host's root certificates in every process: 123 ms with AOT, 193 ms
  without.** Of that, about 85 ms is the macOS trust store query. A per-session cache of the system
  domain, keyed on its keychain's file stamp, would save 60–100 ms per process. Not done: it is a
  trust-anchor cache and needs its own review.
- **winemac.drv's first load holds the loader lock** (Cocoa start-up: 95 ms alone, 250–500 ms inside
  EAGEP). EAGEP's WMI query of Win32_VideoController (`GetDC(NULL)` for the bit depth) triggers it,
  and EAGEP's other threads wait for it in `CreateThread`.
- **Page-cache warming of EA's files and the PE libraries pays little.** A fully cold copy of the
  EA app and of the runtime's PE libraries (fresh APFS clones, with the unix libraries and AOT
  files still warm) cost only +0.1–0.15 s. Whether pre-reading also removes the larger penalty after
  idle, which also involves the unix libraries and the AOT files, was not measured to the end: the
  `fixpw` arm of the second series was cut short.
