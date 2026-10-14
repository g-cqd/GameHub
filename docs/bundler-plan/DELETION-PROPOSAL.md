# Deletion proposal (staged; nothing has been deleted)

Every command below is for the **owner to run after approval**, in order, and only after the bundler (BUNDLER-DESIGN.md phases 1-8) holds the
knowledge. Classes and evidence: REPO-INVENTORY.md. Prefixes: `G=/Users/gc/Developer/Games`, `D=/Users/gc/Developer`,
`BK=/Volumes/ExT2/Backups/wine-games-20261009` on `mbp23.local` (remote shell is fish: wrap remote scripts in `ssh mbp23.local '/bin/bash -s' <<'EOF' … EOF`).
Disk today: 12 GiB free (below the 15 GiB floor): stage 0 uses `/tmp` only for small archives and removes them after the remote checksum matches.

## Never delete (any stage)
- Other sessions: `D/rosetta3*` (incl. the worktree `D/rosetta3-wt/macos-app-host4k`), `D/claudetalk`, `D/skills`, `D/g-cqd*`, `D/xcode-themes`, `D/exfit`, `D/gpsmerge`,
  `G/bump-tools`, `G/fc2-dev/{rosetta3, r3-ml-data, rosetta-analysis}`, `G/f2`, `G/Far Cry 2 - Authentic`, `~/Documents/rosetta3-backups`, `/private/tmp/{agora,arcleak,dolly,atelier,deadwood,claudetalk,analyzerkit,rosetta3}*`.
- Files of workers running now: `G/bf4-run` (BF3/BF4 workers), `/private/tmp/bf4*.sh`, `bf3sp.pid`, `gdv-bundle.log`, mbp23 `Bundles/Battlefield3-Tuned-*`.
- The bundler's home `G/nfs-release/macos-app` and its `inputs/` (until the bundler has its own input cache); `D/mtld3d`, `D/x87sidecar` (live development clones).
- Preservation copies: `~/Documents/NFS-backups`, `~/Documents/push-backups-20261008`, `D/_archive`, mbp23 `Backups/`, `Bundles/`.
- `G/Store/*/MOVED.txt`, `G/Store/README.md`, the symlinks `G/{CoD4,FarCry2,NFSMW,NFS2015-game,Morrowind}` and `~/Games`.
- Owner data without a verified backup and explicit approval: game data, EA/Battlelog/Steam sessions (`~/Library/Application Support/NFS2015Mac`,
  `G/bf4-run/prefix-bf4`, `G/bf4-run/browser-profile`, `G/NFSMW-tools/ea-app-lab/Prefix`), saves (`~/Library/Application Support/NFSMW/Data/Saves`,
  `RetainedSaves`, `~/Documents/My Games`, `~/Documents/Need For Speed`), `~/Downloads/winehost_developer_id*.provisionprofile`, `~/Documents/Torrents`, `/Applications/Wine Staging.app`.
- Any local-only commit that stage 0 has not preserved and verified.
- Anything a recipe still reads as an input (checked in `APP/Packaging/Recipes/*.json`): `G/wine-rebuild/runtime/wine-0010`, `G/wine-rebuild/src/wine`,
  `G/CoD4-tools/wine`, `G/nfs-release/inputs/*`, the Store symlinks, `G/wine-rebuild/ab/` (cited by `runtime-inputs.json:16`).
  Note: `cod4.json:14-18` and `farcry2-bundled.json:17-21` read `{games}/release-build/…` and `{games}/tools-integrate/…`, which **no longer exist**
  (removed in the 2026-10-07 cleanup): those two recipes cannot be rebuilt today until their inputs are re-created from the pins.

## Stage 0: preservation (nothing deleted). ~0.5 day

