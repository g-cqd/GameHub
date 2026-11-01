import Foundation

/// The differential test: the C implementation as it was before WineKit (Differential/reference/hubrules.c) against
/// Wine's hubrules.c as it is, which calls WineKit through libwinekit.a, the code ntdll runs. Both are built into the same
/// harness, with stand-ins for the few ntdll internals they use, and run over every rules file, executable and launcher
/// value of the corpus in `Differential/`. What each prints, on standard output and on standard error, must be
/// byte-identical.
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

    /// The `clang` arguments that build the C harness in `work`, where a hubrules.c, the stand-in unix_private.h and
    /// harness.c were copied, followed by `extra` (WineKit's include directory and library for Wine's side). x86_64,
    /// because the C file reads %cs with inline assembly, as in ntdll.
    public static func harnessArguments(work: String, wineSource: String, extra: [String] = []) -> [String] {
        [
            "-arch", "x86_64", "-w", "-O1", "-D__WINESRC__", "-DWINE_UNIX_LIB", "-I\(work)", "-I\(wineSource)/include",
            "-o", "\(work)/harness", "\(work)/harness.c"
        ] + extra
    }

    /// A harness takes the directory holding hub-rules.txt, the executable, and the launcher file if any.
    public static func harnessCall(_ testCase: DifferentialCase, rulesDirectory: String) -> [String] {
        [rulesDirectory, testCase.executable] + (testCase.launcher.map { [$0] } ?? [])
    }
}
