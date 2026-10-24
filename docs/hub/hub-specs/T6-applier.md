# T6: OverlayLedger + FixApplier (offline, transactional, reversible) (spec; report, do not improvise)
Depends on T1a/T1b, T3, T4a (WindowsPath, registry reader). Files `Sources/HubCore/Apply/{OverlayLedger.swift, FixApplier.swift, HiveEdit.swift}`,
tests `Tests/HubCoreTests/FixApplierTests.swift` (+ move the FakeWineServer helper out of InstanceTests.swift into `Tests/HubCoreTests/Support/FakeWineServer.swift`, internal).
Read before writing: Sources/LauncherCore/{FileTransaction.swift, FileChange.swift, RegistrySetting.swift, RegistryHiveText.swift, ConfigText.swift}; reuse them.
Swift 6, `package`, typed throws HubError, no force unwraps / try! / DispatchQueue; blocking API documented "call off the main actor".

## OverlayLedger (`paths.ledger`, JSON lines of LedgerEntry, append-only)
`init(url:)`; `func entries() throws(HubError) -> [LedgerEntry]` (file regular, not symlink, <= 16 MiB; a malformed line -> `.invalid("ledger line N")`);
`func append(_ e: LedgerEntry) throws(HubError)` (open O_WRONLY|O_APPEND|O_CREAT|O_NOFOLLOW, mode 0600, one line + "\n", fsync);
`func owner(of key: LedgerKey) throws(HubError) -> (fix: String, value: String)?` = latest non-reverted entry for that key. `LedgerKey` = "<kind>|<target-specific id>"
(registry: `reg|<hive>|<lowercased key>|<lowercased name>`; file/ini/xml: `file|<host path>[|section|key or |element|attribute]`; drive: `drive|<letter>`).
Revert is recorded as a new entry with `after == before` and `fix` = "revert:<fix>".

## FixApplier
`init(prefix: SharedPrefix, paths: HubPaths, knowledge: Knowledge, ledger: OverlayLedger)`.
`func isSatisfied(_ p: PendingAction) throws(HubError) -> Bool`: registry -> current value equals desired (minimal reader from T4a); dllOverride(exe) -> HKCU
`Software\Wine\AppDefaults\<exe>\DllOverrides` value `<dll>` equals mode (disabled -> ""); window retina -> HKCU `Software\Wine\Mac Driver` RetinaMode "Y"/"N";
window virtualDesktop -> HKCU `Software\Wine\AppDefaults\<exe>\Explorer` Desktop == exe base name AND `Software\Wine\Explorer\Desktops` <name> == size;
file -> destination sha256 equals; ini -> ConfigText value equals; xmlAttribute -> attribute equals; drive persistent -> link readlink equals target;
drive session, companion, prerequisite -> false (not the applier's business; report "handled at launch"/"needs install step").
`func apply(_ actions: [PendingAction], target: String) throws(HubError) -> ApplyReport` (`ApplyReport { applied: [String]; skipped: [String]; conflicts: [String] }`):
1 refuse `.blocked("the Wine server is running; stop the providers first")` if `prefix.serverRunning`.
2 for each action not satisfied: conflict check: ledger owner of the key is a different fix with a different value -> conflict entry, skip; for file actions,
  an existing destination whose sha256 is neither the original `before` hash recorded by this fix nor missing -> "user-modified", conflict, skip.
3 write via FileTransaction (backups under `paths.state/backups/<UUID>`), then append a LedgerEntry {time, fix: owner, target, action, before (old value or
  backup path or nil), after (new value / sha256), backup}.
Registry writes: build a hive part with RegistrySetting(hive:path:name:value:kind:) entries and `RegistryHiveText.merged(hive:part:)`; values with Windows
paths use kind windowsPath when the setting is a path. Write the whole new hive file through FileTransaction (never in place).
`func revert(fix: String, target: String) throws(HubError) -> ApplyReport`: same server check; replay this fix's ledger entries newest first: restore `before`
(delete the value if before is nil; restore file backups byte-for-byte); append revert entries.
## Tests (>= 14, temp prefix with minimal system.reg/user.reg (`WINE REGISTRY Version 2` header + `#arch=win64`), FakeWineServer for the running case)
registry apply -> value present + ledger entry; apply again -> no write (file mtime unchanged) and no new ledger line; revert -> hive bytes identical to before;
conflict between two fixes on one value; server running -> blocked and nothing written; dllOverride -> AppDefaults key; retina; virtual desktop pair; file asset
copy + second apply no-op + user-modified destination -> conflict; ini set + revert; xmlAttribute set + revert; drive persistent link; malformed ledger line rejected;
ledger file symlink rejected.
## Done: build + HubCoreTests green. Report files, counts, deviations.
