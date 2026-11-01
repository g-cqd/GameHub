import Foundation

/// The differential test: Wine's hubrules.c, built from a Wine checkout with stand-ins for the few ntdll internals it uses,
/// against hubrules-swift, over every rules file, executable and launcher value of the corpus in `Differential/`. The
/// outputs must be byte-identical.
public struct DifferentialCase: Equatable, Sendable {
    public var rules: String
    public var executable: String
    /// A file holding the launcher's WINE_COMPATDB, or nil for none set.
    public var launcher: String?
}

public enum Differential {
    /// The cases of a corpus: every rules file × every listed executable that exists × no launcher and every launcher file.
    /// Executable lines may use `$ROOT` (the package directory); blank lines and `#` comments are skipped.
    public static func cases(
        rules: [String],
        executablesList: String,
        launchers: [String],
        root: String,
        exists: (String) -> Bool
    ) -> [DifferentialCase] {
        let executables = executablesList.split(separator: "\n").map { String($0).trimmed }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .map { $0.replacingOccurrences(of: "$ROOT", with: root) }
            .filter(exists)
        let launcherChoices: [String?] = [nil] + launchers.sorted().map { Optional($0) }
        return rules.sorted()
            .flatMap { rule in
                executables.flatMap { exe in
                    launcherChoices.map { DifferentialCase(rules: rule, executable: exe, launcher: $0) }
                }
            }
    }

    /// The `clang` arguments that build the C harness in `work`, where hubrules.c, the stand-in unix_private.h and
    /// harness.c were copied. x86_64, because the C file reads %cs with inline assembly, as in ntdll.
    public static func harnessArguments(work: String, wineSource: String) -> [String] {
        [
            "-arch", "x86_64", "-w", "-O1", "-D__WINESRC__", "-DWINE_UNIX_LIB", "-I\(work)", "-I\(wineSource)/include",
            "-o", "\(work)/harness", "\(work)/harness.c"
        ]
    }

    /// The harness takes the directory holding hub-rules.txt; hubrules-swift takes the file.
    public static func harnessCall(_ testCase: DifferentialCase, rulesDirectory: String) -> [String] {
        [rulesDirectory, testCase.executable] + (testCase.launcher.map { [$0] } ?? [])
    }

    public static func swiftCall(_ testCase: DifferentialCase, rulesFile: String) -> [String] {
        [rulesFile, testCase.executable] + (testCase.launcher.map { [$0] } ?? [])
    }
}
