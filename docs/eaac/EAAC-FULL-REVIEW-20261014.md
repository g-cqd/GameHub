# EAAC / F1 24 initiative — consolidated review

> Wine source: now at /Users/gc/Developer/wine (moved 2026-10-15), branch `main`. Former `/Volumes/ExT2/GameHub/src/wine` paths in this document are rewritten to that location; `eaac-ntdll-20261014` and `development` mentions are 14 Oct history.

14 October 2026. Four read-only reviews, run in parallel: correctness/completeness, memory-safety/security, performance/test-quality, and whole-initiative/process. Nothing was edited. Findings below are merged, deduplicated, and ranked by severity within each section. File:line references are into `/Users/gc/Developer/wine/dlls/ntdll/...` unless stated otherwise.

**Overall picture.** The core Windows-behavior fixes are sound (the `id+1` sentinel fix, zero-extended NTSTATUS, the 32-byte stub image, asm ABI/CFI). The dangerous part is the all-stub rewrite: it is published unsafely (a real race, found independently by two reviewers), triggered by a heuristic that fires in any process, costs real CPU on every Nt call afterward, and — separately from code quality — amounts to presenting Windows-identical bytes to defeat the anti-cheat's environment check. The project also has process problems: the docs are stale relative to what's actually deployed, work is uncommitted and lives only on one external volume, and sensitive dumps/logs sit world-readable.

---

## 1. Correctness (code)

**C1 — BLOCKING — race: patched stubs are not recognized as patched until the whole rewrite finishes**
`winsyscall.c:258-329` (count published only at the end of the loop), `signal_x86_64.c:2882-2909`, `:3360`.
Thread A starts rewriting ~257 stubs; `eaac_patched_count`/the membership table stay empty until A finishes. If thread B calls an already-rewritten-but-unregistered stub in that window: on the `int 0x2e` path, `is_patched_stub_address()` returns false and the fault falls through to a plain access violation (process dies); on the `SIGSYS` path, the Windows syscall number is used directly as a Wine id, dispatching the wrong syscall with the caller's arguments. The window is seconds-scale (hundreds of export scans + mprotects), inside a multi-threaded process (EA Desktop/CEF has many threads).
**Fix:** publish each stub's address *before* writing it (so membership is a superset, never a subset, of "has been written"); on write failure, retract. Better: make membership decidable from stub *content* (check for the Windows-image signature bytes) instead of a side table, which also fixes stale membership after a partial write. Write the opcode/number last, tail-NOP first, so a half-written stub never reads as "new" while still holding old semantics.

**C2 — BLOCKING — the patch trigger is a process-wide heuristic, not scoped to the anti-cheat**
`signal_x86_64.c:2826-2855, 2882`.
Any SIGSEGV/SIGBUS from an execute fault on a readable-non-executable page, in *any* Wine process, permanently rewrites all ~257 stubs for that process. A JIT (CEF/V8), a DEP probe, or any W^X runtime can trigger this by accident; a hostile guest can trigger it on purpose. The code comment calls this "safe," which was true for the original 6-stub patch but not for 257 stubs process-wide.
**Fix:** gate on explicit per-executable opt-in, reusing the existing `WINE_COMPATDB` mechanism in `start-ea.sh` (e.g., an `eaac_stubs=1` key for the AC launcher only), and/or require the faulting module to match the expected anti-cheat image before patching.

**C3 — blocking — RX-restore failure after mprotect is swallowed, page stays writable+executable forever**
`signal_x86_64.c:2808-2824`.
If the final `mprotect(RX)` fails, the function still returns success (correctly, to keep the stub counted — see C1), but the failure is logged only at `TRACE` level, invisible under the default `WINEDEBUG=-all`. The page silently stays RWX indefinitely.
**Fix:** escalate to `ERR_(seh)` on restore failure and track/report a count of such failures at the end of the patch pass; consider `abort()` if treated as fatal.

