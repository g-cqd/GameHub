# Session snapshot — 2026-10-14, "consolidate-mac-gaming-stack"

Written mid-session because the user had to step away. **UPDATE: all agents were explicitly
halted before stepping away — every one confirmed clean, nothing mid-write anywhere.** To resume:
open a session and message the agent IDs below with SendMessage (names like `a0b156541ccf65d47`
still resolve after completion — resuming replays their final state and lets them continue). If
an ID no longer resolves, re-read the referenced files/worktrees below to recover state and
re-dispatch as needed.

## HALT STATE (verified clean — read this first)

Every agent below was sent an explicit halt instruction and confirmed in plain text, with no
further tool calls after confirming. Cross-checked, no discrepancies between reports.

| Area | Repo | Pushed to `origin/main`? | Uncommitted anywhere? | Where the work sits |
|---|---|---|---|---|
| CI merge (`aee15b30119a7f254`) | rosetta3 | **Yes** — `fb129d8` | No | landed |
| Clippy debt (`aff4c4f5ade9ca026`) | rosetta3 | No | No | branch `fix/r3-coverage-clippy-debt` pushed, worktree `/Users/gc/Developer/rosetta3-coverage-clippy` — 2 judgment calls need a human look before merge (see "Done" section below for what they were) |
| x87 control-word coverage (`ab7bdc15bfcb56a43`) | rosetta3 | No | No | 4 commits in `/Users/gc/Developer/rosetta3-p02` (ends `a79c9e7`), 4 in `/Users/gc/Developer/rosetta3-p02-lower` (ends `fa4d5f9`, mostly duplicate/unused), 1 in `/Users/gc/Developer/rosetta3-p02-bench` (`21fa300`) — **do not push rosetta3-p02's commits until `/tmp/p02/step1-verify.log` and `/Users/gc/.local/state/agent-work/logs/job-780.log` are read and confirmed zero failures** (the job's exit code 0 does NOT mean the checks passed — it's a logging artifact) |
| Old fldpi fix (`a0b156541ccf65d47`, `a84fd2fcd6e0de44e`) | rosetta3 | No | No | commit `2ae8f28` on branch `fix/fldpi-jit` in `/tmp/r3-fldpi`, rebased onto `fb129d8` — **same caveat**: read `/tmp/r3-fldpi-logs/summary.txt` before pushing, exit code 0 on the verification job doesn't mean the checks passed |
| Cache/JIT stages 1-3 (`ad28c70e65c9b2ec2`, `a9cf28b7ebad3d054`) | rosetta3 | **Partial** — 2 foundation commits only: `54ec7de` (design docs), `464e90d` (`r3-jitmem` per-page generation counters + `insert_checked`, real race fix, tested) | **Yes** — `/Users/gc/Developer/rosetta3-wt/tcache` (mid-rewrite, probably doesn't compile) and `/Users/gc/Developer/rosetta3-wt/jit` (partial install protocol, untested) both have uncommitted work | nothing else landed; stage 1 ~30% done, stage 2 blocked on a determinism test that doesn't exist, stage 3 design-only |
| Benchmark harness (`a746ae6a4b08bbb70`) | rosetta3 | No | No | commit `4a5c52c`/`21fa300` (same commit, rebased) in the bench worktree, results at `bench/p02/results/baseline-origin-main.md` |
| GitHub Actions watch (`a8fcf8989f581929e`) | rosetta3 | n/a (read-only) | n/a | a `gh run watch 38606241241` poll may still be running in the background; nobody will act on its result until resumed |

**Orphaned/leftover, not cleaned up, confirmed harmless:**
- Four orphaned Wine `ntdll_test.exe exception` processes (PIDs 305, 67297, 92514, 99906) have
  been pinning ~100% CPU since ~16:01 — not created by any of today's agents, were slowing
  everyone's builds. Consider killing them when you resume if they're still there.
- Worktrees left in place (all either empty-uncommitted or holding the unpushed commits above,
  safe to leave): `/Users/gc/Developer/rosetta3-wt/{jit,tcache}`,
  `/Users/gc/Developer/rosetta3-p02{,-lower,-bench}`, `/Users/gc/Developer/rosetta3-coverage-clippy`,
  `/tmp/r3-fldpi`, `/private/tmp/r3-tcache`, `/private/tmp/r3-tcache-crate`.
- Scratch dirs: `/tmp/p02/`, `/tmp/r3-fldpi-logs/`.
- A dangling doc reference: the fldpi fix's commit message cites
  `docs/benchmarks-rosetta3-vs-rosetta2-vs-x87sidecar-20261014.md`, which isn't on `main` yet
  (it's only in whichever worktree the benchmark task used) — reconcile when landing that branch.

**To resume:** for each row above, SendMessage the agent ID with something like "resume — read
the verification log at X, and if clean, push" or re-dispatch fresh if the ID no longer resolves.
Do NOT blindly push any of the unpushed branches without reading their verification logs first —
several of them have a real caveat that exit-code-0 doesn't mean the tests actually passed.

## Big picture

Two linked efforts today:
1. **EAAC/F1 24 on macOS** — concluded unfixable without evading anti-cheat (EA's anti-cheat needs
   a Windows kernel driver; Wine can't host one). A full review of that work's code quality was
   done and (mostly) fixed. See `/Users/gc/Desktop/EAAC-FULL-REVIEW-20261014.md`.
2. **Consolidate the Mac-gaming dev stack** — sync 5 repos (wine, x87sidecar, mtld3d, dxmt,
   rosetta3) with upstream, move GameHub code off the external drive, collapse all repos to a
   single `main` branch (no dev/topic branches — explicit standing policy now), then push
   rosetta3 toward "supersede Rosetta 2 and Rosetta2+x87sidecar" with a persistent cache and a
   tiered JIT. Plan file: `/Users/gc/.claude/plans/lazy-prancing-bachman.md` (now partly stale —
   see "Done" below for what's actually landed vs. the plan's original text).

## DONE — fully landed, verified, pushed to `main`

- **wine** (`/Volumes/ExT2/GameHub/src/wine`, origin `g-cqd/wine`): synced with `athei/cx-26-patched`,
  all topic branches merged (`eaac-ntdll-20261014`, the `rt-src` W^X-emulation work — 6 real
  commits kept, 17 duplicates dropped, original tip tagged `archive/rt-src-23commits-20261014`),
  renamed `development`→`main`. Final tip `e82dc1e04ec77a776b9f683237e2fe0b38f4ce8d`. 352/352
  `syscall.c` tests passing. **Two leftover branches not yet cleaned up**:
  `development-cx26-sync-20261014`, `wx-emulation-merge-test` — check if safe to delete.
- **x87sidecar** (`/Users/gc/Developer/x87sidecar`, origin `g-cqd/x87sidecar`): synced with
  `athei/x87sidecar` (a real architectural reconciliation, not mechanical — see below), collapsed
  to `main`. 1483/1483 tests passing (2 known stock-divergence XFAILs).
- **mtld3d** (`/Users/gc/Developer/mtld3d`, origin `g-cqd/mtld3d`): synced with `athei/mtld3d`,
  collapsed to `main`, full `make check` + full e2e suite green (1263/1277 and 1261/1275 on both
  architectures, 0 failures) — found and fixed a real e2e-runner bug (WOW64 `start.exe` relaunch
  command-line-length budgeting) along the way. **Local env note**: `make check` needs
  `WINE_SDK` pointed at a real wine-build CrossOver release
  (`/Volumes/ExT2/GameHub/toolchains/wine-sdk-cx-26.3.0-5/wine`), not `/usr/local` — not yet
  changed in your shell profile, you may want to do that.
- **dxmt** (`/Users/gc/Developer/dxmt` — new canonical location, origin `g-cqd/dxmt`, upstream
  `3Shain/dxmt`): fresh un-shallow clone, merged 266 upstream commits, 7-file conflict
  hand-resolved, collapsed to `main`, build passes (154/97 targets depending on which check).
  The old `/Volumes/ExT2/GameHub/src/dxmt-v0.80` shallow clone and the `work/dxmt-{rtv,tess}`
  worktrees were deleted (confirmed fully merged first).
- **nfs-macos** (`/Users/gc/Developer/nfs-macos`, origin `g-cqd/nfs-macos`): rescued real
  uncommitted work from an orphaned worktree (`wt-hub-a`) — 11-item Game Hub model amendment,
  36 new tests — merged into `main`. 16/16 `swift test` passing.
- **GameHub** (new repo `/Users/gc/Developer/GameHub`, origin `g-cqd/GameHub`, private): created
  from the genuinely-GameHub-owned scripts/docs on ExT2 (`bin/`, `docs/`, `STATUS-*.md`, loose
  `work/` automation scripts). Pushed, single `main` branch.
- **wine-arm64** (new repo `/Users/gc/Developer/wine-arm64`, origin `g-cqd/wine-arm64`, private):
  moved off ExT2 (15 unique commits, arm64 bring-up work), pushed, single `main` branch. *This
  was a judgment call by the dispatched agent (plan didn't name a destination) — you confirmed
  it's fine.*
- **ExT2 cleanup**: ~21G of pure build caches deleted (cargo-target, wine-arm64/build, etc.);
  the 24G `/tmp` EA-token-dump quarantine deleted (you confirmed). `/Volumes/ExT2/GameHub/src/`
  now only contains `wine` (by design — stays as runtime-adjacent source per the plan).
  **Still open, deliberately left alone, not yet actioned**: ~65G more of "needs-confirmation"
  cleanup (superseded Wine runtime variants ~12.4G, more `/tmp` scratch ~5.5G, `GameHub/Backups/`
  1.6G, six generated log/dump files left in `GameHub/docs/`) — see
  `/Users/gc/.claude/plans/lazy-prancing-bachman.md` section 8 for the exact list.
- **Operational security (EAAC-side)**: `/tmp` token dumps relocated+locked down,
  `start-ea.sh` hardened (umask, signature check — `osslsigncode` not installed, so the check
  currently always logs "unverified"), stale processes cleaned. **Deferred, NOT done**: S1/S3
  from the EAAC review (dosdevices scope narrowing, code signing/entitlements overhaul) — a
  remediation plan exists at `/Users/gc/Desktop/EAAC-REMEDIATION-S1-S3.md` but has known bugs in
  it, **do not run it as written**.
- **rosetta3 conventions**: loosened per your request — x86-64 test/benchmark execution is now
  routine (timeout-wrapped, scheduler-bounded) instead of needing a one-off ask each time.
  The reverse-engineering policy (`REVERSE-ENGINEERING.md`, here and in rosetta3) explicitly
  allows and encourages analyzing Apple's real Rosetta 2 binary, to any depth, by any means.
- **rosetta3 README + CI**: fixed (README overstated how unfinished the project was; CI added).
- **rosetta3 shared-JIT-arena-full crash**: fixed, tested, committed.
- **rosetta3 benchmark**: real, rigorous, replicable comparison of stock Rosetta 2 vs.
  Rosetta2+x87sidecar vs. rosetta3 written to
  `docs/benchmarks-rosetta3-vs-rosetta2-vs-x87sidecar-20261014.md`. Headline: x87sidecar was
  1.2–1.9x faster than rosetta3 on x87 workloads at the time — **this number is now superseded**,
  see the roadmap below, which found the gap is mostly a few fixable bugs, not a fundamental gap.
- **rosetta3 roadmap**: `/Users/gc/Developer/rosetta3/docs/ROADMAP-state-of-the-art-20261014.md`
  — thorough, evidence-based, with a prioritized P0–P1 list and 22 new blind spots found. Read
  this before doing any more rosetta3 work; it's the reference the in-flight tasks below are
  executing against.

## IN FLIGHT when the user had to step away — resume these first

All in `/Users/gc/Developer/rosetta3` unless noted. **Resume by sending each agent ID a message
asking for its final report** — several were mid-wait on long `cargo test --workspace` runs on a
heavily contested shared machine (expect 30–45 min runs).

| Agent ID | Task | Last known state |
|---|---|---|
| `aee15b30119a7f254` | Merge `fix/ci-failures` branch to `main`, confirm real GitHub Actions CI goes green | Completed per ListAgents, **final report not yet retrieved** — resume and get the report. This was the CI-fix work: 4 commits (weak-link `r3-wow64` fix, `r3-x87ref` clippy/fmt, drive-by fixes), locally verified 1937/0 failed. Should have merged to main and checked real CI by now. |
| `aff4c4f5ade9ca026` | Fix `r3-coverage`/`r3-ml-fuzz` clippy debt, pushed to branch `fix/r3-coverage-clippy-debt` (worktree `/Users/gc/Developer/rosetta3-coverage-clippy`) | Completed per ListAgents, **final report not yet retrieved**. 3 commits already landed on that branch (mechanical fixes + 2 judgment calls: an `if_same_then_else` in `evidence.rs` and an unreachable match arm in `tests/common/mod.rs`), independently re-verified clean. Was waiting on one last full-workspace test run. **Still needs merging to `main`** (not done yet, per the no-topic-branches policy) once confirmed green. |
| `ab7bdc15bfcb56a43` | Full x87 control-word coverage — remove the "interpret forever" cliff generally (fldpi class, `fild` 64-bit, precision-mode, sticky control-word) per roadmap P0-2. "Cover everything" per your explicit answer to question 3. | Completed per ListAgents, **final report not yet retrieved**. This is correctness-critical core-translator work (opus-led). Get the full report before trusting anything here — confirm what shipped vs. what's partial. |
| `ad28c70e65c9b2ec2` | Build persistent cache stage 1 (background pre-translation) + stage 2 (on-disk cache, hash-keyed, untrusted-by-default) + stage 3 (JS-engine-style tiered JIT) — **you explicitly overruled the roadmap's "not worth it" recommendation and asked for all three stages anyway, with full awareness.** | **Still running** (has live children: `a8fcf8989f581929e`, `a84fd2fcd6e0de44e`, `a8d2ae64a9da4cec7` as of last check). This is the single largest, highest-risk piece of work outstanding — correctness- and security-critical new surface. Resume and check how far it got; it was instructed to fully land each stage before starting the next and report precisely which stages are done/tested/pushed vs not, rather than claim completion prematurely. |
| `a0b156541ccf65d47` | Original (now superseded) fldpi-specific fix + cache design doc | Completed earlier. Its narrow fldpi fix may conflict/overlap with `ab7bdc15bfcb56a43`'s broader fix above — **check for duplicate/conflicting commits on `main` touching `r3-lower/src/x87.rs`** when resuming. |

### Blocked on you (not an agent problem — needs your action before these can proceed)

1. **TSO entitlement test** (`aae83e4bb9c2a26fc`, completed, reported) — blocked on a
   certificate/provisioning-profile mismatch for App ID `NP94WB3P75.fr.gcqd.winehost`. Need
   either: a new provisioning profile for that App ID bound to one of the two Developer ID certs
   already in this Mac's keychain (serials `025CB64369347C61` or `7208E67A957B21AC`), **or** the
   `.p12` for the cert the current profile expects (serial `7853D5F3BF2331CE`). Once provided,
   the litmus test (Dekker/store-buffer, native arm64, no x86 involved) runs immediately — no
   further investigation needed.
2. **NX enforcement for attached/Wine-hosted windows** — same underlying cert blocker as #1
   above (this was discovered first, during the original NX investigation). Same fix unblocks
   both.
3. **Hardware budget for rosetta3** (question 4) — you said "I don't have that yet." No action
   needed now; the roadmap just flagged that a real x86 oracle machine, a quiet benchmark host,
   and a newer-chip runner would help later testing.

## Decisions already made today (don't re-litigate these)

- **EAAC**: leave the existing anti-cheat-identity-masking code as-is (already committed,
  predates today), but don't extend it further; label it honestly in docs (done).
- **Don't fetch `eaanticheat.sys`** from EA's CDN — refused; that would manufacture a false
  "protection active" signal for online play, not implement real behavior.
- **x87sidecar merge conflict** (register-allocation architecture clash between your Crysis-3 fix
  and upstream's `declined_block` design): resolved by re-porting your fix onto upstream's new
  architecture, plus two more real bugs found and fixed along the way (an alloc-failure
  write-back race, an FTZ/DAZ-unsafe fusion). Fully landed, 1483/1483 passing.
- **mtld3d test literals**: 8 missing struct fields filled with `..Default::default()` after
  confirming by code reading that none of the 8 sites actually read the new fields — not a blind
  guess.
- **24G EA token dump quarantine**: delete now (done) — you confirmed explicitly.
- **Branch policy**: no more `development`/topic branches anywhere — collapse everything to
  `main`, commit directly to `main` going forward. This is why several in-flight agents above
  were told to push to `main` directly rather than open PRs.
- **Cache/JIT scope**: build all 3 stages (not just stage 1 as the roadmap recommended) —
  explicit, informed override by you.
- **x87 control-word coverage**: "cover everything," not a targeted subset.

## Where to actually start when you're back

1. Resume `aee15b30119a7f254`, `aff4c4f5ade9ca026`, `ab7bdc15bfcb56a43` first — they're marked
   completed but I never got to read their final reports before you had to go.
2. Check `ad28c70e65c9b2ec2`'s progress (still running) — this is the biggest open item.
3. Reconcile `a0b156541ccf65d47` (old fldpi fix) vs `ab7bdc15bfcb56a43` (new broader fix) for any
   duplicate/conflicting commits on rosetta3's `main`.
4. Once rosetta3 settles down, run the deferred branch-consolidation check on rosetta3 itself
   (it was skipped earlier because these very tasks were creating branches/uncommitted files —
   check `git branch -a` and `git status` there once everything above has landed).
5. Decide on the two leftover wine branches, the WINE_SDK shell-profile update, and whichever of
   the ~65G "needs-confirmation" disk cleanup buckets you want actioned.
6. If you want to unblock the TSO/NX entitlement work, provide the provisioning profile or `.p12`
   described above.

Everything that reached `main` on any repo today passed its own test suite before landing — no
broken state was deliberately left on any `main` branch, only on topic/worktree branches that are
either merged, tagged-and-archived, or explicitly flagged above as still open.
