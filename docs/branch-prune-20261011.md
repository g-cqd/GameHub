# Branch Prune Record — 2026-10-11

## Summary

- Date 2026-10-11. Approved by the user: delete SAFE branches (local + g-cqd remotes) and consolidate the rest into production branches; tags and bundles allowed.
- Backups (verified `git bundle verify` ok) in /Volumes/ExT2/Backups/git/: rosetta3-all-20261011-1640.bundle, mtld3d-all-20261011-1640.bundle, x87sidecar-all-20261011-1640.bundle, wine-all-20261011-1640.bundle, nfs-macos-all-20261011-1640.bundle, dxmt-v0.80-all-20261011-1640.bundle, GeneralsX-all-20261011-1640.bundle, and corresponding *-refs-20261011-1640.txt for each; pre-fetch ref lists *-refs-prefetch-20261011-1640.txt; rosetta3-worktrees-before-prune-20261011.txt.
- Proof rules: `anc:<sha><=<ref>` = `git merge-base --is-ancestor` at run time; `cherry:... 0+/N-` = `git cherry` shows no '+' and no merges; `archived in refs/tags/archive/<b>-20261011` = annotated tag at the tip, pushed and verified on the remote (peeled SHA) before deletion; dxmt archive tags are of exact duplicates of 3Shain upstream heads. Executor: /tmp/branch-prune/execute.sh (reviewed twice by a code reviewer before running).
- Counts: 206 branch deletions (106 local, 100 remote), 24 archive tags, worktrees: 29 stale rosetta3-wt registrations pruned (directories had already vanished; any uncommitted work there was already lost before this run), agent-ae8ad2ddc8740bdf1 worktree removed (clean), temporary consolidate-mtld3d and consolidate-rosetta3 worktrees removed.

## Production branches

| Repo | Branch | Before | After | Pushed |
|---|---|---|---|---|
| rosetta3 | main | 5aeca41 | 89174e1 | pushed to origin, fast-forward. Merged: cov/amd up to e8b7081, cov/sys-adjacent up to 0f04306 (WIP tips excluded, full tips kept as archive tags), cov/x87-residual (full, its tip fixes 4 tests), rs/bench, research/ml-seq. cargo test --workspace: baseline 1880 pass/0 fail/7 ignored → 1932/0/7. Conflicts in decode op count (688) and coverage files resolved by regeneration; reviewed: no baseline row relaxed. |
| mtld3d | development | 9818578 | 9818578 | unchanged (bfabd76 and 5c91c3d already present in reworked form via 56a2ec3; their branches archived as tags). |
| x87sidecar | development | b947853 | db3cb92 | not moved by this work: the x87sidecar fix agent fast-forwarded it to db3cb92 at 17:20 and it is already on origin; this work only deleted SAFE branches. |
| wine | development | 825fdbcacc9 | 825fdbcacc9 | unchanged. |
| nfs-macos | main | be2cfba | be2cfba | unchanged. |
| dxmt (g-cqd/dxmt) | development | 214562d | 214562d | unchanged. |
| GeneralsX | main | cdf2f95 | cdf2f95 | unchanged locally; NOTE local main is 337 commits ahead of gcqd/main 366e09e (not pushed by this work). |

## Not merged (archived as tags)

**rosetta3:** rs/perf3 (moves GuestContext EFLAGS offset 0x08C→0x178, flips WoW64 defaults fault_flags_stale/inline_ret, WIP commit; needs user sign-off to merge), rs/perf2 (subset of rs/perf3), cov/vex-modern (fails r3-lower every_supported_op_is_lowered_by_the_corpus and r3-ireval mutated_functions_return_errors_never_panic overflow at ops_sseint.rs:45), rs/harness64, rs/recipes, rs/tier, research/ml-search (rate-limit WIP snapshots on stale bases), area/abi, area/ir, area/interp, area/x87stack (C++ era, superseded), worktree-agent-ae8ad2ddc8740bdf1.

**wine:** nfs2015-runtime-0011 (contains -0005, -0010), wow64-cpu (contains arm64-macos), rosetta-smc-candidate, nfsmw-macos, macos-arm64-native.

**mtld3d:** sync-upstream-20261008, test-fix-d3d8.

**dxmt:** chore/idl, dxil-dev, feat/d2d-interop.

Restore any with `git branch <name> refs/tags/archive/<name>-20261011`.

## Remaining branches and why

- GitHub default branches that cannot be deleted without changing the repository default: g-cqd/mtld3d main, g-cqd/x87sidecar master, g-cqd/wine master, g-cqd/dxmt main (all upstream mirrors; mtld3d main, x87sidecar master and wine master are ancestors of development; dxmt main equals 3Shain main).
- Left untouched by rule: detached worktrees /Volumes/ExT2/GameHub/work/{wt-hub-a, winemac-fs/src, wine-fontperf/src, dxmt-rtv/src-wt, mtld3d-merge}, ~/Developer/x87sidecar-wt-fprpool (later removed by the x87sidecar fix agent, not by this work), GeneralsX build/review-baseline-source; GeneralsX stash@{0} "phase1-fix-wip" kept.

## Action log

### x87sidecar