**C4 — blocking — `NtInitializeRegistry` accepted-flag path returns the wrong status**
`signal_x86_64.c:3270-3284`.
Flags `0`, `1`, `2`, `0x1000`–`0x13e8` return `STATUS_NOT_IMPLEMENTED`; real Windows post-boot behavior (per ReactOS `ntapi.c`) is `STATUS_ACCESS_DENIED` (`0xC0000022`) for an already-initialized registry. A probe that sends a valid flag distinguishes Wine from Windows on this status alone.
**Fix:** return `STATUS_ACCESS_DENIED` for accepted flags; verify against the 19041 `ntoskrnl` disassembly at RVA `0x78df90` you already have, and pin with a test.

**C5 — suggestion — `int 0x2e` route skips the Rosetta MXCSR fix applied on the other two dispatch routes**
`signal_x86_64.c:2912-2934` vs `:3397-3415`.
The "CW Hack 24265" MXCSR correction is applied on the foreign-SIGSYS and patched-stub-SIGSYS paths but not on the segv/`int 0x2e` path. Guest FP control state can be clobbered on every patched-stub call now (was 6 stubs, now ~257).
**Fix:** factor the frame-setup+MXCSR-fix logic (duplicated three times) into one helper, call it from all three dispatch routes.

**C6 — suggestion — dead/untested `SIGSYS` patched-stub branch; dead `is_patched_stub_address(rip)` check**
`signal_x86_64.c:3360`. Wine always sets `SystemCall=1` for patched stubs, so they always take `int 0x2e`, never `syscall` — this branch can't currently execute, and `is_patched_stub_address(rip)` (vs `rip-0x15`) can never match a stub start. Either exercise it with a test that clears the byte, or delete both as dead code.

**C7 — suggestion — `int 0x2e` recognized only from patched ntdll stub addresses, not from arbitrary memory**
`signal_x86_64.c:2909`. A raw `int 0x2e` from foreign/packed code (not a Wine-managed stub) falls through as an access violation instead of being translated, unlike the foreign-`syscall` case which is handled. Gap in the stated "SIGSYS/int 0x2e translation" scope.

**C8 — suggestion — unpatched/unimplemented syscalls are silent**
~216 of 473 cached Windows numbers are never patched (no stub resolved) and return `STATUS_NOT_IMPLEMENTED` with no log. A loader hashing one of those names fails with no diagnostic. **Fix:** WARN once per unresolved name at patch time; assert `count == resolved` in tests, not just `count >= 8`.

**C9 — suggestion — spin-wait for "patch done" is iteration-bounded, not time-bounded, and fails silently**
`signal_x86_64.c:2892-2895`. `100000 × sched_yield()` (~0.1–0.5 s on Darwin) is not a real timeout; under contention (see C1/C2 cost) a waiter can give up before the patch finishes and proceed with unpatched stubs — the exact failure mode the mechanism exists to prevent. Only a TRACE line marks this. **Fix:** bound by wall-clock time via `clock_gettime`, `ERR_(seh)` on timeout, and make the flag a proper atomic (not `volatile` + manual fence).

**C10 — nit — naming/dead code**
`eaac_*` names a general Windows-stub rewriter; `get_wine_syscall_stub_address` has no remaining callers (`winsyscall.c:167`, `unix_private.h:752`) — delete. `wine_syscall_id_for_windows_nr`'s "id+1 | KNOWN | 0" tri-state is decoded (`id--`) independently in three call sites — give it a named enum return instead.

---

## 2. Completeness

**CM1 — the install chain has unaddressed gaps that gate before any Wine fix could matter**
- F1 license file missing (`…\EA Services\License\16425782.dlf`), causing a 120 s reactivation timeout on every launch attempt.
- `eaanticheat.sys` driver file doesn't exist anywhere in the prefix — the genuine installer never registered it.
- The actual failure is a **modal dialog** ("The program encountered E111000D at 0026FA30 during initialization. Conflicting software detected!") that EA Desktop later reports as an exit code once dismissed — this is new information not reflected in prior handoffs, which treated E111000D only as an exit code with timing data.
- A documented multi-gate ladder exists (E111000B → E1110005 → E1110009 → E111000D on a second verification round) in an archive file (`EAAC-gate5-status-report.md`) not linked from the main handoffs; the Desktop handoffs collapse this into "Windows interface contract" and omit it.

