# T3 remaining TO DO (from the Sonnet debugger; all required; report, do not improvise). Worktree /Volumes/ExT2/GameHub/work/wt-hub-b.
1 B3 isSafeDriveTarget (SharedPrefix.swift ~:516): order = absolute + no "."/".." components -> if volumeRoot(of: target) non-nil and !isMounted -> false (BEFORE realpath) -> realpath -> mount check on the real path -> stat is dir.
2 S9 bug: the driveUnreachable sweep (~:318-362) must skip relative link targets (c: -> ../drive_c is validated separately by the cDrive check). Add test: a healthy prefix (c: -> ../drive_c, e: -> existing temp dir, matching updateStamp) returns problems == [] .
3 S13: every "missing link" check (~:395, :422, :463) = lstat fails AND errno == ENOENT (capture errno immediately after lstat).
4 S12: HubConfig.read key check with a dynamic CodingKey struct (`struct Keys: Decodable { let names: Set<String>; init(from d: Decoder) { let c = try d.container(keyedBy: AnyKey.self); names = Set(c.allKeys.map(\.stringValue)) } }`), no JSONSerialization/Any; read loop until EOF or 64 KiB + 1 bytes (handle short reads).
5 Nit: one `readLink(_ path: String) -> String?` helper replacing the four copies; delete dead `resolveAbsoluteTarget` and `shouldPlanDrive`.
6 Tests: problemsDetection asserts the updateStamp MATCH case gives no updateStamp problem (no unused `_problems2`), and an unreadable/non-integer stamp gives `.updateStamp(prefix: nil, runtime: <mtime>)`; plus the healthy-prefix test from item 2.
Done: HubCoreTests green + full swift build. Report item -> file:line, final Test run line.
