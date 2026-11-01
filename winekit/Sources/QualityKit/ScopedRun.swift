import Foundation

extension Quality {
    /// The files `hook` changes in the package.
    func changeSet(for hook: Hook) throws -> ChangeSet {
        var base: String?
        if hook == .prePush {
            let upstream = try runner.run(
                "git",
                ["rev-parse", "--verify", "-q", "@{upstream}"],
                in: workspace.root,
                echo: false
            )
            base = upstream.succeeded ? upstream.output.trimmed : nil
        }
        let diff = try runner.run("git", ChangeSet.gitArguments(for: hook, base: base), in: workspace.root, echo: false)
        guard diff.succeeded else { throw QualityError.unavailable("git diff failed: \(diff.errors.trimmed)") }
        return ChangeSet(files: ChangeSet.paths(fromGitOutput: diff.output), libraryTargets: libraryTargets)
    }

    /// Every gate, scoped to what `hook` changes: format and lint read only the changed Swift files; the analyzers read
    /// the whole package and report only those files; mutation testing mutates only the changed library sources. The suite
    /// runs whole (it takes a second), in release too before a push.
    func runChanged(_ hook: Hook) throws {
        let changes = try changeSet(for: hook)
        guard !changes.isEmpty else {
            reporter.note("[OK] \(hook.rawValue): no change to the package")
            return
        }
        if changes.manifestChanged { try run(.manifest) }
        if changes.files.contains(where: { Workspace.configs.contains($0) }) { try run(.config) }
        if hook == .preCommit { try aemiScript("check-tags.sh", ["staged"], failure: "tags") }
        let swift = changes.swiftFiles
        if !swift.isEmpty {
            try format(swift, recursive: false)
            try lint(swift)
            let list = workspace.scratch.appendingPathComponent("changed-files")
            try helper("mkdir", ["-p", workspace.scratch.path], failure: "could not create \(workspace.scratch.path)")
            try fileSystem.write(Data((swift.joined(separator: "\n") + "\n").utf8), to: list)
            try analyzers(onlyFrom: list)
            try test(release: hook == .prePush)
        }
        if changes.librarySources.contains(where: { path in
            Workspace.embeddedTargets.contains { path.hasPrefix("Sources/\($0)/") }
        }) {
            try embedded()
        }
        if changes.touchesDifferential { try differential() }
        if !changes.librarySources.isEmpty { try mutation(.changed(changes.librarySources)) }
    }
}