| Repo | Branch | Local/Remote | Proof | Action | Result |
|---|---|---|---|---|---|
| x87sidecar | archive/fc2-perf/development | local | anc:8aa4d308d90c3cc5ebf873db8c3e851848a332db<=development | delete | ok |
| x87sidecar | archive/fc2-perf/fc2-perf | local | anc:8aa4d308d90c3cc5ebf873db8c3e851848a332db<=development | delete | ok |
| x87sidecar | archive/fc2-perf/integrate-fld-gap-fstp | local | anc:c3969379750531fb124859ae742ab4f727f54f9c<=development | delete | ok |
| x87sidecar | archive/fc2-rosetta/development | local | anc:12afdc2880246a92014b67f83df32696ef77d82b<=development | delete | ok |
| x87sidecar | archive/fc2-rosetta/fc2-rosetta-research | local | anc:fe05037f551fa6a161c5c6dd65cc90951940cc5e<=development | delete | ok |
| x87sidecar | master | local | anc:4048fcf436876f26c799ba2fa340ec73f4cca95e<=development | delete | ok |
| x87sidecar | archive/fc2-perf/fc2-x87-fuse | local | cherry:db61cb7bf72894ade8965eb3d9c9a26835528338 0+/6- vs development, 0 merges | delete | ok |
| x87sidecar | archive/fc2-perf/fc2-x87-fuse-rebased | local | cherry:bd53e37fd38552efc9e62817a1fc814596df9082 0+/6- vs development, 0 merges | delete | ok |
| x87sidecar | integrate-fld-gap-fstp | remote | anc:c3969379750531fb124859ae742ab4f727f54f9c<=origin/development | delete | ok |

### nfs-macos

| Repo | Branch | Local/Remote | Proof | Action | Result |
|---|---|---|---|---|---|
| nfs-macos | host-4k-rebased | remote | anc:d149987fdb0cb1f960d041d0f064bc23c9d30a76<=origin/main | delete | ok |
| nfs-macos | import-game-data | remote | anc:4212dd738b3cfffb935f1cde9893073e05fce0ce<=origin/main | delete | ok |
| nfs-macos | integration-20261002 | remote | anc:f4c3273017128c1be96878221d0c7da392bb0bf0<=origin/main | delete | ok |
| nfs-macos | licensing | remote | anc:bee32a6d87f2011aa48d31c00944abe975ffc9fa<=origin/main | delete | ok |
| nfs-macos | nfs2015-diagnostics | remote | anc:7bca7b08e23922352b3c7a27c4c477a378780eb1<=origin/main | delete | ok |
| nfs-macos | refresh-runtimes-cod4-bundle | remote | anc:71082c80c0fdf1684f29e6d4a8a36af981f337e3<=origin/main | delete | ok |

### GeneralsX

| Repo | Branch | Local/Remote | Proof | Action | Result |
|---|---|---|---|---|---|
| GeneralsX | feat/ai-modernization-phase0 | local | anc:1d67d0863f110dc67f5bc5ca674b0f9fcb4555b5<=main | delete | ok |
| GeneralsX | feature/swift-net-offload | local | anc:94912b2ca5a298a09542b8911a57997127e8369b<=main | delete | ok |
| GeneralsX | feature/upstream-review-fixes | local | anc:39e312c71e1cf0ffe300aed52ac9cafb5566b066<=main | delete | ok |
| GeneralsX | worktree-agent-a6b2148cb64d45d6e | local | anc:7098868b81a8cf9855322dc4c944d44a9f812aee<=main | delete | ok |
| GeneralsX | feature/swift-net-offload | remote | anc:94912b2ca5a298a09542b8911a57997127e8369b<=gcqd/main | delete | ok |

### mtld3d

| Repo | Branch | Local/Remote | Proof | Action | Result |
|---|---|---|---|---|---|
| mtld3d | archive/fc2-foliage/development | local | anc:b22073b4fe835ec4beb7017898b4593be2f3a018<=development | delete | ok |
| mtld3d | archive/fc2-foliage/integrate-farcry2-profile | local | anc:845b6c914a55633cbe099a076432d2dbe3656d1d<=development | delete | ok |
| mtld3d | main | local | anc:1b0bf1f40c8bfeecb4b0c5a2c8182ef6893edd76<=development | delete | ok |
| mtld3d | archive/fc2-foliage/farcry2-nvidia-profile | local | cherry:df60ce037f6ada6e9602cd3e0ea91bf153b5f676 0+/1- vs development, 0 merges | delete | ok |
| mtld3d | archive/fc2-foliage/fc2-foliage | local | cherry:0e995a62726cc2ceea0ed36e690664cc0dcf1018 0+/1- vs development, 0 merges | delete | ok |
| mtld3d | integrate-farcry2-profile | remote | anc:845b6c914a55633cbe099a076432d2dbe3656d1d<=origin/development | delete | ok |
| mtld3d | sync-upstream-20261008 | tag | tip bfabd76da12de8378abe5dc3c254ed0c16e6f1f3 | tag archive/sync-upstream-20261008-20261011 pushed | ok |
| mtld3d | sync-upstream-20261008 | remote | archived in refs/tags/archive/sync-upstream-20261008-20261011 (remote tip bfabd76da12de8378abe5dc3c254ed0c16e6f1f3 <= tag) | delete | ok |
| mtld3d | sync-upstream-20261008 | local | archived in refs/tags/archive/sync-upstream-20261008-20261011 (tag==tip) | delete | ok |
| mtld3d | test-fix-d3d8 | tag | tip 5c91c3d93f7768636bb928e4f599709400d26662 | tag archive/test-fix-d3d8-20261011 pushed | ok |
| mtld3d | test-fix-d3d8 | local | archived in refs/tags/archive/test-fix-d3d8-20261011 (tag==tip) | delete | ok |
| mtld3d | (consolidate-mtld3d) | worktree | own temp detached a255602, clean | git worktree remove | ok |

### dxmt

