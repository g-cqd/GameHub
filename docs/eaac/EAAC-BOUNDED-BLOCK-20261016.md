# First bounded investigation block — 2026-10-16

## Decisions

E-001 failed the deployment gate: Win10 stub encoding and the shared 0x101 dispatch
override disagree. See EAAC-SYSCALL-GATE-20261016.md. Correct foreign profile
selection and the remaining fatal predicate are unresolved. No production changes.

E-002 closed the four-byte literal resource-ID scan: no 10100/10150 literals in
executable sections of the correctly based service capture. The capture hash is
ed84fa5a5b24c6bdcf5f0d34c93eedbf9fcd38fdd2fe689c45356984cad940eb.
Job-97 executed for 0.9 seconds. Computed IDs and custom parsing are excluded from
coverage; do not rerun this scan on the same image.

E-003 observed 890 resource trace events before a standalone service fatal at
00CB7DC5, with no opaque-ID requests. Job-98 executed for 6.3 seconds. This is a
different fatal location from the earlier 00457425 capture; no same-stage comparison
is claimed. No new consumer was identified. The observer externally stopped its
owned process; target return -9 is not success. No unchanged standalone rerun.

E-004's installer observation recorded 1425 resource trace events: RCDATA102
from the installer and RCDATA10001 twice in a child. Job-99 executed for 11.2 seconds
but failed with PermissionError in group cleanup. Target exit status and final
endpoint were not preserved, so absence of opaque-ID events is only a partial-log
observation. Subsequent process inspection found no remaining EAAC target.
The wrapper now checks child exit before group cleanup and preserves cleanup
errors in its summary. This correction has not been revalidated by another launch;
the two-launch budget is exhausted. Do not report the installer run as successful.

## Cost and next decision

Zero builds, two target launches, one static inventory job. Scheduler-reported
execution times total 18.4 seconds; reported capacity waits total 0.1 seconds.
These numbers exclude source review, preparation and reporting; they are not a
measurement of total investigation effort or a speedup claim.

No driver was recovered. Literal scanning and these startup resource API traces
do not establish the opaque resources' role. Another identical service/installer
run will not answer it. The next acquisition question must inspect an actual
consumer or custom resource parser, or trace a distinct evidenced acquisition
entry point. No compression guessing, no whole-module recapture, no third launch.

The isolated installer may replace research-prefix service files as part of its
normal installation; it does not touch the production prefix. Preserve captured
hash identities rather than assuming that the research prefix is immutable.

Evidence and exact input hashes: EAAC-EXPERIMENTS.json. Reproducible analysis tools:
research/eaac/resource_id_consumers.py and observe_resources.py. These are retained
research tools, not product code. Runtime-wrapper cleanup correction remains
unverified; no broader tests or builds were warranted for this evidence block.