**0.1 Local-only git work → git bundles on mbp23** (private; nothing published). Bundle only what GitHub lacks:
```bash
mkdir -p /tmp/bk && cd /tmp/bk
git -C $G/nfs-release/macos-app       bundle create nfs-release-bf4-schema.bundle bf4-recipe-schema ^9b6e8ed
git -C $G/FarCry2-tools/macos-app     bundle create fc2-arm64-route.bundle integration-20261002 host-4k ^f4c3273
git -C $G/wine-rebuild/src/wine       bundle create wine-wx-experiment.bundle wx-experiment ^c2afb95
git -C $G/NFSMW-tools/public-sources/mtld3d       bundle create nfsmw-mtld3d.bundle nfsmw-macos --not --remotes
git -C $G/NFSMW-tools/public-sources/mtld3d-clean bundle create nfsmw-mtld3d-clean.bundle nfsmw-macos nfsmw-upstream-update ^1b0bf1f
git -C $G/NFSMW-tools/public-sources/x87sidecar   bundle create nfsmw-x87sidecar.bundle nfsmw-macos ^4048fcf
git -C $G/NFSMW-tools/public-sources/wine         bundle create wine-crash-context.bundle crash-context crash-context-2 ^1a7b0c766
git -C $D/mtld3d                      bundle create mtld3d-test-fix-d3d8.bundle test-fix-d3d8 ^7d108a4
git -C $D/upstream-prep/x87sidecar    bundle create x87sidecar-pr.bundle --branches='pr/*' ^74c7dfe
git -C $D/upstream-prep/mtld3d/repo   bundle create mtld3d-pr.bundle --branches='pr/*' fix/d3d8-heldpages ^e0ff32a
git -C $D/upstream-prep/swapchain/mtld3d bundle create mtld3d-swapchain.bundle fix/swapchain-upstream ^e0ff32a
git -C $D/wine-arm64                  bundle create wine-arm64-outer.bundle --all            # no remote: whole repo (small)
S=$D/wine-arm64/src; BASE=$(git -C $S merge-base --octopus $(git -C $S for-each-ref --format='%(objectname)' refs/heads))
git -C $S                             bundle create wine-arm64-src.bundle --branches ^$BASE   # all 6 branches minus the shared upstream history
cp ~/Documents/push-backups-20261008/*.bundle ~/Documents/NFS-backups/*.bundle .
for b in *.bundle; do git bundle list-heads "$b" >/dev/null || echo "BAD $b"; done
shasum -a 256 *.bundle > SHA256SUMS
```
(If a `^base` is not an ancestor, `git bundle create` still succeeds but includes more; check each bundle's size stays small. Alternatively the owner may
push these as branches to the g-cqd forks — they are public, so bundles are the default.)
Also save the two uncommitted diffs: `git -C $G/NFSMW-tools/macos-app diff > /tmp/bk/nfsmw-macos-app-uncommitted.patch`;
`git -C $G/NFSMW-tools/diagnostics/widescreen-reference diff > /tmp/bk/widescreen-reference-Resolution.patch`.

