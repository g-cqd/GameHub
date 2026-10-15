# x87sidecar: scratch-FPR pool fix (Crysis 3 alloc_free_fpr abort, 2026-10-11 16:27:12)

- Binary: `x87sidecar`, the flat build used in cooperative mode (same kind as hub-0-helpers/x87sidecar)
- sha256: `0cc5ea16e3547942666f8133cdd3e2abd82e3311ddbd3b03d1a3170072247a42` (also in `x87sidecar.sha256`)
- Mach-O UUID: 08A6C45C-0CD8-3A0A-BE76-8AE8A4160549
- Source: g-cqd/x87sidecar commit `db3cb92d82fb330b4646058dbbbe84fd8a7537a7`
  (parent b947853, `development` at build time; detached commit, not pushed)
- Build: CMake Release (asserts kept, as the repo configures), Apple clang, 2026-10-11.
  The repo build is ad-hoc signed (sha256 223813edb41823e2f8af879cc3ba79a098c2cdcfad5adcf117df6aa6b6a6de90).
  This copy is re-signed like the pinned helper: identifier `x87sidecar`,
  Developer ID Application NP94WB3P75, hardened runtime, no secure timestamp.
- Replaces: `Runtimes/hub-0-helpers/x87sidecar` (sha256 43ab085a…, UUID 8B9FD112, the binary named in the crash report)

## What it fixes

Stock Rosetta keeps recent scalar SSE results (cvtsd2ss, sqrtsd, … written to a fresh xmm) in the
V16–V31 temporaries. That leaves the sidecar anywhere from 8 down to 0 scratch FPRs. The
single-instruction x87 translators assumed 8: inline FSINCOS/FPTAN/FYL2X/FYL2XP1 need 8, FSIN/FCOS
need 7 and FPATAN/F2XM1 need 6. They aborted on alloc_free_fpr's assert, which killed the game.

Now:

- An x87 instruction that does not fit is translated by Rosetta's own x87 path, and the rest of its run stays inline.
- Any other scratch-register exhaustion hands the request to Rosetta instead of aborting.

Each fallback logs one rate-limited line:

    [rosettax87] x87 fsincos needs 8 scratch FPRs, stock left 5 free (mask=f8000000); stock translates it (#n)

## Verified

- `scripts/run_tests.sh`: 1070 passed, 0 failed, 2 known stock divergences, out of 1072.
  Baseline (`development` b947853, same script): 1059 / 1061 with the same 2 divergences. The +11 is the new test in 11 phases.
- `tests/test_fpr_pool_pressure`: the pinned hub-0-helpers binary aborts with the Crysis assertion under `--cooperative`;
  this binary passes 45/45 checks under `--cooperative`.
- Not verified: Crysis 3 itself under Wine (not run).

## Install (not done here)

    shasum -a 256 -c x87sidecar.sha256        # in this directory
    mkdir -p /Volumes/ExT2/GameHub/Runtimes/hub-0-helpers-<tag>
    /bin/cp -c x87sidecar /Volumes/ExT2/GameHub/Runtimes/hub-0-helpers-<tag>/x87sidecar

Then point `ROSETTA_X87_PATH` in `/Volumes/ExT2/GameHub/bin/start-ea.sh` at the new path.