**CM2 — zero of the eight stated completion criteria are met.** EA Desktop does pick F1 24 and "launch" succeeds at the EA-Desktop layer; the anticheat launcher never completes, no service/SCM transition is attempted on current runs, no driver is active, `F1_24.exe` has never been created, nothing has run more than once, and no performance baseline exists.

**CM3 — no build/deploy recipe is documented.** No command to build `ntdll.so`, patch the PE-side version resource, verify hashes, or atomically swap the runtime. Reproducibility depends on unrecorded manual steps.

---

## 3. Performance

**P1 — HIGH IMPACT — every Nt call from the rewritten stubs now traps via signal instead of a fast indirect call**
`signal_x86_64.c:2882`, `winsyscall.c:352`. The old patch touched 6 rarely-used stubs; the new one removes the fast tail from all ~330+ resolvable stubs, including hot ones (`NtWaitForSingleObject`, `NtClose`, `NtSetEvent`, `NtAllocateVirtualMemory`, `NtYieldExecution`, `NtQueryPerformanceCounter`). Each call now costs a `#GP`/SIGSYS round trip instead of ~50–100 ns of user-mode dispatch — reasoned estimate of low microseconds per call natively, several times that under Rosetta's exception-to-signal conversion. At 10⁴–10⁵ such calls/sec in a busy process, this is a plausible multi-percent to double-digit CPU tax for the process's whole lifetime, compounding C2's over-broad trigger scope.
**Fix (priority order):** (1) gate per-exe via `WINE_COMPATDB` as in C2; (2) patch on-demand only the names actually resolved by the loader instead of all 257 eagerly; (3) add a micro-benchmark asserting the cost so regressions are visible.

**P2 — 473 linear PE-export scans, done twice (load time in every process, then again in the patch loop)**
`winsyscall.c:121-150`. O(NumberOfNames) per lookup × 473 lookups × 2 passes ≈ 0.5–0.6M `memcmp` calls, estimated 5–15 ms native, more under Rosetta — paid by every Wine process at startup, and again (stalling the faulting thread, spinning the losers) inside the signal handler. **Fix:** binary-search the sorted export name table (names are sorted in the PE format), or cache resolved addresses from the first pass and skip the second scan entirely (~100x fewer comparisons).

**P3 — ~946 separate `mprotect` calls instead of ~4**
`signal_x86_64.c:2808-2824`. Stubs are 32 bytes, 128 fit per 4K page; the code flips RWX→RX per *stub* rather than batching per page range. **Fix:** compute the covering page range once, mprotect RWX, write all stubs, mprotect RX once.

**P4 — test suite is largely tautological**
`tests/syscall.c:412-420`. The 342-check "golden" comparison uses the same 32-byte template the implementation itself writes, so a systematically wrong template (e.g., wrong NOP length) would still pass. **Fix:** pin one independently-captured real-Windows-19045 stub as a literal byte constant and compare against that, not against the implementation's own table.

**P5 — missing boundary/concurrency/failure tests**
No test for: registry-flag boundaries at `0x1000`/`0x13e8`/`0x13e9` on the *valid* side (only invalid side covered); max valid syscall id (`0x1d8`) or `0xffffffff`; two threads racing the first fault (would catch C1); mprotect failure injection; wait-timeout expiry; non-macOS/non-19045 Windows skip conditions (tests currently assume Wine + build 19045 unconditionally and would fail rather than skip elsewhere).

---

## 4. Memory safety

**M1 — HIGH — guest-writable PE export directory is re-parsed, untrusted, inside the SIGSEGV handler**
`winsyscall.c:120-153, 288-290, 352-359`. The patch-time resolution re-walks `NumberOfNames`, `names[i]` RVAs, `NumberOfFunctions`, and `functions[]` RVAs directly from the live ntdll image at signal time, with only a partial bounds check (`func+8` against image size, not `func+32`). A guest that corrupts these tables (accidentally via a hooking engine, or deliberately) and then forces the exec fault gets an attacker-steered 32-byte write at a computed address inside the ntdll image — or crashes the process via a wild read, with SIGSEGV masked inside its own handler.
**Fix:** resolve once at init into a host-owned table (`{addr, nr, id}`), validate each entry's range against `.text` bounds and the service-table size at that time; have the signal-time patcher iterate only this trusted table, never re-parsing the PE.