| Repo | Branch | Local/Remote | Proof | Action | Result |
|---|---|---|---|---|---|
| dxmt | chore/idl | tag | tip 0adc0a0b00893089980b49f26db05b6e59e9a9d0 | tag archive/chore/idl-20261011 pushed | ok |
| dxmt | chore/idl | remote | archived in refs/tags/archive/chore/idl-20261011 (remote tip 0adc0a0b00893089980b49f26db05b6e59e9a9d0 <= tag) | delete | ok |
| dxmt | dxil-dev | tag | tip 774aebc30e4003073905d5fc1a6b3ffd6f556092 | tag archive/dxil-dev-20261011 pushed | ok |
| dxmt | dxil-dev | remote | archived in refs/tags/archive/dxil-dev-20261011 (remote tip 774aebc30e4003073905d5fc1a6b3ffd6f556092 <= tag) | delete | ok |
| dxmt | feat/d2d-interop | tag | tip 3a9a303379ea6339542872d9002ad23d6f1c9e86 | tag archive/feat/d2d-interop-20261011 pushed | ok |
| dxmt | feat/d2d-interop | remote | archived in refs/tags/archive/feat/d2d-interop-20261011 (remote tip 3a9a303379ea6339542872d9002ad23d6f1c9e86 <= tag) | delete | ok |

### wine

| Repo | Branch | Local/Remote | Proof | Action | Result |
|---|---|---|---|---|---|
| wine | stable | remote | anc:db11d0fe6a169c457e23d007e20404643d067aa8<=origin/development | delete | ok |
| wine | oldstable | remote | anc:b073859675060c9211fcbccfd90e4e87520dc2c2<=origin/development | delete | ok |
| wine | nfs2015-runtime-0011 | tag | tip 71133b59a0038a190060b5ad653cf62beb3226ba | tag archive/nfs2015-runtime-0011-20261011 pushed | ok |
| wine | nfs2015-runtime-0011 | remote | archived in refs/tags/archive/nfs2015-runtime-0011-20261011 (remote tip 71133b59a0038a190060b5ad653cf62beb3226ba <= tag) | delete | ok |
| wine | wow64-cpu | tag | tip c92ef791ef93c6e177821278c89769e2ead02be9 | tag archive/wow64-cpu-20261011 pushed | ok |
| wine | wow64-cpu | remote | archived in refs/tags/archive/wow64-cpu-20261011 (remote tip c92ef791ef93c6e177821278c89769e2ead02be9 <= tag) | delete | ok |
| wine | rosetta-smc-candidate | tag | tip bbf0786eb4a73857e61785ce30e78edbf4d715df | tag archive/rosetta-smc-candidate-20261011 pushed | ok |
| wine | rosetta-smc-candidate | remote | archived in refs/tags/archive/rosetta-smc-candidate-20261011 (remote tip bbf0786eb4a73857e61785ce30e78edbf4d715df <= tag) | delete | ok |
| wine | nfsmw-macos | tag | tip f064add996bbf4819acf49f48bab263735279800 | tag archive/nfsmw-macos-20261011 pushed | ok |
| wine | nfsmw-macos | remote | archived in refs/tags/archive/nfsmw-macos-20261011 (remote tip f064add996bbf4819acf49f48bab263735279800 <= tag) | delete | ok |
| wine | macos-arm64-native | tag | tip 6bcff626b3403746e264f03d9c265ac933150e57 | tag archive/macos-arm64-native-20261011 pushed | ok |
| wine | macos-arm64-native | remote | archived in refs/tags/archive/macos-arm64-native-20261011 (remote tip 6bcff626b3403746e264f03d9c265ac933150e57 <= tag) | delete | ok |
| wine | nfs2015-runtime-0005 | remote | anc:f4fc43f2e04a3b92f32856fe56dc43ab2b47a57d<=refs/tags/archive/nfs2015-runtime-0011-20261011 | delete | ok |
| wine | nfs2015-runtime-0010 | remote | anc:6e4a7fff26121c3ead00ba62916520051faa3da7<=refs/tags/archive/nfs2015-runtime-0011-20261011 | delete | ok |
| wine | arm64-macos | remote | anc:89a212b2895086361159e5a38036bf70f4d13267<=refs/tags/archive/wow64-cpu-20261011 | delete | ok |

### rosetta3

