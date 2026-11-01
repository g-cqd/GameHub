# GameHub: project white paper

These are the rules the project runs on. **Read this at the start of every work session, whoever does the work: the
owner, an agent or a contributor.** If a session can't follow one of these rules, it stops and either fixes the rule
or asks for the change in writing. It never carries on quietly.

GameHub plays the owner's Windows games on an Apple Silicon Mac. The games come from Steam, EA, Ubisoft, Epic or a
plain folder. Everything runs from one Wine prefix, with one runtime built from our own forks:

| Fork | Role |
|---|---|
| `g-cqd/wine` | The base. |
| `g-cqd/dxmt` | Direct3D 10/11 on Metal. |
| `g-cqd/mtld3d` | Direct3D 8/9 on Metal. |
| `g-cqd/x87sidecar` | x87 maths under Rosetta for 32-bit games. |

This document says what "working" means and how a change is allowed to get there. The records that apply it live
beside it:

- [`adr/`](adr/): decisions, with their evidence.
- [`roadmap/`](roadmap/): work items, each with a "done when".
- [`diary/`](diary/): what happened, day by day.

`docs/` describes how the hub works today. `development/` records how it got there and where it is going.

## The aim

**Any game the owner has, from any store, starts from one place and plays as if it were native.** It should be
smooth, show the right display mode, play its audio, take its input, and need no per-game ritual. This aim is the
test for every change.

Four properties follow from it, and they bind every component.

**Generic first.** A fix is made so that it applies to every game that has the same problem, never only to the game
where it was found. A fix that only one program needs is written as a rule in `runtime/hub-rules.txt`, matched by
exe name, company or PE section (ADR-0006). It is not a branch in the launcher, a wrapper script or a patched game
file.

**One of everything.** There is one prefix (ADR-0001), one runtime serving it (ADR-0004, ADR-0009), and one Steam,
one EA app, one Ubisoft Connect and one Epic launcher, all installed in that prefix. There is one `main` branch per
fork (ADR-0003). When there are two copies of anything, they drift apart, and the drift costs more than the
duplication saved.

**Parity with Windows.** A game has the same modes, settings and online play as on a PC, even when that means
presenting a PC's identity to a game that never considered Macs (§5, ADR-0014).

**Native and nearly invisible at run time.** Anything that runs while a game runs goes into the forks themselves
(C, Rust, Swift, assembly), where it costs least. It is not a script or a polling helper. The launcher only prepares a
session and starts it; it does no work while the game plays.

## 0. The evidence rule

> **Every claim is backed by something observed before it is acted on. There is no place for an assumption.**

**A claim** is anything stated as fact about:

- a game
- a store client
- Wine, Metal or Rosetta behaviour
- a log line
- a registry value
- a performance number

If acting on a claim would be expensive to undo, it needs evidence.

**Evidence** is one of:

- a log line, quoted with its path;
- a command and its output;
- a build;
- a static analyzer finding that has been triaged against the source;
- a measurement;
- the owner's own report of what they saw.

A memory of how a launcher "usually" behaves is not evidence, and neither is a confident guess from another session.

**The protocol:**

1. **Name the claim** as a sentence that could be false.
2. **Find the observation that would show it false.** For example: "Wolfenstein II is fully downloaded" is false if
   `content_log.txt` shows bytes still to download, so read `content_log.txt`.
3. **Record the result.** Small results go in the diary. A result that decides something goes in an ADR.
4. **Act only then.** A claim with no evidence is written down as an open question, never as a fact.

**Reference first.** When a known-good integration exists (CrossOver's runtime, an earlier hub runtime, a working
bundle), reproduce it unchanged before building anything, then change one variable at a time against it. Don't
assemble a stack from parts and debug the symptoms. After two experiments that don't change the outcome, stop and
look for the reference (diary 2026-10-31-07).

**Unverified is said plainly.** Every report says what was built, what was checked and what was not run. If a game
was not launched, the report says "not launched" and never "should work". If another agent's report claims
something, it is checked before it is repeated (the owner: "check whenever you get answers back from the other guy
instead of telling me it's unverified").

## 1. The owner's games come first

- **Never stop a game the owner is playing.** Before anything that restarts the wineserver (`hub stop`, `--restart`,
  `wineserver -k`, installing runtime files that a running process maps), check `ps` for `.exe` processes. If a game
  is running, wait or ask (ADR-0018).
- **Never edit a runtime file in place.** Remove it, then copy the new one (`rm`, then `/bin/cp -c`). A running process
  keeps the old file's inode, and a file written in place corrupts what that process has mapped (ADR-0008).
- **Leave the owner's machine as it was found.** Delete scratch files the session made, above all screenshots, which
  can show other apps on the owner's desktop. Back up a registry hive before editing it, and only while the prefix is
  stopped.
- **Disk and memory are shared and small.** ExT2 has run at 98–99% full and swap at 6 of 7 GB. Check free space before
  any download, build or copy over a gigabyte. Use all cores for a build only when no game is running.

## 2. Change discipline

- **Everything lands on `main`** of the fork it belongs to, with no long-lived side branches (ADR-0003). Upstream is
  merged in (Wine from `athei/wine cx-26-patched`, DXMT from `3Shain/dxmt`, mtld3d and x87sidecar from `athei/*`).
  Our commits are rebased or merged so that hub-2 is always "every fork's `main`".
- **DXMT commits stay on the fork.** They are not proposed upstream unless the owner decides so.
- **Author:** `Gigi <42325924+g-cqd@users.noreply.github.com>`.
- **One commit per area**, with a message that says what changed and why, in the style of the fork's upstream (Wine:
  `component: Sentence.`).
