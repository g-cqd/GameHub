/// Wine's Unix side runs x86_64 code (under Rosetta on Apple silicon) and may need libc there, nothing else: no Swift
/// runtime, no Foundation. Together, the objects in libwinekit.a may only leave these symbols undefined.
public enum EmbeddedCheck {
    public static let target = "x86_64-apple-macos15"

    /// The symbols C/winekit.h declares: the library must define every one.
    public static let requiredExports = ["_winekit_free", "_winekit_hub_rules_apply"]

    /// libc, plus compiler-rt's CPU model, which Aemi's C kernels ask once (`__builtin_cpu_supports`) to pick their
    /// SIMD tier; the list matches Aemi's Scripts/check-embedded.sh.
    public static let allowedSymbols = Set((memory + allocation + system + compilerRuntime).map { "_" + $0 })

    static let memory = ["__bzero", "bzero", "memmove", "memcpy", "memset", "memcmp", "memchr", "strlen"]
    static let allocation = ["free", "posix_memalign"]
    /// Aemi's kernels: a random seed, the one-time CPU probe, and its sysctl on arm64.
    static let system = ["arc4random_buf", "pthread_once", "sysctlbyname"]
    static let compilerRuntime = ["__stack_chk_fail", "__stack_chk_guard", "__cpu_model", "__cpu_indicator_init"]

    /// Aemi's Embedded-clean modules, in build order: each one's module is on the next one's include path.
    public static let aemiModules = ["AemiKernels", "AemiKernel"]

    /// The `swiftc` arguments that compile `sources` of `module` into `object` as Embedded Swift.
    /// `options` go before the sources: include paths, and where to emit the module for the next one.
    public static func compileArguments(
        module: String,
        sources: [String],
        object: String,
        options: [String] = []
    ) -> [String] {
        [
            "-target", target, "-enable-experimental-feature", "Embedded", "-wmo", "-Osize", "-parse-as-library",
            // Wine builds its Unix side with -fno-stack-protector.
            "-strict-memory-safety", "-Xfrontend", "-disable-stack-protector", "-module-name", module
        ] + options + sources + ["-emit-object", "-o", object]
    }

    /// The `clang` arguments that compile one of Aemi's C sources into `object`, with Aemi's strict flags and includes.
    public static func cCompileArguments(source: String, object: String, flags: [String], includes: [String])
        -> [String]
    {
        ["-target", target, "-O2", "-fno-stack-protector"] + flags + includes + ["-c", source, "-o", object]
    }

    /// What Aemi's Scripts/lib/c-targets.sh says about its C, printed as three lines by `cTargetsScript`: the strict
    /// flags, the include flags, then the sources an Embedded consumer of AemiKernels builds (CAemiCPU's feature set
    /// and CAemiKernels). Paths are split on whitespace, as the script itself does.
    public struct CTargets: Equatable, Sendable {
        public let flags: [String]
        public let includes: [String]
        public let sources: [String]

        public init?(scriptOutput: String) {
            let lines = scriptOutput.split(separator: "\n", omittingEmptySubsequences: false)
            guard lines.count >= 3 else { return nil }
            func words(_ line: Substring) -> [String] { line.split(separator: " ").map(String.init) }
            flags = words(lines[0])
            includes = words(lines[1])
            sources = words(lines[2])
            guard !flags.isEmpty, !sources.isEmpty else { return nil }
        }
    }

    /// Sources Aemi's c-targets.sh (it needs AEMI_ROOT) and prints `CTargets`' three lines; $1 is Aemi's root.
    public static let cTargetsScript = """
        AEMI_ROOT="$1"; . "$1/Scripts/lib/c-targets.sh"; printf '%s\\n' "$C_STRICT" "$C_INCLUDES" "$CPU_SOURCES $KERNELS_SOURCES"
        """

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

    /// Every symbol `nm` output defines, whatever its section.
    static func definedSymbols(nmOutput: String) -> Set<String> {
        Set(
            nmOutput.split(separator: "\n")
                .compactMap { line in
                    let fields = line.split(separator: " ")
                    return fields.count == 3 && fields[1] != "U" ? String(fields[2]) : nil
                }
        )
    }

    /// The symbols the objects in `nm` output need from outside them and outside `allowedSymbols`, sorted and unique: one
    /// object's undefined symbol another defines (Aemi's C kernels, for its Swift) is resolved inside the archive.
    public static func disallowed(nmOutput: String) -> [String] {
        let defined = definedSymbols(nmOutput: nmOutput)
        return Set(undefinedSymbols(nmOutput: nmOutput))
            .filter { !allowedSymbols.contains($0) && !defined.contains($0) }.sorted()
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