**0.2 Unique non-git work → tarball** (scan for secrets first; exclude prefixes and browser profiles):
```bash
cd $G && grep -rIlE 'AuthCode|access_token|refresh_token|logintoken=|Cookie:' bf4-run/bf3 bf4-run/logs bf4-run/gdf-test bf4-tools ea-helper wine-rebuild/logs ron-tools/logs ron-tools/full/logs 2>/dev/null   # expect none; redact before archiving if any
tar -czf /tmp/bk/knowledge-20261009.tgz \
  bf4-run/{README-OWNER.md,env.sh,run-ea.sh,bf3,gdf-test,bundle-tools,logs} bf4-tools ea-helper \
  wine-rebuild/{HANDOFF.md,logs,local,ab,scratch,scratch-dsound,tests-wx} \
  ron-tools/{*.md,*.sh,*.py,*.json,diag,perf,logs} ron-tools/full/{*.md,*.sh,logs,helper,dsound} \
  NFSMW-tools/{*.md,*.reg,*.ixx,*.json,*.conf} NFSMW-tools/ea-app-lab/{*.md,Logs,Diagnostics} \
  CoD4-tools/{README.md,*.command,benchmark,diagnostics,performance-*} Morrowind-tools/{README.md,*.command,diagnostics,renderer-snapshots} \
  fc2-dev/{patches,build.sh,build-*.log} pe-inventory.json \
  -C $D _archive games.md mtld3d-x87.md \
  -C /Users/gc Desktop/Games-inventory-20261008.md Desktop/mtld3d-state-report-20261002.md Desktop/x87sidecar-state-report-20261002.md Desktop/mtld3d-x87-developer-handoff-20260927.md \
  -C /private/tmp dxmtfx nfsrel
tar -czf /tmp/bk/wine-source-archives-0010-0011.tgz -C $G/wine-rebuild/source-archive wine-nfs2015-source-0010.tar.gz wine-nfs2015-source-0011.tar.gz
(cd /tmp/bk && shasum -a 256 *.tgz *.patch >> SHA256SUMS)
```
(`/private/tmp/x87*` belong possibly to the rosetta3 session: ask that session before including them.) Expected size: < 300 MB.

