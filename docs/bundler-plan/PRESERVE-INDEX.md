# PRESERVE-INDEX (Stage 0 preservation, 2026-10-09)

Location on mbp23: `/Volumes/ExT2/Backups/Preserve-20261009/` (`git/`, `files/`, `patches/`, `SHA256SUMS`). Nothing was deleted, moved, modified or pushed on this Mac; everything below is a verified COPY.
Verify any time: `cd /Volumes/ExT2/Backups/Preserve-20261009 && shasum -a 256 -c SHA256SUMS` (27 entries, all OK when written).

## 1. Git bundles (`git/`)
Full-history bundles (`git bundle create - --all`, streamed). Restore: `git clone --mirror git/<name>.bundle <dir>` then `git -C <dir> branch -a`.

| bundle | source repo | bytes | sha256 | HEAD at bundling | notes |
|---|---|---|---|---|---|
| `nfs-release-macos-app.bundle` | `D/Games/nfs-release/macos-app` | 1419504 | `27f7e94386a18dfb…` | bf4-recipe-schema:e7e7a1b | contains bf4-recipe-schema b028857/e7e7a1b (not on GitHub), nfs-firstrun, nfs-release-rebuilt |
| `farcry2-tools-macos-app.bundle` | `D/Games/FarCry2-tools/macos-app` | 1354801 | `e54075e79a2e35c0…` | integration-20261002:cfd2de9 | contains the 5 local-only arm64-route commits (cfd2de9 6832249 9f3bbd0 76267b8 a8f5da9); worktree rosetta3-wt/macos-app-host4k belongs to another session |
| `nfsmw-tools-macos-app.bundle` | `D/Games/NFSMW-tools/macos-app` | 1171372 | `97802301b48ba2f3…` | refresh-runtimes-cod4-bundle:71082c8 | dirty tree saved separately in patches/ |
| `wine-rebuild-src-wine.bundle` | `D/Games/wine-rebuild/src/wine` | 53010282 | `74fe400c9940fd69…` | wx-0011:412fcd8 | SHALLOW source repo (boundary 1a7b0c766 = athei cx-26-patched base): restore INTO nfsmw-ps-wine (see section 4). Holds wx-0008..0011 and local-only wx-experiment 44974bf |
| `nfsmw-ps-mtld3d-clean.bundle` | `D/Games/NFSMW-tools/public-sources/mtld3d-clean` | 8516959 | `dfc9b6e5cb7ba9ae…` | nfsmw-upstream-update:2513602 | nfsmw-macos / nfsmw-upstream-update (no GH branch) |
| `nfsmw-ps-x87sidecar.bundle` | `D/Games/NFSMW-tools/public-sources/x87sidecar` | 1834465 | `aaa32c9a5bb1c101…` | nfsmw-macos:f979c23 | nfsmw-macos f979c23 (no GH branch) |
| `nfsmw-ps-wine.bundle` | `D/Games/NFSMW-tools/public-sources/wine` | 559388087 | `5b94c9e9a1eb498b…` | nfs2015-runtime-0011:71133b59a00 | full g-cqd/wine history incl. crash-context ed16a3c9119 and crash-context-2 0867f210ec9 (no GH branch); base for restoring the two shallow wine bundles |
| `mtld3d.bundle` | `D/mtld3d` | 10460595 | `555f7d9c3af7a1da…` | development:7d108a4 | includes test-fix-d3d8 5c91c3d (local-only) and the archive/fc2 branches |
| `x87sidecar.bundle` | `D/x87sidecar` | 2308439 | `a566ddf0a4e5fd3a…` | development:b947853 | includes archive/fc2-perf branches |
| `upstream-prep-x87sidecar.bundle` | `D/upstream-prep/x87sidecar` | 2405648 | `24c3731aa6e263c6…` | HEAD:d1a71f8 | 6 pr/* branches (local-only PR preparation) |
| `upstream-prep-mtld3d-repo.bundle` | `D/upstream-prep/mtld3d/repo` | 13416762 | `16ce6cb057e303e1…` | pr/ff-ternary-texture-ops:21c7975 | pr/* branches and fix/d3d8-heldpages |
| `upstream-prep-swapchain-mtld3d.bundle` | `D/upstream-prep/swapchain/mtld3d` | 14027608 | `b32fc50e707a81ef…` | fix/swapchain-upstream:be03808 | fix/swapchain-upstream be03808 (+bdd87b1) |
| `wine-arm64-outer.bundle` | `D/wine-arm64` | 81910 | `85ebf476250b49b2…` | main:0bf2d41 | no remote existed: this is the only copy of the outer repo (docs, patches, scripts) |
| `wine-arm64-src.bundle` | `D/wine-arm64/src` | 53180391 | `632ded70a60e3a63…` | arm64-macos-onto-dev:89a212b | SHALLOW (boundary 1a7b0c766): restore INTO nfsmw-ps-wine. 6 branches incl. arm64-macos a3433d0, arm64-macos-rebased b92f4ed, wow64-cpu cf90b43, wow64-cpu-old f3ebe29 (not on GH) |
| `nfsmw-widescreen-reference.bundle` | `D/Games/NFSMW-tools/diagnostics/widescreen-reference` | 195354559 | `05b58346550e8e5b…` | master:e9550ff | third-party mod source clone (upstream available); dirty diff in patches/ |
| `nfsmw-ps-mtld3d-localonly.bundle` | `D/Games/NFSMW-tools/public-sources/mtld3d` | 39916 | `72f4580c47b5e4d6…` | nfsmw-macos ca187f6 | 4 local-only commits on top of GH main 58ed7d9 (the clone is partial: a full bundle was impossible). NEEDS prerequisite 58ed7d91ba83948bd9ec1a21ea7e435d11377435 (upstream athei/mtld3d main). Same content as `patches/nfsmw-ps-mtld3d-4commits.patch` (git am) |

Full SHA-256 values: `SHA256SUMS` (same dir).

## 2. Files (`files/`)
| file | contents | bytes | sha256 |
|---|---|---|---|
| `knowledge-20261009.tar` | 7,482 entries (tar listing count equals the source count): bf4-run scripts/NOTES/FINDINGS/interposer+shellwin sources/gdf-test/bundle-tools/logs; bf4-tools; ea-helper; bundler-plan (all docs + raw); wine-rebuild HANDOFF.md, logs (runtime manifests), local, ab harness, scratch, scratch-dsound, tests-wx; ron-tools docs/tools/diag/perf/logs and full/{logs,helper,dsound}; NFSMW-tools loose docs + ea-app-lab SETUP/Logs/Diagnostics; CoD4-tools README/commands/benchmark/diagnostics; Morrowind-tools README/commands/diagnostics/renderer-snapshots; fc2-dev patches/build; pe-inventory.json; D/_archive, games.md, mtld3d-x87.md; Desktop reports; ~/Documents/NFS-backups (wine-patches 0001-0011, bundles, evidence, deleted log) and push-backups-20261008; The_Board (all .jsonl); /private/tmp/dxmtfx and /private/tmp/nfsrel; the plan file | 962590720 | `01f2462b4917aea8…` |
| `wine-nfs2015-source-0010.tar.gz` | LGPL corresponding-source archive cited by shipped apps | 53107123 | `0d5b52b869c5da43…` |
| `wine-nfs2015-source-0011.tar.gz` | LGPL corresponding-source archive cited by shipped apps | 53902442 | `b8ea1642537c6040…` |

Restore: `mkdir x && tar -xf files/knowledge-20261009.tar -C x` (paths inside are relative to `/`, e.g. `x/Users/gc/Developer/Games/bf4-run/...`). List: `tar -tf files/knowledge-20261009.tar | less`.

## 3. Patches (`patches/`)
- `nfsmw-ps-mtld3d-4commits.patch` (176,626 B): `git am` onto upstream athei/mtld3d 58ed7d9 to rebuild nfsmw-macos ca187f6.
- `nfsmw-macos-app-uncommitted.patch` + `nfsmw-macos-app-status.txt` + `untracked-nfsmw-macos-app/` (app_archive.py, check_app_archive.py): the 4 dirty paths of `NFSMW-tools/macos-app` (ZIP64 wiring in build.py, older BUNDLING.md; the two new files equal commit 99b98c1 on GitHub).
- `widescreen-reference-uncommitted.patch`: the Resolution.ixx edit used for the light-streak crash analysis.
- `runtime-scratch-diff-note.txt`: the whole diff of `ron-tools/full/runtime-scratch` vs wine-0010 = one symlink `lib/wine/dxgi/gptk -> dxmt` (the steam-web-helper rule fix).

## 4. Restoring the two SHALLOW wine bundles (tested on mbp23 in /tmp, fsck clean)
```
git clone --mirror git/nfsmw-ps-wine.bundle wine.git
git -C wine.git fetch git/wine-rebuild-src-wine.bundle 'refs/heads/*:refs/preserved/wine-rebuild/*'   # wx-0008..0011, wx-experiment
git -C wine.git fetch git/wine-arm64-src.bundle 'refs/heads/*:refs/preserved/wine-arm64/*'            # 6 arm64/wow64 branches
```
Tested result: 5 + 6 refs, tips wx-experiment 44974bf, arm64-macos a3433d0, arm64-macos-rebased b92f4ed, wow64-cpu cf90b43, wow64-cpu-old f3ebe29; `git fsck --connectivity-only`: 0 errors.

## 5. Deliberately NOT copied
- EA / Battlelog / Steam sessions and prefixes: `bf4-run/prefix-bf4`, `bf4-run/browser-profile`, `ea-app-lab/Prefix`, `~/Library/Application Support/NFS2015Mac`, ron-tools prefixes (class D: owner decision; Stage 0.6).
- Registry hive copies (`system.reg*`, `user.reg*`, e.g. `bf4-run/logs/system.reg.before-*`, `bf3/system.reg.before-shellwin`): excluded as a precaution.
- `~/Downloads/winehost_developer_id*.provisionprofile` (signing material), `.DS_Store`.
- `/private/tmp/x87fid x87cw x87bcd x87s_scratch r3-cpp-x87` (possibly rosetta3's: ask that session), `bf4*.sh`, `gdv-bundle.log`, `bf3sp.pid` (running workers' files), screenshots on the Desktop (may show private windows).
- Other sessions' folders (rosetta3*, agora*, claudetalk, arcleak/dolly/atelier/deadwood, skills, bump-tools, fc2-dev/rosetta3 ...).
- Runtimes/build trees/toolchains/clones that are regenerable (class A/B) and game data (class D) were out of Stage 0 scope.
- Secret scan before archiving (AuthCode/token values, cookies, bearer tokens, private keys, ssh keys) over every archived path: 0 real hits (1 false positive: DELETION-PROPOSAL.md quotes a grep pattern).

## 6. Verification record
- `shasum -a 256 -c SHA256SUMS` on mbp23: 27/27 OK (bundles, knowledge tar, two source archives, patches, local-only bundle).
- `git bundle verify`: all OK except `nfsmw-ps-mtld3d-localonly` which correctly reports its prerequisite 58ed7d9 (expected).
- Test mirror clones in /tmp on mbp23 (removed afterwards): nfs-release (bf4-recipe-schema e7e7a1b), farcry2 (cfd2de9), mtld3d (test-fix-d3d8 5c91c3d), x87sidecar PR branches (6), nfsmw-ps-wine (crash-context ed16a3c9119 / 0867f210ec9): all as expected; shallow wine bundles restore per section 4.
- Tar entry count on mbp23 = local count (7,482).
- Own artifacts removed: a failed 16-byte bundle (empty, partial clone) from the destination, logged in `~/Documents/NFS-backups/wine-patches/deleted-20261008.log`.
