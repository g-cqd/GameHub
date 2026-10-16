# EAAC investigation control — 2026-10-16

This is the current investigation entry point. The roadmap describes the eventual
outcome; historical handoffs do not describe current completion. Agora carries
ownership and dependencies. This file carries evidence limits and decision rules.
The user clarified the objective: EA anti-cheat protected games running truthfully,
with F1 24 as the first milestone. Genuine required protection must operate;
manual recovery of a specific driver filename is not an unconditional dependency. Windows
machines and VMs are excluded by the user. No completion or delivery date is known.

Recovered install path: [static chain and registry correction](EAAC-INSTALL-PATH-20261016.md).

First execution block: [decisions and measured job costs](EAAC-BOUNDED-BLOCK-20261016.md).
Syscall deployment gate: [failed consistency check](EAAC-SYSCALL-GATE-20261016.md).

## Evidence audit

| Claim | Defensible conclusion | Evidence and correction |
| --- | --- | --- |
| Initialization was repaired by task-90. | Execution advanced; initialization still fails. | Commit 0413180984c; archived task90-test2.log:3712,3976,4311. A second raw syscall occurs, then E111000D at 00457425. Task-90's done state is historical partial progress, not proof of its full acceptance criteria. |
| Raw 0x101 always means NtGetNextThread here. | Rejected for the Win10 profile; unconditional alias removed in E-024. | Signed Microsoft kernel10.0.19041.5794 maps0x101 to NtInitializeRegistry and supports C000000D for capturedD8F0. Six invalid-flag cases fail before removal and pass afterward. EAAC fatal causality remains unresolved. See EAAC-NATIVE-REFERENCE-20261016.md. |
| Changing the fourth return value resolves the failure. | Refuted for the sampled values and captured state. | Jobs 60/62/82 still reach error callback arguments. Job 86 proves a comparison, not that it is the sole failure predicate. Do not repeat the status sweep without changed evidence. |
| Offline replay establishes native behavior. | It establishes a bounded path through captured state under supplied syscall results. | Job 82 matches 16 registers and next RIP for three continuations. It then stops at uncaptured callback-table memory. The replay script prints incomplete stops and catches UcError without failing its process. Require semantic markers, not exit zero. Snapshot contents outside checked reads are not universally validated. |
| Resources 10100/10150 contain the driver. | Unknown; their content and role are unidentified. | Resource inventory and jobs 73/76 establish opaque bytes and bounded unsuccessful scans/decoding. My earlier recommendation to extract a driver from them was too specific. First prove which code consumes them and why. |
| No embedded PE means no bundled driver. | Unsupported. | Job 73 finds only outer PE headers in its scanned files. Transformed payloads and other acquisition paths are not excluded. |
| Missing minifilter functions cause today's error. | Stubs exist; causality and required subset are unknown. | Current wine/dlls/fltmgr.sys/main.c:60–79 still returns dummy handles/success. No recovered driver establishes its actual imports; no captured call ties these stubs to the current fatal path. |
| A loader/minifilter implementation will make this work. | Feasibility remains unknown. | Genuine driver execution, host protection coverage and any required integrity/attestation semantics are unproved. Do not treat the implementation roadmap as evidence of feasibility. |
| Captures must be collected again. | Existing core artifacts are reusable. | All nine continuation-manifest files matched size and SHA-256 on 2026-10-16; evidence-integrity-audit-20261016.json records the check. Old partial service dump is superseded by complete-module capture. |

Private evidence root: /Users/gc/eaac-archive/eaac-acquisition-20261015.
Job logs: /Users/gc/.agora/work/logs/job-N.log. Logs can expire; preserve decisive
minimal excerpts and artifact hashes in the private archive before relying on them.
The task90 log is now archived there instead of relying on /tmp.

## What changes now

Use one active question and one owner. Do not start another tool installation,
VM, alternate debugger, full decompilation, or kernel implementation merely because
the current question is difficult. A tool change needs a named missing observable
and a cheaper path that has been ruled out. Tool repair gets at most 15 minutes;
then use the working CLI/static artifacts or record the observation as unavailable.

A result is one of: observed, derived with stated premises, refuted within a named
boundary, or unresolved. Never remove premises to make a conclusion sound stronger.
Unknowns do not become facts at a deadline. Operational choices and budgets below
are policy choices, not measured speed improvements. No speedup is claimed yet.

Before any experiment, append a record to EAAC-EXPERIMENTS.json with:

- A unique ID, parent task, owner, question and competing explanations.
- Exact input hashes, source/runtime revision, prefix and command or analysis query.
- One changed variable and predictions that distinguish the explanations.
- A semantic pass/fail predicate, capture endpoint and maximum runtime/output.
- Existing evidence searched, prior experiment IDs and why this is not a duplicate.
- A wall-clock deadline and the decision to take for each possible outcome.

Registry absence checks must resolve serialized symbolic links/control-set aliases
and account for implicit parent keys before proposing a missing-key cause.

Missing any item means no execution. No production prefix, game or runtime changes
as experiments. Use Agora work_run/work_wait for tests/builds/captures and the
show/accept digest gate for queued commands. Keep credentials out of shared output.
A tool timeout is not a hypothesis refutation. A wrapper success is not target success.

