/// Wine's Unix side runs x86_64 code (under Rosetta on Apple silicon) and may need libc there, nothing else: no Swift
/// runtime, no Foundation. An Embedded Swift object of a library may only leave these symbols undefined.
public enum EmbeddedCheck {
    public static let target = "x86_64-apple-macos15"

    public static let allowedSymbols: Set<String> = [
        "___bzero", "___stack_chk_fail", "___stack_chk_guard", "_free", "_posix_memalign", "_memmove", "_memcpy",
        "_memset", "_memcmp"
    ]

    /// The `swiftc` arguments that compile `sources` of `module` into `object` as Embedded Swift.
    public static func compileArguments(module: String, sources: [String], object: String) -> [String] {
        [
            "-target", target, "-enable-experimental-feature", "Embedded", "-wmo", "-Osize", "-parse-as-library",
            "-strict-memory-safety", "-module-name", module
        ] + sources + ["-emit-object", "-o", object]
    }

    /// The undefined symbols in `nm` output ("                 U _free").
    public static func undefinedSymbols(nmOutput: String) -> [String] {
        nmOutput.split(separator: "\n")
            .compactMap { line in
                let fields = line.split(separator: " ")
                return fields.count == 2 && fields[0] == "U" ? String(fields[1]) : nil
            }
    }

    /// The undefined symbols outside `allowedSymbols`, sorted.
    public static func disallowed(nmOutput: String) -> [String] {
        undefinedSymbols(nmOutput: nmOutput).filter { !allowedSymbols.contains($0) }.sorted()
    }
}

/// Which sources a mutation run mutates.
public enum MutationScope {
    /// A run over every library source (writing the baseline, or checked against it), or over the changed ones only.
    public enum Run: Equatable, Sendable {
        case full(writeBaseline: Bool)
        case changed([String])
    }

    /// `--exclude` arguments that leave every library source out except `changed`. Each path is excluded by its path from
    /// the package root, which the tool matches as a fragment of the absolute path.
    public static func excludeArguments(allSources: [String], changed: [String]) -> [String] {
        let keep = Set(changed)
        return allSources.filter { !keep.contains($0) }.sorted().flatMap { ["--exclude", "/" + $0] }
    }
}
