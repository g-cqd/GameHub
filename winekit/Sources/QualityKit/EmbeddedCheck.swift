/// Wine's Unix side runs x86_64 code (under Rosetta on Apple silicon) and may need libc there, nothing else: no Swift
/// runtime, no Foundation. An Embedded Swift object of a library may only leave these symbols undefined.
public enum EmbeddedCheck {
    public static let target = "x86_64-apple-macos15"

    /// The symbols C/winekit.h declares: the library must define every one.
    public static let requiredExports = ["_winekit_free", "_winekit_hub_rules_apply"]

    public static let allowedSymbols: Set<String> = [
        "___bzero", "___stack_chk_fail", "___stack_chk_guard", "_free", "_posix_memalign", "_memmove", "_memcpy",
        "_memset", "_memcmp"
    ]

    /// The `swiftc` arguments that compile `sources` of `module` into `object` as Embedded Swift.
    public static func compileArguments(module: String, sources: [String], object: String) -> [String] {
        [
            "-target", target, "-enable-experimental-feature", "Embedded", "-wmo", "-Osize", "-parse-as-library",
            // Wine builds its Unix side with -fno-stack-protector.
            "-strict-memory-safety", "-Xfrontend", "-disable-stack-protector", "-module-name", module
        ] + sources + ["-emit-object", "-o", object]
    }

    /// The symbols of one kind in `nm` output: an undefined one is `U _free` (no address), a defined one
    /// `0000000000001101 T _winekit_free`. The kind is the field before the name, and a line has no other fields.
    static func symbols(_ kind: String, nmOutput: String) -> [String] {
        nmOutput.split(separator: "\n")
            .compactMap { line in
                let fields = line.split(separator: " ")
                let count = kind == "U" ? 2 : 3
                return fields.count == count && fields[count - 2] == kind ? String(fields[count - 1]) : nil
            }
    }

    /// The undefined symbols in `nm` output.
    public static func undefinedSymbols(nmOutput: String) -> [String] { symbols("U", nmOutput: nmOutput) }

    /// The symbols `nm` output defines in a text section.
    public static func exportedSymbols(nmOutput: String) -> Set<String> { Set(symbols("T", nmOutput: nmOutput)) }

    /// The exports of `requiredExports` that `nm` output lacks.
    public static func missingExports(nmOutput: String) -> [String] {
        let exported = exportedSymbols(nmOutput: nmOutput)
        return requiredExports.filter { !exported.contains($0) }
    }

    /// The undefined symbols outside `allowedSymbols`, sorted.
    public static func disallowed(nmOutput: String) -> [String] {
        undefinedSymbols(nmOutput: nmOutput).filter { !allowedSymbols.contains($0) }.sorted()
    }
}

/// Which sources a mutation run mutates.
public enum MutationScope {
    /// The sources a run may mutate: those of `Workspace.mutationTargets`, the code Wine runs.
    public static func isMutated(_ path: String) -> Bool {
        Workspace.mutationTargets.contains { path.hasPrefix("Sources/\($0)/") }
    }

    /// A run over every mutated source (writing the baseline, or checked against it), or over the changed ones only.
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
