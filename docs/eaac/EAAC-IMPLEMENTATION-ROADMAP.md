# EA anti-cheat protected games: implementation roadmap

The user clarified the objective on2026-10-16: run EA anti-cheat protected games
truthfully on this Mac, with F1 24 as the first milestone. A particular driver
filename, kernel architecture or extraction technique is not an independent goal.
Windows machines and VMs are excluded. The actual protection required by the
game must operate; fabricated responses or disabled protection do not satisfy this.

Current evidence and experiment gates: [investigation control](EAAC-INVESTIGATION-CONTROL.md).
Exact experiment inputs/results: [ledger](EAAC-EXPERIMENTS.json).
Agora scope: f124-anticheat. Current documents supersede historical task assumptions.

## Established facts and unknowns

- The real launcher/service still fails initialization with E111000D. Task-90
  advanced one path but did not fix initialization. A source-level syscall
  producer/consumer inconsistency remains a failed deployment gate.
- The installer registers a kernel/minifilter service pointing to eaanticheat.sys.
  Its registration is present through the CurrentControlSet -> ControlSet001 link;
  the expected file is absent in the inspected isolated prefix.
- EA describes Javelin as operating at kernel level in its
  [September2026 update](https://www.ea.com/news/ea-javelin-anticheat-2026-update).
  Kernel protection is documented architecture, not an invented possibility.
- We have not established that the missing file causes the current initialization
  failure, which exact kernel operations this title/build requires, or that
  manually recovering that filename must precede fixing startup.
- No evidence establishes a genuine driverless protected-game mode. Changing
  investigation order does not establish that kernel protection can be omitted.
- Driver writer search E-015 exhausted two static queries without a validated
  writer/byte-source anchor. This is unresolved, not proof of absence.

## Active path: follow demonstrated failures

| Task | Deliverable | Acceptance evidence |
| --- | --- | --- |
| task-7, completed capture | Preserve the reproducible failing initialization path. | Correct module identity/base, process correlation and pre-dialog failure evidence; reuse captures rather than repeat the baseline. |
| task-9 | Inventory observed startup operations and identify the earliest causally established failure. | Each operation/status has an evidence pointer. Separate fatal reporter from initiating condition; distinguish Wine contract defect, unsupported host requirement and unknown target predicate. No assumed driver dependency. |
| task-10; after9 | Implement one causally established Wine compatibility defect. | Root cause in one sentence; regression fails before/passes after; genuine startup advances with actual results; relevant contract behavior remains correct. |
| eaac-syscall-evidence-gate, currently failed | Validate syscall encoding/dispatch consistency before deployment. | Generated stub numbers round-trip through the same profile; foreign-call profile is explicitly supported rather than guessed. A failed gate stays failed until repaired and revalidated. |
| task-17; after7,10 and syscall gate | Integrate evidenced startup repairs with genuine EA anti-cheat. | Genuine components perform observed required operations; initialization progresses; no success-only replacement or fabricated attestation. Add any newly demonstrated component requirement as a concrete prerequisite. |
| task-18; after17 | Verify authenticated F1 24 gameplay and genuine anti-cheat operation. | Ordinary EA launch reaches a playable session with evidence that required anti-cheat operations remain active and accepted by the normal game flow; clean exit/relaunch. Gameplay alone is insufficient. Report anything not observable. |

The next investigation concerns the actual E111000D selection condition after
partial syscall advancement, not another installer run or compression guess.
A speculative syscall mapping is not a valid deployed fix. Preserve the production
EA session, game and runtime; experiments use isolated state and exact revisions.

## Conditional component work

Historical task-8 and tasks11–16 assumed mandatory driver acquisition and a chosen
kernel/minifilter architecture before those requirements had been demonstrated.
Those queue items are superseded as unconditional work; their technical evidence
is retained. Requeue narrowly when an observed game/anti-cheat operation or a
validated contract makes the requirement concrete. Cancellation does not prove
that a driver or those APIs are unnecessary.

If the genuine flow requires the driver, acquisition/provenance, imports, execution
backend, filter lifecycle, communication and required device requests become
explicit tasks with tests and evidence. No fake handles/statuses/handshakes.
If another genuine flow is discovered, demonstrate its required protection and
normal game acceptance; do not infer support from a window or absence of errors.
Unknown requirements stay unknown. No claim of eventual feasibility is made.

## Lean execution and completion

Apply the control document's phase budgets:15min evidence selection,45min/two
focused static queries,20min/two bounded launches,10min decision. Every experiment
has discriminating predictions and a semantic endpoint before execution. Unknowns
at deadlines remain unresolved. Repeats require new evidence or a demonstrated
measurement defect. Use Agora work_run/work_wait for builds/tests/experiments.

Implement only one observed behavior per change. Use Wine's existing C test
infrastructure, focused debug build/tests and relevant integration checks. No
build for documentation; no unchanged rebuild or launch. No Windows reference is
a prerequisite. Do not claim protected gameplay, genuine protection or performance
without measured evidence. The user objective remains unachieved.