| Repo | Branch | Local/Remote | Proof | Action | Result |
|---|---|---|---|---|---|
| rosetta3 | (28 rosetta3-wt entries) | worktree | directories absent on disk; list in rosetta3-worktrees-before-prune-20261011.txt | git worktree prune | ok |
| rosetta3 | worktree-agent-ae8ad2ddc8740bdf1 | worktree | clean | git worktree remove | ok |
| rosetta3 | area/a64 | local | anc:a9950ec16765047779f26bcbde421598b59add17<=main | delete | ok |
| rosetta3 | area/decode | local | anc:c3a6f9fec3cf7cde0c0ba8f36d0b9da2908d8da0<=main | delete | ok |
| rosetta3 | area/flags | local | anc:db5de00d528e30c4aa6038e3cf197634f4dd7522<=main | delete | ok |
| rosetta3 | area/jitmem | local | anc:e60f86f1a357290eaf39b138d2a11d482b64bb61<=main | delete | ok |
| rosetta3 | area/oracle | local | anc:da5b17ab9a41d26d67e66d8145eaa47270ae9fd9<=main | delete | ok |
| rosetta3 | area/x87cmp | local | anc:847b16a4d07dedb55750898d8d9af6184d34f230<=main | delete | ok |
| rosetta3 | area/x87ref | local | anc:398821d3b26bd191f73b1525d3987d19bffcd245<=main | delete | ok |
| rosetta3 | cov/16bit-bcd | local | anc:4c2c92d90765929958090ad4e886b26ef607969d<=main | delete | ok |
| rosetta3 | cov/atomics | local | anc:edc011faedb218cfafedf064f002e473a8229e6f<=main | delete | ok |
| rosetta3 | cov/crypto | local | anc:8c76e07bb4ce20c8578b7d103d42cf5db94a0e6a<=main | delete | ok |
| rosetta3 | cov/int-forms | local | anc:38934d21d926df8194d9d35aef6124df450220c9<=main | delete | ok |
| rosetta3 | cov/misc | local | anc:bf23ea65fe137bde6329d31bd4152b4df741ffef<=main | delete | ok |
| rosetta3 | cov/system-faults | local | anc:112c00cb2f8a84543331edec0774f54772e56a1b<=main | delete | ok |
| rosetta3 | cov/vex-gather | local | anc:9ad8230127c4848219b386f2c1d069fcdb62c88d<=main | delete | ok |
| rosetta3 | cov/vex-shuffle-a | local | anc:4f92f6a9c5391dc0fa58c37c854cf2c8c1bf9210<=main | delete | ok |
| rosetta3 | cov/vex-shuffle-b | local | anc:dfce811394d265b891f7df56452b33fd583cf6b2<=main | delete | ok |
| rosetta3 | fix/atomics-faultmap | local | anc:03561aa61b5177ab2b1799f3cd7231cf4bfb7e2c<=main | delete | ok |
| rosetta3 | fix/merge-20261008 | local | anc:ab1b089c63ac4f9de7bd51991fdab13cb2d6e5ac<=main | delete | ok |
| rosetta3 | fix/x87seg-regs | local | anc:78d4f7f30e692e6bb5004e1c73dfed73d720aa6c<=main | delete | ok |
| rosetta3 | research/ml | local | anc:dc6e1280e7a1697969e4d8a476c2ff08750d6d40<=main | delete | ok |
| rosetta3 | research/ml-cost | local | anc:17137f679bd97e5d99e4d4b740d6e43bd1044dac<=main | delete | ok |
| rosetta3 | research/ml-creative2 | local | anc:6b50787cdee6cf444fde93269c02d7011f7d16c2<=main | delete | ok |
| rosetta3 | research/ml-modern | local | anc:6fa19370d91093ab9dec3c9c5d9052fe3fd9434e<=main | delete | ok |
| rosetta3 | research/ml-patterns | local | anc:68e6a1891d07733c88e84cc31a1ef55d480dab1f<=main | delete | ok |
| rosetta3 | research/ml-superopt | local | anc:ff9c623725e56ca8440d350f4924b353138c3579<=main | delete | ok |
| rosetta3 | rs/a64 | local | anc:117296487df3ca7a532f1447f741ff7a14c54bd2<=main | delete | ok |
| rosetta3 | rs/abi | local | anc:f3abd5c4e6a214661f0b3100032b6aa624c591e5<=main | delete | ok |
| rosetta3 | rs/align | local | anc:8b47d729e97650f97a3280d14662951c87686baa<=main | delete | ok |
| rosetta3 | rs/cover | local | anc:c27f0dd6114409953974dd65f4dc35ddb9b0c895<=main | delete | ok |
| rosetta3 | rs/cpuid-honest | local | anc:81e333952cb38db46e02f42be1d1edcfac913c94<=main | delete | ok |
| rosetta3 | rs/decode | local | anc:58a8f74d03c3405dfece8bfa62893dd31f053952<=main | delete | ok |
| rosetta3 | rs/faultmap | local | anc:368b941d07a7db582fbd3810a3b2c37f16218527<=main | delete | ok |
| rosetta3 | rs/fix-addsub | local | anc:e03e753011504cfdd48c7933abc999ca0073a087<=main | delete | ok |
| rosetta3 | rs/flags | local | anc:8ca74bc04a544db6b1d86cd603cc730cfd50dcdd<=main | delete | ok |
| rosetta3 | rs/flagslive | local | anc:017cc56cf935b81ca8629ae20a31bdbde3213acc<=main | delete | ok |
| rosetta3 | rs/frontend | local | anc:aabe8fc33c691c72460cb3ad207dfc38c6ed87d0<=main | delete | ok |
| rosetta3 | rs/hosting | local | anc:f5a8a63d649211ac38f48269f1d84ba2089c3d8c<=main | delete | ok |
| rosetta3 | rs/interp | local | anc:59634046a61efaf9dcde334b81c780af5cff6315<=main | delete | ok |
| rosetta3 | rs/ir | local | anc:301768ed3de964c2002906f604f8490ef4bbf229<=main | delete | ok |
| rosetta3 | rs/ireval | local | anc:e49089abeaea1bccf77312d66cbcf0b9074666bf<=main | delete | ok |
| rosetta3 | rs/jitmem | local | anc:728d8287ad027b5be8e3412e6ad12209464d0ed1<=main | delete | ok |
| rosetta3 | rs/lower | local | anc:ed815d223fc98493ab476e2b8b6488f5a9b155c6<=main | delete | ok |
| rosetta3 | rs/lowgaps | local | anc:4085c7442f1446ac79d8a855267d434a089f2c2b<=main | delete | ok |
| rosetta3 | rs/opt | local | anc:a2cb8b3f56658a55afe0c294b03d02a80500a86b<=main | delete | ok |
| rosetta3 | rs/perf | local | anc:4c5e11a0bcff8f591101e6badd22164110d9e395<=main | delete | ok |
| rosetta3 | rs/priv-lowmem | local | anc:bb1b8cd68dc5e03c447c2b990819cf82200da0fa<=main | delete | ok |
| rosetta3 | rs/private | local | anc:386dbd19617c9ffaff01e15bfa4ba7a82b81fb21<=main | delete | ok |
| rosetta3 | rs/realprog | local | anc:e060764f45e5b0a4a835df2c04654bb23b16e48d<=main | delete | ok |
| rosetta3 | rs/smc-ip | local | anc:97b557bbfd7446e765fedfd13d5d5090523b40cc<=main | delete | ok |
| rosetta3 | rs/snan | local | anc:780925a71a79691e06a90600cdd8ea7223c611b1<=main | delete | ok |
| rosetta3 | rs/spike-low4g | local | anc:991d06bcf6a35e408c9d962c854fa296c4f7e471<=main | delete | ok |
| rosetta3 | rs/sseint | local | anc:7b11e4c57bf5a3729cb170c16501f46b872c622c<=main | delete | ok |
| rosetta3 | rs/translator | local | anc:0344f952fe1cf345a624e13311b069beccd6917a<=main | delete | ok |
| rosetta3 | rs/tso-research | local | anc:82169fdcc3a567de90ead563c4bbf51f72947146<=main | delete | ok |
| rosetta3 | rs/vex | local | anc:1652e549afab63e377e54cbaf3cda98f42f35fe3<=main | delete | ok |
| rosetta3 | rs/vex-cpu | local | anc:b87f3604d53269b01489a315f1312393f2cd6983<=main | delete | ok |
| rosetta3 | rs/vex-ir | local | anc:b7297fd6775cc2d5625157ba3ceb790908d56b82<=main | delete | ok |
| rosetta3 | rs/vex-sse | local | anc:e6dab0e4490281c8d2274107525ead4277acbdde<=main | delete | ok |
| rosetta3 | rs/vex-sse4 | local | anc:95c6e7e1a4b02be4b56fbcff9642cba657c8851b<=main | delete | ok |
| rosetta3 | rs/wow64 | local | anc:7203cb1bb5ba2c7292b0f4c24cbc205b44046ce5<=main | delete | ok |
| rosetta3 | rs/x87cmp | local | anc:c687ac31beb26da4deeebd1a68e0242d0267f91c<=main | delete | ok |
| rosetta3 | rs/x87cw | local | anc:6789aafe25485b38c1e829ebabcb8d94bbe09723<=main | delete | ok |
| rosetta3 | rs/x87fid | local | anc:d19e045c3e481d7dd555f97aea39f037b0cc698d<=main | delete | ok |
| rosetta3 | rs/x87ref | local | anc:048b65b6f1baa0727064cd91db13e52650d02854<=main | delete | ok |
| rosetta3 | rs/x87rt | local | anc:ca492f09de2fa126c39476909b01eb0f77d7d2a7<=main | delete | ok |
| rosetta3 | rs/x87stack | local | anc:cfa0427c0a217407a91a8a01af1336a609d88c88<=main | delete | ok |
| rosetta3 | worktree-agent-a4f611aca5d013a26 | local | anc:60be0ca7528d4ed99d0d935d47675e8824a81336<=main | delete | ok |
| rosetta3 | worktree-agent-a6967f4008c530880 | local | anc:60be0ca7528d4ed99d0d935d47675e8824a81336<=main | delete | ok |
| rosetta3 | worktree-agent-a7b7d2a72620786a5 | local | anc:60be0ca7528d4ed99d0d935d47675e8824a81336<=main | delete | ok |
| rosetta3 | worktree-agent-a8050fb635ecc07fa | local | anc:60be0ca7528d4ed99d0d935d47675e8824a81336<=main | delete | ok |
| rosetta3 | area/a64 | remote | anc:a9950ec16765047779f26bcbde421598b59add17<=origin/main | delete | ok |
| rosetta3 | area/decode | remote | anc:c3a6f9fec3cf7cde0c0ba8f36d0b9da2908d8da0<=origin/main | delete | ok |
| rosetta3 | area/flags | remote | anc:db5de00d528e30c4aa6038e3cf197634f4dd7522<=origin/main | delete | ok |
| rosetta3 | area/jitmem | remote | anc:e60f86f1a357290eaf39b138d2a11d482b64bb61<=origin/main | delete | ok |
| rosetta3 | area/oracle | remote | anc:da5b17ab9a41d26d67e66d8145eaa47270ae9fd9<=origin/main | delete | ok |
| rosetta3 | area/x87cmp | remote | anc:847b16a4d07dedb55750898d8d9af6184d34f230<=origin/main | delete | ok |
| rosetta3 | area/x87ref | remote | anc:398821d3b26bd191f73b1525d3987d19bffcd245<=origin/main | delete | ok |
| rosetta3 | cov/16bit-bcd | remote | anc:4c2c92d90765929958090ad4e886b26ef607969d<=origin/main | delete | ok |
| rosetta3 | cov/atomics | remote | anc:edc011faedb218cfafedf064f002e473a8229e6f<=origin/main | delete | ok |
| rosetta3 | cov/crypto | remote | anc:8c76e07bb4ce20c8578b7d103d42cf5db94a0e6a<=origin/main | delete | ok |
| rosetta3 | cov/int-forms | remote | anc:38934d21d926df8194d9d35aef6124df450220c9<=origin/main | delete | ok |
| rosetta3 | cov/misc | remote | anc:bf23ea65fe137bde6329d31bd4152b4df741ffef<=origin/main | delete | ok |
| rosetta3 | cov/system-faults | remote | anc:112c00cb2f8a84543331edec0774f54772e56a1b<=origin/main | delete | ok |
| rosetta3 | cov/vex-gather | remote | anc:9ad8230127c4848219b386f2c1d069fcdb62c88d<=origin/main | delete | ok |
| rosetta3 | cov/vex-shuffle-b | remote | anc:dfce811394d265b891f7df56452b33fd583cf6b2<=origin/main | delete | ok |
| rosetta3 | fix/atomics-faultmap | remote | anc:03561aa61b5177ab2b1799f3cd7231cf4bfb7e2c<=origin/main | delete | ok |
| rosetta3 | fix/merge-20261008 | remote | anc:ab1b089c63ac4f9de7bd51991fdab13cb2d6e5ac<=origin/main | delete | ok |
| rosetta3 | fix/x87seg-regs | remote | anc:78d4f7f30e692e6bb5004e1c73dfed73d720aa6c<=origin/main | delete | ok |
| rosetta3 | research/ml | remote | anc:dc6e1280e7a1697969e4d8a476c2ff08750d6d40<=origin/main | delete | ok |
| rosetta3 | research/ml-cost | remote | anc:17137f679bd97e5d99e4d4b740d6e43bd1044dac<=origin/main | delete | ok |
| rosetta3 | research/ml-creative2 | remote | anc:6b50787cdee6cf444fde93269c02d7011f7d16c2<=origin/main | delete | ok |
| rosetta3 | research/ml-modern | remote | anc:6fa19370d91093ab9dec3c9c5d9052fe3fd9434e<=origin/main | delete | ok |
| rosetta3 | research/ml-patterns | remote | anc:68e6a1891d07733c88e84cc31a1ef55d480dab1f<=origin/main | delete | ok |
| rosetta3 | research/ml-superopt | remote | anc:ff9c623725e56ca8440d350f4924b353138c3579<=origin/main | delete | ok |
| rosetta3 | rs/a64 | remote | anc:117296487df3ca7a532f1447f741ff7a14c54bd2<=origin/main | delete | ok |
| rosetta3 | rs/abi | remote | anc:f3abd5c4e6a214661f0b3100032b6aa624c591e5<=origin/main | delete | ok |
| rosetta3 | rs/align | remote | anc:8b47d729e97650f97a3280d14662951c87686baa<=origin/main | delete | ok |
| rosetta3 | rs/decode | remote | anc:58a8f74d03c3405dfece8bfa62893dd31f053952<=origin/main | delete | ok |
| rosetta3 | rs/faultmap | remote | anc:368b941d07a7db582fbd3810a3b2c37f16218527<=origin/main | delete | ok |
| rosetta3 | rs/fix-addsub | remote | anc:e03e753011504cfdd48c7933abc999ca0073a087<=origin/main | delete | ok |
| rosetta3 | rs/flags | remote | anc:8ca74bc04a544db6b1d86cd603cc730cfd50dcdd<=origin/main | delete | ok |
| rosetta3 | rs/flagslive | remote | anc:017cc56cf935b81ca8629ae20a31bdbde3213acc<=origin/main | delete | ok |
| rosetta3 | rs/frontend | remote | anc:aabe8fc33c691c72460cb3ad207dfc38c6ed87d0<=origin/main | delete | ok |
| rosetta3 | rs/hosting | remote | anc:f5a8a63d649211ac38f48269f1d84ba2089c3d8c<=origin/main | delete | ok |
| rosetta3 | rs/interp | remote | anc:59634046a61efaf9dcde334b81c780af5cff6315<=origin/main | delete | ok |
| rosetta3 | rs/ir | remote | anc:301768ed3de964c2002906f604f8490ef4bbf229<=origin/main | delete | ok |
| rosetta3 | rs/ireval | remote | anc:e49089abeaea1bccf77312d66cbcf0b9074666bf<=origin/main | delete | ok |
| rosetta3 | rs/jitmem | remote | anc:728d8287ad027b5be8e3412e6ad12209464d0ed1<=origin/main | delete | ok |
| rosetta3 | rs/lower | remote | anc:ed815d223fc98493ab476e2b8b6488f5a9b155c6<=origin/main | delete | ok |
| rosetta3 | rs/lowgaps | remote | anc:4085c7442f1446ac79d8a855267d434a089f2c2b<=origin/main | delete | ok |
| rosetta3 | rs/opt | remote | anc:a2cb8b3f56658a55afe0c294b03d02a80500a86b<=origin/main | delete | ok |
| rosetta3 | rs/perf | remote | anc:2fbea5d9ab51110b6cfb7274608e8860b9f1ec26<=origin/main | delete | ok |
| rosetta3 | rs/priv-lowmem | remote | anc:bb1b8cd68dc5e03c447c2b990819cf82200da0fa<=origin/main | delete | ok |
| rosetta3 | rs/private | remote | anc:386dbd19617c9ffaff01e15bfa4ba7a82b81fb21<=origin/main | delete | ok |
| rosetta3 | rs/realprog | remote | anc:e060764f45e5b0a4a835df2c04654bb23b16e48d<=origin/main | delete | ok |
| rosetta3 | rs/snan | remote | anc:8d19a92b3c99851b760680dbf741ba962a2d777c<=origin/main | delete | ok |
| rosetta3 | rs/spike-low4g | remote | anc:991d06bcf6a35e408c9d962c854fa296c4f7e471<=origin/main | delete | ok |
| rosetta3 | rs/sseint | remote | anc:7b11e4c57bf5a3729cb170c16501f46b872c622c<=origin/main | delete | ok |
| rosetta3 | rs/translator | remote | anc:0344f952fe1cf345a624e13311b069beccd6917a<=origin/main | delete | ok |
| rosetta3 | rs/tso-research | remote | anc:82169fdcc3a567de90ead563c4bbf51f72947146<=origin/main | delete | ok |
| rosetta3 | rs/vex | remote | anc:1652e549afab63e377e54cbaf3cda98f42f35fe3<=origin/main | delete | ok |
| rosetta3 | rs/vex-cpu | remote | anc:b87f3604d53269b01489a315f1312393f2cd6983<=origin/main | delete | ok |
| rosetta3 | rs/vex-ir | remote | anc:b7297fd6775cc2d5625157ba3ceb790908d56b82<=origin/main | delete | ok |
| rosetta3 | rs/vex-sse | remote | anc:e6dab0e4490281c8d2274107525ead4277acbdde<=origin/main | delete | ok |
| rosetta3 | rs/vex-sse4 | remote | anc:95c6e7e1a4b02be4b56fbcff9642cba657c8851b<=origin/main | delete | ok |
| rosetta3 | rs/wow64 | remote | anc:ad15fd3d290e3d3c0d1650260dfa59e4b0513b6e<=origin/main | delete | ok |
| rosetta3 | rs/x87cmp | remote | anc:c687ac31beb26da4deeebd1a68e0242d0267f91c<=origin/main | delete | ok |
| rosetta3 | rs/x87cw | remote | anc:4df1b34930fe5b0a64f11b8db1b740d11b752da3<=origin/main | delete | ok |
| rosetta3 | rs/x87fid | remote | anc:d19e045c3e481d7dd555f97aea39f037b0cc698d<=origin/main | delete | ok |
| rosetta3 | rs/x87ref | remote | anc:048b65b6f1baa0727064cd91db13e52650d02854<=origin/main | delete | ok |
| rosetta3 | rs/x87rt | remote | anc:ca492f09de2fa126c39476909b01eb0f77d7d2a7<=origin/main | delete | ok |
| rosetta3 | rs/x87stack | remote | anc:cfa0427c0a217407a91a8a01af1336a609d88c88<=origin/main | delete | ok |
| rosetta3 | worktree-agent-a4f611aca5d013a26 | remote | anc:60be0ca7528d4ed99d0d935d47675e8824a81336<=origin/main | delete | ok |
| rosetta3 | worktree-agent-a6967f4008c530880 | remote | anc:60be0ca7528d4ed99d0d935d47675e8824a81336<=origin/main | delete | ok |
| rosetta3 | worktree-agent-a7b7d2a72620786a5 | remote | anc:60be0ca7528d4ed99d0d935d47675e8824a81336<=origin/main | delete | ok |
| rosetta3 | worktree-agent-a8050fb635ecc07fa | remote | anc:60be0ca7528d4ed99d0d935d47675e8824a81336<=origin/main | delete | ok |
| rosetta3 | area/interp | tag | tip 1d88064b537e9ae8a7ba4311d83060dff7e6bdd3 | tag archive/area/interp-20261011 pushed | ok |
| rosetta3 | area/interp | remote | archived in refs/tags/archive/area/interp-20261011 (remote tip 1d88064b537e9ae8a7ba4311d83060dff7e6bdd3 <= tag) | delete | ok |
| rosetta3 | area/interp | local | archived in refs/tags/archive/area/interp-20261011 (tag==tip) | delete | ok |
| rosetta3 | area/x87stack | tag | tip 855ffdf26a6c7ed0ad1ec2b76ae7c441dc5061eb | tag archive/area/x87stack-20261011 pushed | ok |
| rosetta3 | area/x87stack | remote | archived in refs/tags/archive/area/x87stack-20261011 (remote tip 855ffdf26a6c7ed0ad1ec2b76ae7c441dc5061eb <= tag) | delete | ok |
| rosetta3 | area/x87stack | local | archived in refs/tags/archive/area/x87stack-20261011 (tag==tip) | delete | ok |
| rosetta3 | area/abi | tag | tip fc5e1f758ffe1d22300eaa44201609cb19f8a62c | tag archive/area/abi-20261011 pushed | ok |
| rosetta3 | area/abi | remote | archived in refs/tags/archive/area/abi-20261011 (remote tip fc5e1f758ffe1d22300eaa44201609cb19f8a62c <= tag) | delete | ok |
| rosetta3 | area/abi | local | archived in refs/tags/archive/area/abi-20261011 (tag==tip) | delete | ok |
| rosetta3 | area/ir | tag | tip bfb3ff9fff465b80bed698c988855fd1f761864b | tag archive/area/ir-20261011 pushed | ok |
| rosetta3 | area/ir | remote | archived in refs/tags/archive/area/ir-20261011 (remote tip bfb3ff9fff465b80bed698c988855fd1f761864b <= tag) | delete | ok |
| rosetta3 | area/ir | local | archived in refs/tags/archive/area/ir-20261011 (tag==tip) | delete | ok |
| rosetta3 | rs/harness64 | tag | tip 74087d1eef857107f36a6d27f4021b6d1d1e3e9c | tag archive/rs/harness64-20261011 pushed | ok |
| rosetta3 | rs/harness64 | remote | archived in refs/tags/archive/rs/harness64-20261011 (remote tip 74087d1eef857107f36a6d27f4021b6d1d1e3e9c <= tag) | delete | ok |
| rosetta3 | rs/harness64 | local | archived in refs/tags/archive/rs/harness64-20261011 (tag==tip) | delete | ok |
| rosetta3 | rs/recipes | tag | tip ba311901a1e3406b30f6eaf3478718dec9d47653 | tag archive/rs/recipes-20261011 pushed | ok |
| rosetta3 | rs/recipes | remote | archived in refs/tags/archive/rs/recipes-20261011 (remote tip ba311901a1e3406b30f6eaf3478718dec9d47653 <= tag) | delete | ok |
| rosetta3 | rs/recipes | local | archived in refs/tags/archive/rs/recipes-20261011 (tag==tip) | delete | ok |
| rosetta3 | rs/tier | tag | tip d20321438271c5c88f64aacaeb060b93c86f67c8 | tag archive/rs/tier-20261011 pushed | ok |
| rosetta3 | rs/tier | remote | archived in refs/tags/archive/rs/tier-20261011 (remote tip d20321438271c5c88f64aacaeb060b93c86f67c8 <= tag) | delete | ok |
| rosetta3 | rs/tier | local | archived in refs/tags/archive/rs/tier-20261011 (tag==tip) | delete | ok |
| rosetta3 | research/ml-search | tag | tip 474326827a3b1bda455f8b0c045294b85e38c42c | tag archive/research/ml-search-20261011 pushed | ok |
| rosetta3 | research/ml-search | remote | archived in refs/tags/archive/research/ml-search-20261011 (remote tip 474326827a3b1bda455f8b0c045294b85e38c42c <= tag) | delete | ok |
| rosetta3 | research/ml-search | local | archived in refs/tags/archive/research/ml-search-20261011 (tag==tip) | delete | ok |
| rosetta3 | worktree-agent-ae8ad2ddc8740bdf1 | tag | tip bb0337282e071e4f6016ad60a0f78a60ff0b9727 | tag archive/worktree-agent-ae8ad2ddc8740bdf1-20261011 pushed | ok |
| rosetta3 | worktree-agent-ae8ad2ddc8740bdf1 | remote | archived in refs/tags/archive/worktree-agent-ae8ad2ddc8740bdf1-20261011 (remote tip bb0337282e071e4f6016ad60a0f78a60ff0b9727 <= tag) | delete | ok |
| rosetta3 | worktree-agent-ae8ad2ddc8740bdf1 | local | archived in refs/tags/archive/worktree-agent-ae8ad2ddc8740bdf1-20261011 (tag==tip) | delete | ok |
| rosetta3 | rs/perf3 | tag | tip 5004c345c5279663665a93c286304ba6f7a5500f | tag archive/rs/perf3-20261011 pushed | ok |
| rosetta3 | rs/perf3 | local | archived in refs/tags/archive/rs/perf3-20261011 (tag==tip) | delete | ok |
| rosetta3 | rs/perf2 | local | anc:34b8f6fdf15982c15e73453c4f3933bb14cff928<=refs/tags/archive/rs/perf3-20261011 (pushed) | delete | ok |
| rosetta3 | cov/amd | tag | tip 1ab5762ecd0b98740b372c9667407d6626089734 | tag archive/cov/amd-20261011 pushed | ok |
| rosetta3 | cov/sys-adjacent | tag | tip 689b30162bef193374e6f96cb3f0b148ff002275 | tag archive/cov/sys-adjacent-20261011 pushed | ok |
| rosetta3 | cov/vex-modern | tag | tip 6ba49a6155bac6c02d6d81b77f9e183a05538700 | tag archive/cov/vex-modern-20261011 pushed | ok |
| rosetta3 | cov/x87-residual | tag | tip 23a800d9f92704825ccf2cb04577870d67fe3b6b | tag archive/cov/x87-residual-20261011 pushed | ok |
| rosetta3 | cov/vex-modern | tag | tip 6ba49a6155bac6c02d6d81b77f9e183a05538700 | tag archive/cov/vex-modern-20261011 pushed | ok |
| rosetta3 | cov/vex-modern | local | archived in refs/tags/archive/cov/vex-modern-20261011 (tag==tip) | delete | ok |
| rosetta3 | cov/amd | local | parent 1ab5762ecd0b98740b372c9667407d6626089734~1 <= origin/main; tip in pushed refs/tags/archive/cov/amd-20261011 | delete | ok |
| rosetta3 | cov/amd | remote | - | skip | absent |
| rosetta3 | cov/sys-adjacent | local | parent 689b30162bef193374e6f96cb3f0b148ff002275~1 <= origin/main; tip in pushed refs/tags/archive/cov/sys-adjacent-20261011 | delete | ok |
| rosetta3 | cov/sys-adjacent | remote | - | skip | absent |
| rosetta3 | cov/x87-residual | local | parent 23a800d9f92704825ccf2cb04577870d67fe3b6b~1 <= origin/main; tip in pushed refs/tags/archive/cov/x87-residual-20261011 | delete | ok |
| rosetta3 | cov/x87-residual | remote | - | skip | absent |
| rosetta3 | rs/bench | local | anc:200d27258aca31624e8dd729ab395cdfb8be1249<=origin/main | delete | ok |
| rosetta3 | rs/bench | remote | anc:27b9f80f61c2ae2b9897f15df5eea94c09f757d2<=origin/main | delete | ok |
| rosetta3 | research/ml-seq | local | anc:16e9965184bca9ec030fdaf555de9ef00cb3deaa<=origin/main | delete | ok |
| rosetta3 | research/ml-seq | remote | anc:16e9965184bca9ec030fdaf555de9ef00cb3deaa<=origin/main | delete | ok |
| rosetta3 | (consolidate-rosetta3) | worktree | own temp detached, clean | git worktree remove | ok |

*Note: The cov/vex-modern tag row appears twice because the tag step re-verified an existing tag (it is one tag).*