**M2 — MEDIUM — patch-publication race (same defect as C1, security framing: wrong-syscall dispatch from attacker-influenced timing)**
Same locations as C1. From a memory-safety angle: the torn 4-store rewrite (`signal_x86_64.c:2796-2805`) means a concurrent thread can observe a half-written stub whose opcode says one thing and whose immediate says another — not just wrong dispatch, but potentially an inconsistent fetch mid-instruction. **Fix, additional to C1:** perform the write window as RW (not RWX) and rely on the resulting exec fault to naturally serialize concurrent callers against the in-progress patch (any thread that executes mid-rewrite pages faults, falls into the existing "wait for patch done" path, and retries after restore) — this also closes the C1 window without needing per-thread suspension.

**M3 — MEDIUM — hard-coded 4 KiB page math instead of the host's actual page size**
`signal_x86_64.c:2808-2824` uses literal `~0xfff`/`+0x1000`. On a host with a different page size, `mprotect` fails with EINVAL and the patch silently no-ops (compounds C3). **Fix:** use `host_page_size`/`host_page_mask`.

**M4 — MEDIUM — blind protection restore ignores the page's actual original protection and Wine's own view tracking**
`signal_x86_64.c:2808-2824`. Restoring to a fixed `PROT_READ|PROT_EXEC` can clobber concurrent `VirtualProtect` work by the guest on the same pages, and doesn't update Wine's internal view-protection bookkeeping, causing later desync. **Fix:** query current protection via `mach_vm_region` before writing, restore to that, and route the change through Wine's existing view-protection update path rather than a bare `mprotect`.

**M5 — LOW — lock/logging work performed inside signal-handler context**
`signal_x86_64.c:2856-2871`. `trace_patched_stub_termination` takes `virtual_mutex` (not async-signal-safe in general) and formats TRACE output from within the handler. Diagnostic-only, low likelihood, but a correctness hazard if conditions change. **Fix:** either drop the guest-memory read entirely, or validate the return address lies within the current thread's known stack bounds and do a bare pointer read with no lock.

**M6 — LOW — `is_execute_fault_on_readable_page` doesn't check the fault address actually falls inside the returned region**
`signal_x86_64.c:2848-2850`. `mach_vm_region` returns the *next* region at-or-after the query address; the code never checks `rip` is actually within `[raddr, raddr+rsize)`. A fault at an unmapped address followed by a readable region elsewhere in the address space is misclassified as "the dance," feeding into C2's over-broad trigger. **Fix:** add the containment check.

**M7 — LOW — integer truncation/wrap on the cached syscall `id`**
`winsyscall.c:209`. `id + 1` on an unbounded raw immediate read from a (guest-influenceable, pre-rewrite) stub can wrap or spuriously set the `WIN_SYSCALL_KNOWN` bit. **Fix:** validate `id` against the service-table size at the point it's first cached, not just at dispatch time.

---

## 5. Security / operational safety

**S1 — HIGH — guest-writable host runtime + unsandboxed launch path with broad entitlements**
`Prefix/dosdevices` maps `e:` to the whole GameHub volume and `z:` to all of `/Volumes`, including the home directory (`~/.ssh`, browser profiles). The signed `bin/wine` host binary has `allow-unsigned-executable-memory`, `disable-library-validation`, and camera/audio-input/Bluetooth entitlements, while the `.so` libraries it loads from the writable runtime directory are completely unsigned. A Windows-side process (the anti-cheat, an installer, a dropped payload — 530 files were observed dropped into the prefix by the anti-cheat in one capture) can overwrite `ntdll.so`, `start-ea.sh`, or the x87 sidecar, which the user's own signed, entitlement-holding host then loads/executes natively on next launch.
**Fix:** narrow `dosdevices` to only the library folders actually needed (not the whole volume, not `z:`→`/Volumes`); sign every runtime `.so`/`.dylib` under one Team ID and re-enable library validation; drop the camera/audio/Bluetooth entitlements if unused; add a `codesign --verify` gate to `start-ea.sh` before exec.