After each experiment, record actual duration, exit/signal, semantic result,
evidence path/hash, conclusion boundary, remaining unknown and the next decision.
Update the same record, then publish one concise Agora reply. Do not create another
handoff that restates the full history. Corrections explicitly supersede earlier claims.

## Phase budgets and stop conditions

These are maximum investigation budgets per question, not promises of resolution.
Count wall time, including setup, retries and queue waits. Long jobs must enforce
their own deadline; a work_wait timeout alone does not stop a running job.

| Phase | Limit | Required output / stop condition |
| --- | --- | --- |
| Evidence selection | 15 min | Reuse exact matching artifacts and choose a discriminating observation. If unavailable, name the missing artifact; no broad new capture. |
| Static analysis | 45 min; two focused queries | Identify the relevant consumer/branch or report the exact unresolved indirect edge. No repeated whole-image analysis. |
| Runtime observation | 20 min total; two launches maximum | One bounded baseline if existing evidence cannot serve, then one changed-variable run. Stop at the first discriminating event. Default capture 30 s, hard maximum 120 s and 16 MiB log; larger limits require a written reason before execution. |
| Decision | 10 min | Supported/refuted/unresolved; evidence and scope; one next question. No third launch to avoid writing an unresolved result. |
| Implementation, after causal gate | One reviewable behavior; one focused build/test cycle | Root cause in one sentence with evidence; regression fails before and passes after; original reproduction advances with genuine results. Fix all diagnostics before one rebuild. Two failed fix cycles stop implementation and reopen diagnosis. |
| Integration | One bounded run after a relevant change | Require evidence of actual required anti-cheat operations, then normal game flow. Driver/callback evidence is required where that component is established as necessary. Stop at first failure; do not repeat unchanged launches. |

An unresolved question leaves the execution lane at its deadline. Keep it tracked
with its exact missing observable; choose a different discriminating method or a
separate runnable question. A retry requires new input, a changed measurement, or
correction of a demonstrated instrumentation defect, plus the prior record ID.
After two no-information experiments, stop the approach and re-derive the model.
No fixed sleep, no unbounded logging, no speculative success returns.

## User clarification and architectural evidence

The previous control treated driver acquisition as the oldest mandatory
prerequisite. The user challenged that premise on2026-10-16. It is superseded.
The installer/kernel-service evidence establishes an expected driver architecture;
EA's September2026 update also states that Javelin operates at kernel level:
https://www.ea.com/news/ea-javelin-anticheat-2026-update.
This does not identify the cause of the current fatal error, prove that the exact
missing filename must be manually recovered first, or prove a driverless mode.
Follow actual required operations, preserving genuine protection. No invented
handshake, success response, disabled protection or unsubstantiated protected-game
claim is acceptable. Kernel/API work becomes mandatory only where its requirement
is established; it is not ruled out merely because it is difficult.

## Immediate sequence and feasibility gates

1. Validate the task-90 evidence boundary before any deployment. Separate the
   output-handle safety fix from the profile override; identify the profile rule
   and the next actual failure predicate. Reuse existing captures first. Do not
   rerun return-value sweeps or conclude that a new fatal address is a repair.
2. Inventory actual startup operations and the earliest causally established failure
   under task-9. Distinguish an API contract violation from an error reporter and
   from an unresolved target predicate. No new launch without a missing observable.
3. Implement one proven contract defect under task-10, with failing/passing
   regression evidence. Do not guess success values or remove anti-cheat checks.
4. Add driver acquisition or kernel/minifilter/backend work only for a demonstrated
   requirement. Recover provenance and establish semantics before implementing it.
   Driverless operation is also an unproved hypothesis, not a chosen solution.
5. Integrate through the normal genuine flow and verify gameplay with required
   anti-cheat behavior. Passing initialization or seeing a game window alone is
   insufficient. Record protection/acceptance evidence and any observability limit.

Historical acquisition/kernel queue assumptions are superseded by the current
roadmap. E-015's two-query static writer search is closed unresolved; do not repeat
it on the same inputs. Work on one discriminating question at a time.

## Lean verification and reporting

Reuse one research checkout, runtime and prefix per artifact family. Record their
identity; do not rebuild unchanged code. Use filtered channels and bounded probes.
Do not recapture a complete module for a question about one missing stack range.
For deterministic static facts, one checked observation suffices. Repeat only for
a declared nondeterminism question; then report the sample count and outcomes.
Use focused tests for the changed behavior; run integration after relevant changes,
and broader tests only for the affected compatibility surface or final landing.

Every 90-minute investigation block must end with an evidence-backed decision,
including unresolved. Report questions resolved, hypotheses eliminated within
scope, duplicate runs prevented, builds/launches, active/queue time and whether the
next genuine execution milestone advanced. More logs, agents, tools or commits
alone are not progress. Compare these measurements over the next three blocks
before claiming this process is faster.

This protocol is a required review gate, not an automatic execution sandbox.
The agent must apply it before launching work; Agora currently does not enforce
these semantic checks. No new framework or test harness is introduced for policy.