- **Commit and push** when a change is built and checked. Then say what was built, what was installed into which
  runtime, and what was not run.
- **One agent commits in a working tree at a time** (ADR-0017). Before committing, read `git status` and `git diff`
  and commit only your own hunks.
- **Long builds and servers run as background jobs** and are stopped when no longer needed.

## 3. Verification

The proof that a change works is, in order of strength:

1. **The owner plays the game** and it works.
2. **The game is started** through `hub play` and its log shows the expected path (a DXMT or mtld3d log, a winemac
   mode set, a coreaudio stream format).
3. **A unit or regression test** passes in the fork (Wine `tests/`, DXMT `tests/unit/run.sh`, mtld3d `cargo test`,
   x87sidecar CTest, `launcher/tests`).
4. **Static analysis** shows the finding is gone and nothing new appeared (ADR-0015).
5. **The touched objects build.**

A report names the strongest level it reached. Level 5 alone is never called "fixed". When the owner asks for static
analysis only, the session stops at level 4 and says so.

## 4. The runtime

- **A runtime is assembled, never patched by hand.** `scripts/assemble_runtime.sh` builds it from the fork builds into
  a new directory. The script refuses to write into one that exists. Single files are replaced in a live runtime
  only by rm then cp, and the diary records which files and from which build.
- **Backends live in their own directories** (`lib/wine/dxgi/{dxmt,wined3d}`, `lib/wine/d3d9/{wined3d,mtld3d}`), with
  Wine fake modules in the standard place. A rule or `--dxgi` picks the backend per process, with no copying or
  renaming (ADR-0005).
- **Build trees:**
  - Wine: `$HUB_ROOT/build/wine-ours`, configured only through `build-macos-x86_64.sh`. Don't put llvm-mingw first in
    `PATH`.
  - DXMT: `$HUB_ROOT/build/dxmt/{x64,x32}`, with the cross files from `toolchains/dxmt-cross/` copied to
    `/tmp/dxmt-cross/` first.
  - x87sidecar: `$HUB_ROOT/build/x87sidecar`.
  - mtld3d: through its `Makefile`.
  - In these build trees, use `/bin/cp -c` for APFS clones. The `cp` on `PATH` is GNU coreutils and has no `-c`.

## 5. Parity with Windows

The aim is that a game on the Mac has **the same functionality as on a Windows PC** (ADR-0014). Studios write for
PCs and rarely think of Macs. So we give each game the Windows environment it expects:

1. **Real Windows behaviour first.** Syscalls, kernel interfaces, files, registry and services are implemented
   correctly, because a correct implementation survives game updates.
2. **A Windows PC's identity where a game insists on one.** A game that refuses or degrades because of the Mac's real
   GPU vendor, CPU features, Windows build or Wine markers is shown what a PC would show. The disguise is the
   smallest one that works, set by a per-game rule, with a comment saying what the game checks.
3. **Protection runs as on Windows.** Anti-cheat and DRM are made to run and pass, never stripped or patched out.

**The line is the purpose.** We change what a game believes about the machine, never the game itself, and never to
gain an advantage over other players or to get around ownership.

## 6. Records

- **ADR** (`adr/NNNN-slug.md`): a decision that would be expensive to reverse, with its context, the evidence, the
  options, the decision and its consequences. Its front matter has `status` (`proposed`, `accepted` or `superseded`,
  with `superseded-by`) and `date`. A settled decision is reopened only by new evidence, in a new ADR that supersedes
  it.
- **Roadmap item** (`roadmap/NNNN-slug.md`): one piece of work. Its front matter has `status` (`not-started`,
  `in-progress`, `blocked` or `done`), `blocked-by` and `date`, and it has a **Done when** that can be checked. When it
  is done, it gets a **Result** with the evidence, and it stays in the folder as a record.
- **Diary** (`diary/YYYY-MM-DD-NN.md`): what a session did, found, measured and left open, in prose, with commit
  hashes. Write one entry per working session, before the session ends. Entries before 2026-10-31 were reconstructed
  from the commit history and the session logs, and say so.
- **`docs/`** stays the description of the present. When a roadmap item is done, the doc it concerns is updated in the
  same commit.