**S2 — HIGH — EA session tokens sitting in world-readable `/tmp` dumps**
28 `/tmp/eaac-full-*.bin` files (~20 GB total), mode 0644, containing JWT-shaped strings and `access_token`/`refresh_token`/`email` keys (presence confirmed by pattern match; liveness of tokens not verified). These persist indefinitely since macOS doesn't promptly purge `/tmp`.
**Fix:** delete or move into an encrypted container now; rotate/sign-out the EA session used; for any future capture use `umask 077` + a `mktemp -d` 0700 directory + `trap ... EXIT` cleanup; never leave dump-instrumented `.bak-*` binaries next to the live runtime.

**S3 — MEDIUM — deploy/rollback has no integrity story**
Runtime `.so` files are edited in place with no manifest, no checksums file, no code signatures, and backups (`ntdll.so.bak-20261013-prod`, `-regs`, `.orig-aot`) accumulate unlabeled beside the live library. PE (`.dll`) and unix (`.so`) halves are never archived as a matched pair, so a rollback can mismatch them. Overwriting a mapped `.so` in place under running processes risks SIGBUS.
**Fix:** build into versioned, immutable runtime directories (e.g., named by git sha), with a `SHA256SUMS` manifest and signatures; switch via atomic symlink flip (`ln -sfn`); never edit a runtime in place while any process has it mapped.

**S4 — MEDIUM — debug/trace logs can carry secrets, created world-readable**
`start-ea.sh` passes `HUB_WINEDEBUG` straight through with default umask (0644 observed on every archived log, one reaching 438 MB); a saved `/tmp/eaac-winedebug` wrapper enables `+relay,+file,+reg,+environ` on the anti-cheat process, which records argument strings that can include credentials. No rotation. (Scans of recent logs found no live secrets — this is latent exposure, not an observed leak.)
**Fix:** `umask 077` before creating logs; warn when `HUB_WINEDEBUG` enables high-risk channels; redact `Bearer`/`access_token`/`Cookie` patterns in any archived trace.

**S5 — LOW — predictable `/tmp` filenames vulnerable to symlink pre-creation**
Several wrapper scripts (`/tmp/launcher-fullenv.sh`, `/tmp/eaac-retest-launcher.sh`) and `eaac-probe-harness.c:444` write to fixed or low-entropy `/tmp` paths without `O_EXCL`/`O_NOFOLLOW`. **Fix:** use `mktemp`, or `open(..., O_CREAT|O_EXCL|O_NOFOLLOW, 0600)`.

**S6 — LOW — auto-selected EA Desktop binary trusts whatever is newest on disk**
`start-ea.sh` picks the highest-`sort -V` installed `EADesktop.exe` under a guest-writable directory; a dropped higher-version directory becomes what's launched next time, with no publisher/signature check. **Fix:** verify Authenticode signature or pin the expected path/version.

**S7 — hardening notes, no exploit scenario needed:**
- A stale background poller (`poller.sh`, observed running 1d14h) still watches a now-moved capture directory every 2 s — kill it.
- The archived anti-cheat payload capture (`eaac-capture-20261012-231849/dropped/`, 530 files, 2.7 GB) retains execute bits — strip them (`chmod -R a-x`) or tarball it inert.
- Prefix credential material (`EA Desktop/cookie.ini`, CEF profiles) sits at 0644/0777; tighten permissions and confirm the volume is encrypted.
- `ROSETTA_X87_PATH`/`HUB_X87_PATH`/`HUB_RUNTIME` env overrides are executed without any signature check — verify Team ID before use or drop the override path.

---

## 6. Process / documentation issues (whole-initiative review)

**D1 — HIGH — handoff docs are stale relative to what's actually deployed and tested.** All four Desktop docs state job 469 (`d585a642…`) is the deployed, tested runtime and job 473 (`313e87df…`) is "not deployed, no live result." In fact job 473 **was** deployed and **does** have a live run (`run-473-20261014-102650/REPORT.txt`), and jobs 474/475 exist and aren't mentioned at all. **Fix:** rewrite the "tested vs. deployed" tables to match the live `ntdll.so` hash at time of writing; re-run the 342/2318-check suites against whatever is actually deployed, not assume prior results carry over.

