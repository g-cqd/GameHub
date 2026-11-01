public import Foundation

/// An undetected mutant: one the tests didn't catch.
public struct UndetectedMutant: Equatable, Sendable, CustomStringConvertible {
    public var file: String
    public var line: Int
    public var mutation: String
    public var fingerprint: String

    public var description: String { "\(file):\(line) \(mutation)" }
}

/// Reads swift-mutation-testing's report and baseline. The tool refuses a baseline recorded with another scope, and a
/// scoped run excludes other files every time, so for scoped runs the comparison with the baseline is made here: every
/// undetected mutant of the run must be one the baseline holds, by fingerprint.
public enum MutationVerdict {
    /// The undetected mutants (`Survived`, `NoCoverage`) of a report (`--output`).
    public static func undetected(report: Data) throws -> [UndetectedMutant] {
        let decoded = try decode(Report.self, report, "the mutation report")
        return decoded.files
            .flatMap { path, file in
                file.mutants.filter { ["Survived", "NoCoverage"].contains($0.status) }
                    .map {
                        UndetectedMutant(
                            file: path.hasPrefix("/") ? String(path.dropFirst()) : path,
                            line: $0.location.start.line,
                            mutation: "\($0.mutatorName) \($0.description)",
                            fingerprint: $0.fingerprint
                        )
                    }
            }
            .sorted { ($0.file, $0.line, $0.fingerprint) < ($1.file, $1.line, $1.fingerprint) }
    }

    /// The fingerprints a baseline (`--write-baseline`) accepts.
    public static func accepted(baseline: Data) throws -> Set<String> {
        Set(try decode(Baseline.self, baseline, "the mutation baseline").undetected.map(\.fingerprint))
    }

    /// The undetected mutants of `report` that `baseline` doesn't hold; with no baseline, all of them.
    public static func newUndetected(report: Data, baseline: Data?) throws -> [UndetectedMutant] {
        let accepted = try baseline.map(accepted(baseline:)) ?? []
        return try undetected(report: report).filter { !accepted.contains($0.fingerprint) }
    }

    private static func decode<T: Decodable>(_ type: T.Type, _ data: Data, _ what: String) throws -> T {
        do { return try JSONDecoder().decode(type, from: data) } catch {
            throw QualityError.unavailable("could not read \(what): \(error)")
        }
    }

    private struct Report: Decodable {
        var files: [String: File]
        struct File: Decodable { var mutants: [Mutant] }
        struct Mutant: Decodable {
            var fingerprint: String
            var status: String
            var mutatorName: String
            var description: String
            var location: Location
        }
        struct Location: Decodable { var start: Position }
        struct Position: Decodable { var line: Int }
    }

    private struct Baseline: Decodable {
        var undetected: [Entry]
        struct Entry: Decodable { var fingerprint: String }
    }
}