**0.3 Transfer and verify:**
```bash
ssh mbp23.local '/bin/bash -s' <<'EOF'
mkdir -p /Volumes/ExT2/Backups/wine-games-20261009 && df -h /Volumes/ExT2
EOF
rsync -a /tmp/bk/ mbp23.local:/Volumes/ExT2/Backups/wine-games-20261009/
ssh mbp23.local '/bin/bash -s' <<'EOF'
cd /Volumes/ExT2/Backups/wine-games-20261009 && shasum -a 256 -c SHA256SUMS
EOF
# only after "OK" for every line:
rm -rf /tmp/bk
```
**0.4 Record runtime pins:** add sha256 of `wine-nfs2015-source-0010.tar.gz` to `runtime-inputs.json`/`nfs2015.json` (`runtimeSource`), and commit the
`wine-rebuild/logs/runtime-000N-manifest-sha256.txt` files into the bundler repo (private part). Verify each runtime against its manifest:
`cd $G/wine-rebuild/runtime/wine-0010 && shasum -a 256 -c ../../logs/runtime-0010-manifest-sha256.txt | grep -vc ': OK$'` (expect 0; check the manifest's path base first).
**0.5 BF3 bundle on mbp23:** after the bf3-bundle worker finishes, run on mbp23 `cd /Volumes/ExT2/Bundles/Battlefield3-Tuned-20261009 && shasum -a 256 -c MANIFEST.sha256 | grep -vc ': OK$'` (expect 0).
**0.6 Owner sessions/game data (class D) — only if the owner wants copies before stage 3** (sizes logical; ExT2 has 381 GiB free):
`rsync -a "$G/bf4-run/prefix-bf4" "$G/bf4-run/browser-profile" mbp23.local:/Volumes/ExT2/Backups/wine-games-20261009/D/` (23.4 GiB), likewise
`$G/NFSMW-tools/ea-app-lab/Prefix` (15.2), `~/Library/Application Support/NFS2015Mac` (17.2; quit the app first), `~/Library/Application Support/NFSMW/Data/Saves` + `RetainedSaves`,
`$G/Morrowind-tools/prefix` (1.4), `$G/CoD4-tools/prefix` (1.3); verify with `rsync -an --checksum --itemize-changes` (expect no output).
These copies contain the owner's EA/Battlelog sessions: keep them on the owner's own disk only.

## Stage 1: class A (fully redundant). Logical ≈ 3.0 GiB, expected real ≈ 2.7 GiB (few clones here)

Before each item: re-run its proof (shown) and stop if it fails.

| Item | Proof to re-run | Command | GiB |
|---|---|---|---|
| `$G/publish/nfs-macos` | `git -C … status --porcelain \| wc -l` = 0; `git -C … rev-parse main` = GH `main` (`gh api repos/g-cqd/nfs-macos/branches/main -q .commit.sha`); FC2 bundle from 0.1 verified | `rm -rf "$G/publish/nfs-macos"` | 0.83 |
| `$G/nfs-firstrun` | `git -C …/macos-app merge-base --is-ancestor 7b1bd8f <GH main>` in a GH clone; NFS-backups bundle present | `rm -rf "$G/nfs-firstrun"` | 0.01 |
| `$G/wine-rebuild/pkg`, `wine-build`, `ab/sidecar/src*` | clean, heads on their remotes | `rm -rf "$G/wine-rebuild/pkg" "$G/wine-rebuild/wine-build" "$G/wine-rebuild/ab/sidecar/src" "$G/wine-rebuild/ab/sidecar/src-12afdc2"` | 0.01 |
| ~~`$G/wine-rebuild/src`~~ **moved out of stage 1**: `nfs2015.json:58` uses `{games}/wine-rebuild/src/wine` as `runtimeSourceTree` (and `:57` uses `runtime/wine-0010`); delete only after the recipe points at a pinned source cache/clone of g-cqd/wine and the wx-experiment bundle is verified | — | — | (0.39) |
| `$G/NFSMW-tools/macos-app` | patch from 0.1 on mbp23; `git log --branches --not --remotes` shas all found on GH | `rm -rf "$G/NFSMW-tools/macos-app"` | 0.53 |
| `$G/NFSMW-tools/public-sources` | the four bundles from 0.1 verified | `rm -rf "$G/NFSMW-tools/public-sources"` | 1.0 |
| `$G/NFSMW-tools/wine-cursor-src` | blobs equal g-cqd/wine `nfsmw-macos` (Sonnet check) | `rm -rf "$G/NFSMW-tools/wine-cursor-src"` | 0.32 |
| `$G/NFSMW-tools/diagnostics/{unlimiter-stock-reference,extra-options-src,save-editor-src,widescreen-reference}` | upstream clones; Resolution.ixx patch saved | `rm -rf` those four | 0.1 |
| `$G/NFSMW-tools/{mtld3d-v0.11.0,d9vk-macOS-async-v1.10.3-20250511}` | upstream releases | `rm -rf` both | 0.02 |
| `$G/mtld3d-test/dxmt-src` | detached at v0.80, clean | `rm -rf "$G/mtld3d-test/dxmt-src"` | 0.01 |
| `/private/tmp/mtld3d-lic` | HEAD 7d108a4 = GH development; only `cargohome/` untracked | `rm -rf /private/tmp/mtld3d-lic` | 0.13 |
| `$G/pe-inventory.json` | `cmp` with `$G/ron-tools/pe-inventory.json` | `rm "$G/pe-inventory.json"` | 0 |
| `$D/scripts`, `$D/g-cqd-publish` | empty | `rmdir "$D/scripts" "$D/g-cqd-publish"` | 0 |
| `/private/tmp` logs of this effort (`nfs-*`, `mtld3d-*.log/json`, `x87test.log`, `perf-*dsound*`, `ron-*.sha`, `bf3.sample`, `wine_*.sample.txt`) | not used by running workers (`lsof +D` empty) | `rm` per name | 0.03 |

## Stage 2: class B (regenerable, costly). Logical ≈ 45-50 GiB, expected real ≈ 30-45 GiB (runtimes and prefixes may be clones)

Only after the bundler builds every game from pinned inputs and its byte-identical regression passes.

| Item | Rebuild cost | Command | GiB |
|---|---|---|---|
| `$G/wine-rebuild/runtime/{wine,wine-0005,…,wine-0009}` (keep `wine-0010`, `wine-0011`) | ~1 h each from the GH tags; manifests on mbp23 | `rm -rf` the six dirs | 8.4 (real: 1.4-8.4) |
| `$G/wine-rebuild/build` | ~1 h (configure 10 min, make ~50 min) | `rm -rf` | 5.35 |
| `$G/wine-rebuild/scratch-smc` | ~1 h from the wx-experiment bundle | `rm -rf` | 1.4 |
| `$G/wine-rebuild/{toolchains,deps,downloads,cargo-home,sysroot}`, `source-archive` except -0010/-0011 | ~30 min downloads; `git archive` | `rm -rf` | 1.0 |
| `$G/NFSMW-tools/build-env` | ~30 min | `rm -rf` | 2.7 |
| `$G/NFSMW-tools/diagnostics/nfs2015-context-{wine,build,src}` | ~1 h; compare src with GH `crash-context*` first | `rm -rf` | 1.7 |
| `$G/NFSMW-tools/ea-app-lab/Wine` | copy of a pinned runtime | `rm -rf` | 1.2 |
| `$G/mtld3d-test` (rest) | ~30-60 min (rustup, wine-sdk) | `rm -rf "$G/mtld3d-test"` | 4.0 |
| `$G/CoD4-tools/wine`, `$G/Morrowind-tools/wine` | the bundler ships pinned runtimes; play scripts must be replaced first | `rm -rf` | 2.4 |
| `$G/ron-tools/full/runtime-scratch` | after the steamwebhelper rule diff is captured | `rm -rf` | 1.4 |
| `$G/ron-tools/{prefix,full/prefix-full,full/prefix-dsound}` | ~30 min each from Store + recipe; first check `ls drive_c/Program\ Files\ \(x86\)/Steam` for a Steam login (then class D) | `rm -rf` | 15.1 |
| `$D/wine-arm64/{build,install}` | ~1-2 h; outer + src bundles on mbp23 | `rm -rf` | 6.9 |
| `$G/bf4-run/downloads` | minutes (sha256 in SOURCES.md) | `rm -rf` | 0.1 |

## Stage 3: class D (explicit approval per item; only with a verified copy from 0.6 or a deliberate decision to re-download/re-sign-in)

| Item | Other copies | Cost if lost | GiB |
|---|---|---|---|
| `$G/bf4-run/prefix-bf4` (+ `browser-profile`) | cleaned BF3 bundle on mbp23 (no session); 0.6 copy | EA sign-in + an activation; ~20 GB re-download | 23.4 (real: ~20) |
| `$G/NFSMW-tools/ea-app-lab/Prefix` | NFS data in `Store/nfs-2015`, NFS2015Mac, mbp23 NFS app | sign-in + activation | 15.2 |
| `$G/Store/nfs-2015` | NFS2015Mac prefix, ea-app-lab, mbp23 NFS app | EA re-download; recipes use `{store}` | 13.6 (keep one plain copy somewhere) |
| `$G/Store/rise-of-nations` | mbp23 Steam library (SHA-256 verified source) | copy back | 2.6 |
| `$G/Morrowind-tools/prefix` | mbp23 `Backups/Store-20261008/morrowind` | restore | 1.4 |
| `$G/CoD4-tools/prefix` | game on mbp23; player config only here | config | 1.3 |
| `~/Library/Application Support/NFSMW/Data/Versions` | the app re-creates versions | minutes | 2.8 (keep Saves) |
| `~/.wine` | none (default prefix, purpose unknown) | none known | 1.0 |
| `~/Library/Application Support/NFS2015Mac` | **do not delete**: the player's live install + EA session | — | 17.2 |

## Estimated space

| Stage | Logical | Expected real |
|---|---|---|
| 1 (A) | ≈ 3.0 GiB | ≈ 2.7 GiB |
| 2 (B) | ≈ 50 GiB | ≈ 30-45 GiB |
| 3 (D, if all approved except NFS2015Mac) | ≈ 61 GiB | ≈ 55 GiB |
Real figures are estimates: APFS clone sharing was not measured; deleting one side of a clone frees only the blocks that differ.
