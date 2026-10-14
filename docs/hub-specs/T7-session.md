# T7: one Session runner for providers and games (spec; report, do not improvise)
Depends on T3, T4a/T4b (LaunchPlan with stages/hostCommand), T6 (isSatisfied). Files `Sources/HubCore/Session/{SessionController.swift, Probes.swift,
LogWatch.swift, SessionRecord.swift}`, tests `Tests/HubCoreTests/SessionTests.swift`. Swift 6: `package actor SessionController`; all I/O inside the actor or
nonisolated helpers; polling with `try await Task.sleep(for: pollInterval)` honouring cancellation (no DispatchQueue, no Thread.sleep).
## Injected seams (protocols, Sendable)
`ProcessStarter { func start(argv: [String], environment: [String: String], directory: URL, log: URL) throws(HubError) -> Int32 }` real impl:
LauncherCore `ProcessCommand(executable:arguments:directory:environment:).start(output:)` with the log opened O_APPEND|O_CREAT|O_NOFOLLOW 0600 under paths.logs.
`SystemProbe { func running(_ names: [String]) -> Set<String>; func portOpen(_ port: Int) -> Bool; func serverRunning(_ prefix: URL) -> Bool; func now() -> Date }`
real impl: PrefixActivity.running / a non-blocking TCP connect to 127.0.0.1 with 300 ms timeout / PrefixActivity.serverIsRunning / Date().
`WineServerControl { func kill(_ prefix: URL, wineserver: URL, environment: [String: String]) throws(HubError) }` real impl: LauncherCore WineShutdown.stop.
## SessionRecord (`paths.session`, JSON, written atomically under SessionLock at `paths.state/session.lock`)
{ runtimeID, manifestSHA256, sessionProfile: [String: String], providers: [String: Int32], game: {target, pid, leaseTarget}?, startedAt }.
## LogWatch
Tracks per log file: offset of the last `startMarker` occurrence seen (start of the current run), and for each ReadinessEvent/Probe.log the latest matching
line after that offset plus the time the Hub first observed it (for holdSeconds). Reads only appended bytes (keep offset; if the file shrank, restart at 0);
reads at most 4 MiB per poll; lines split on "\n"; invalid UTF-8 replaced. Pure function `evaluate(events:, observations:, now:) -> ProviderState?` = state of
the latest matching event whose hold has elapsed.
## SessionController API
`init(paths:, prefix: SharedPrefix, runtimeID:, manifestSHA256:, starter:, probe:, server:, applier: FixApplier, pollInterval: Duration = .milliseconds(500))`
`func status(_ target: String, plan: LaunchPlan) -> TargetStatus` (no side effects): blocked if paths.root volume missing ("game drive not connected"),
notInstalled from plan.state, else process presence (recipe processes from the plan's knowledge) + readiness evaluation -> stopped/starting/needsSignIn/ready/failed;
games: running when leaseTarget present.
`func start(_ plan: LaunchPlan) async throws(HubError) -> TargetStatus` (Mode.start plans):
 1 refusals non-empty -> throw `.blocked(refusals.joined("; "))`. 2 SharedPrefix problems containing driveUnreachable -> blocked. 3 server running and no
 SessionRecord -> `.blocked("the prefix is in use by another app (for example a game wrapper); quit it first")`. 4 record exists with another manifestSHA256 ->
 blocked("runtime mismatch"). 5 record exists and target is a provider already running -> return status. 6 record exists with a different sessionProfile for
 overlapping keys -> blocked("restart <provider> to apply: <keys>"). 7 every pendingAction not companion/session-drive must be `isSatisfied` else
 blocked("apply fixes first: <owners>"). 8 provider lease file `leases/provider-<id>.json` via LauncherCore GameLease(url:).check()/record(process:).
 9 start hostCommand via starter (directory = paths.temp, log = paths.logs/<target>-<yyyyMMdd-HHmmss>.log); write SessionRecord.
 10 run client-scope stages in order: poll until all passWhen probes hold -> next; any failWhen holds -> state (needsSignIn when the failing probe is the
 signed-in stage's awaitingAuthentication hold, else failed) with reason "stage <id>: <probe>"; timeout -> failed "stage <id> timed out". Append each stage
 outcome to paths.runs/<target>.jsonl {time, stage, outcome, detail}. 11 companion pending actions (after: ready) start with the same environment
 (argv [wine, providerRoot\<exe>]) and wait their readiness bounded by timeoutSeconds; failure -> warning in the returned status reason, provider stays ready.
`func launchGame(_ plan: LaunchPlan) async throws(HubError) -> TargetStatus` (Mode.launchGame): game lease `leases/game.json` (a running game -> blocked
 "<other> is running"); ensure provider ready (start it with the provider plan passed in `providerPlan:` parameter if not running); session drives created
 (symlink in dosdevices, recorded for removal); run hostCommand; then game-scope stages; leaseTarget seen -> running; record game in SessionRecord.
 A background monitor task polls until leaseTarget disappears, then clears the lease, removes session drives, updates the record.
`func stop(_ target: String, plan: LaunchPlan) async throws(HubError)`: provider: if it is the only provider and no game -> WineServerControl.kill, remove the
 SessionRecord; else run `wine <exe> <stop.arguments>` when given, wait up to 10 s, then `wine taskkill /IM <name>` per stop.taskkill name, then `/F` after 10 s.
`func stopAll() async throws(HubError)`: kill server, clear record, leases, session drives.
## Tests (>= 16, fakes + temp dirs, pollInterval 5 ms, timeouts small)
start EA plan -> ready when the fake writes "[STARTUP]" then "-> authenticated" to the temp log and ports report open; needsSignIn after a 20 s-equivalent hold
(inject now()); failed on "LaunchFailed"; timeout; foreign server (FakeWineServer, no record) -> blocked; runtime mismatch blocked; profile mismatch blocked;
unsatisfied pending action blocked; refusal blocked; volume missing blocked; second game blocked; launchGame records the game, monitor clears the lease when the
process disappears; session drive created and removed; stop last provider calls kill and removes the record; stop with two providers uses taskkill argv;
companion failure is a warning; runs jsonl has stage outcomes; LogWatch handles truncation and partial lines.
## Done: build + HubCoreTests green. Report files, counts, deviations.
