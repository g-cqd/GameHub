# Mac gaming development: consolidated knowledge

**14 October 2026.** This synthesis connects the project reports without treating every historical draft as a separate milestone. It is a guide to the collected evidence, not a claim that every archived version was reread or that every listed game was retested today. The [full F1 24 handoff](/Users/gc/Desktop/EAAC-macOS-full-game-handoff-20261014.md) carries the current anticheat detail.

## The stack and why each project exists

The running-game stack has distinct jobs. Wine supplies Windows interfaces and process behavior; Apple's Rosetta runs the x86_64 Wine and game code on Apple Silicon; x87sidecar handles old Intel floating-point sequences; mtld3d translates Direct3D 8/9 work to Metal; DXMT serves Direct3D 11 games; and the native wrappers and GameHub manage prefixes, libraries, runtime selection, settings, and packaging. The [nfs-macos developer handoff](/Users/gc/Developer/nfs-macos/docs/DEVELOPER-HANDOFF.md) states this division for the shipped game wrappers. [rosetta3](/Users/gc/Developer/rosetta3/README.md) is a separate Rust x86-to-AArch64 translator research project; its own README says milestone M0 does not yet run a guest program end to end. It is not the Rosetta used by the current Wine runtime.

## What has actually worked

mtld3d's [game matrix](/Users/gc/Developer/mtld3d/docs/GAMES.md) records playable Direct3D 9 paths for titles including World of Warcraft, Half-Life 2, Far Cry 2, and Need for Speed: Most Wanted (2005). Its [status document](/Users/gc/Developer/mtld3d/docs/STATUS.md) also names incomplete Direct3D 8 behavior and renderer divergences; a listed game is evidence for that tested path, not complete API compatibility. The [27 September wrapper handoff](/Users/gc/Developer/nfs-macos/docs/DEVELOPER-HANDOFF.md) records earlier Most Wanted gameplay and two newly notarized, stapled Most Wanted editions. It separately says the new Call of Duty 4 bundles reached archive and renderer loading, while a campaign gameplay check and notarization remained open at that snapshot.

The [11 October GameHub status](/Volumes/ExT2/GameHub/STATUS-20261011.md) records user-confirmed Battlefield 4 and Need for Speed (2015) launches from the shared EA setup. It also records an EA library consolidation and runtime changes, including Wine fullscreen behavior, DXMT buffer render-target views, and a Wine font-list cache. These are dated observations from that session; they do not prove that every title still works after later runtime changes. The [DXMT buffer RTV report](/Volumes/ExT2/GameHub/work/dxmt-rtv/20261011-1515/README.md) explains the BF3/4 failure and its hidden-texture workaround, including the important limitation that rendering does not write back to the original buffer.

## Performance knowledge and limits

The [x87sidecar Most Wanted experiment](/Users/gc/Developer/x87sidecar/docs/NFSMW.md) measured a faster native boundary for normal, zero, and mixed inputs on its stated M1 benchmark, while its special-value case became slower. The report explicitly says this is a boundary measurement, not an FPS result or proof of native 80-bit arithmetic equivalence. The GameHub status records a Wine font-list cache reducing a repeated EAGEP startup cost after a cache hit; that result addresses a process startup race, not game frame rate. Preserve each benchmark's workload, baseline, and regression when comparing newer builds.

## Where the work stops today

The current [F1 24 anticheat handoff](/Users/gc/Desktop/EAAC-macOS-full-game-handoff-20261014.md) says full protected gameplay is **not achieved**. The last observed EA Desktop attempts ended at `E111000D`; no `F1_24.exe` process was observed, and genuine anticheat service/driver readiness has not been established. Wine syscall and unwind fixes now pass focused and broader virtual tests, but those tests establish Windows interface behavior only. Job 475 (fb185cd9…) was subsequently deployed and tested, and one controlled EA Desktop launch on it (run-475) again returned E111000D with no F1_24.exe. The missing driver file and possible later D3D12 need are concrete investigation topics, not proven causes of the current error.

The projects therefore answer different questions. mtld3d and DXMT evidence concerns rendering paths; x87sidecar evidence concerns translation and numeric behavior; Wine evidence concerns Windows process/API compatibility; GameHub and wrappers concern repeatable installation and launch; the EAAC report concerns a protected title's service and process chain. Success in one layer does not establish success in another. The most useful next evidence for F1 24 is a controlled EA Desktop launch tied to the exact runtime hash, source state, process/service timeline, and visible error, as specified in the current handoff.

## Source catalog

The [collection entry](/Users/gc/Desktop/Mac-Gaming-Development-Reports-20261014/START-HERE.md) points to the offline searchable copies and the portable manifest. Its Git history remains supporting provenance; this synthesis is the short reading path. The collection's discovery note records excluded raw logs, generic dependency documents, inaccessible directories, and the limits of its search.

## Sharing hygiene (review finding D6, 2026-10-14)

- The report collection this synthesis draws on (the ~1,729-document archive) is permissioned privately (0700 directories / 0600 files) and a secret-pattern scan found no clear leaked credentials, but the documents leak local machine layout: home-directory/user names, absolute paths under /Users/... and /Volumes/ExT2/..., and paths that are inaccessible from other machines. Some documents also exist as duplicate-named copies that the manifest does not reconcile.
- Before any external sharing (of this synthesis, the archive, or excerpts), scrub local paths and usernames (e.g. replace with placeholders like `<HOME>` and `<EXT_VOLUME>`), and reconcile duplicates.
- Raw `/tmp` log/token dumps from the EAAC runs are more exposed than the curated archive and must never be shared; keep both the archive and the /tmp dumps private regardless.
- This is a documentation note only: the archive itself has not been edited or scrubbed.
- Source: /Users/gc/Desktop/EAAC-FULL-REVIEW-20261014.md, section 6, finding D6.
