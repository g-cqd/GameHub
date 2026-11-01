/// The hook a scoped run serves: a commit checks its staged files, a push what HEAD has beyond its upstream.
public enum Hook: String, Sendable, CaseIterable {
    case preCommit = "pre-commit"
    case prePush = "pre-push"
}

/// The package's files a commit or push changes, sorted into what each gate needs.
public struct ChangeSet: Equatable, Sendable {
    /// Every changed path, relative to the package.
    public var files: [String]
    /// The library targets: their sources are mutated and compiled as Embedded Swift. Executable targets and plugins are
    /// host tools and are left out.
    public var libraryTargets: [String]

    public init(files: [String], libraryTargets: [String]) {
        self.files = files
        self.libraryTargets = libraryTargets
    }

    public var swiftFiles: [String] { files.filter { $0.hasSuffix(".swift") } }

    public var librarySources: [String] {
        swiftFiles.filter { path in libraryTargets.contains { path.hasPrefix("Sources/\($0)/") } }
    }

    public var manifestChanged: Bool { files.contains("Package.swift") }

    /// Anything the differential test reads: the Swift rules engine, its host tool, or the corpus.
    public var touchesDifferential: Bool {
        files.contains {
            $0.hasPrefix("Sources/HubRules/") || $0.hasPrefix("Sources/hubrules-swift/")
                || $0.hasPrefix("Differential/")
        }
    }

    public var isEmpty: Bool { files.isEmpty }

    /// The paths in `git diff --name-only` output, one per line.
    public static func paths(fromGitOutput output: String) -> [String] {
        output.split(separator: "\n").map { String($0).trimmed }.filter { !$0.isEmpty }
    }

    /// The `git` arguments that list the changes for `hook`, relative to the package; deleted files are left out. A push
    /// compares with `base`, the upstream of the branch.
    public static func gitArguments(for hook: Hook, base: String?) -> [String] {
        switch hook {
            case .preCommit: ["diff", "--cached", "--relative", "--name-only", "--diff-filter=ACMR", "--", "."]
            case .prePush:
                [
                    "diff", "--relative", "--name-only", "--diff-filter=ACMR", "\(base ?? "origin/main")...HEAD", "--",
                    "."
                ]
        }
    }
}