**D2 — HIGH — the "27/169/326 s error timings" conclusion is likely an artifact, and the real finding (a visible modal dialog) wasn't captured in the docs.** Evidence from `WINDOW_REPORT.txt` and a screenshot shows a Wine dialog reading "The program encountered E111000D at 0026FA30 during initialization. Conflicting software detected!" The varying timings line up with how long that dialog sat open before being dismissed or the process killed — not a launcher-internal timer. **Fix:** describe `E111000D` as "a modal gate-failure dialog, dismissed or killed at varying times" rather than implying a timing signature; capture/screenshot the dialog automatically in future runs.

**D3 — HIGH — the project deliberately masks Wine's identity from the anti-cheat, and this isn't labeled as such in the docs.** Committed history (`ed6ebe1c693` and an earlier commit renaming `wine_get_version`, stamping Windows version resources) plus the uncommitted work extend this to all 257 stubs, explicitly to make Wine's bytes hash-match Windows so the loader's probe "fails cleanly" / "fails the hash check" is avoided. This is categorically masking, not implementing real Windows kernel-driver behavior, and the handoffs frame it neutrally as a "Windows interface contract" rather than disclosing it as detection evasion.
*(Cross-reference: this is exactly the category the user's last instruction ruled out going forward — "we don't want to evade anticheat detection." This finding is about the already-existing, already-committed and already-deployed code, which predates that instruction and should be labeled honestly regardless of what happens next.)*
**Fix:** add an explicit "known evasion techniques already in the tree" section to the handoff; have the user decide, with eyes open, whether this part of the stack is kept, and don't extend it further (consistent with current scope).

**D4 — MEDIUM — work is uncommitted, unbacked-up, and lives entirely on one external volume.** The Wine source tree had 9 local commits ahead of `origin/development` at review time (wine is now on `main` at /Users/gc/Developer/wine, moved 2026-10-15), all unpushed, plus an uncommitted diff on top; the external drive holding source, runtime, prefix and launcher script is 80% full with no second copy. The current HEAD commit message is itself stale (says "six stubs," "int 0x29" — both since changed). **Fix:** commit the current state to a branch, tag it with the job number/hash, push to a remote, and keep a second copy of the critical artifacts off that one drive.

**D5 — MEDIUM — no legal/ToS risk note anywhere in the handoffs.** EA's anti-cheat explicitly disallows Wine/Proton; presenting spoofed identity to pass that check risks account action on the real account used for every test run. **Fix:** add a risks section; use a throwaway account for any further anti-cheat-facing experiments.

**D6 — LOW — report-collection hygiene.** The 1,729-document archive is reasonably permissioned (0700/0600) and a secret-pattern scan found no clear leaked credentials in it, but it does leak local machine layout (home directory names, inaccessible paths) and contains duplicate-named copies not reconciled in the manifest. Separately, the raw `/tmp` dumps (see S2) are far more exposed than the curated archive. **Fix:** scrub local paths before any external sharing; keep both the archive and `/tmp` dumps private regardless.

---

## Priority order if acting on this report

1. **D3** — decide, explicitly, what to do about the already-deployed Wine-identity-masking code, since it conflicts with the stated going-forward scope.
2. **S1, S2** — the guest-writable runtime/entitlements and the world-readable token dumps are real exposure right now, independent of whether F1 24 ever runs.
3. **C1/C2/M2** (same race, two framings) — fix before any further iteration on the stub rewrite, since it causes crashes/misdispatch today.
4. **C3, C4, M3, M4** — the mprotect/restore/status-code correctness items, cheap to fix, needed for any faithful-Windows-behavior claim to hold.
5. **D1, D4** — fix the documentation/hash mismatch and commit+backup the work, so the next session isn't misled the way this one started out being.
6. **P1–P3** — performance, once correctness is settled.
7. **CM1** — the F1 license file and `eaanticheat.sys` gaps are required regardless of any Wine fix; nothing above will matter if these aren't also resolved.
