/// A pinned tool: its version and the SHA-256 of its release archive per platform.
public struct PinnedTool: Equatable, Sendable {
    public var name: String
    public var version: String
    public var macOSArm64SHA: String?
    public var linuxX86SHA: String?
}

/// The lock format Aemi's Scripts/analyzers.lock uses, one tool per line: `name version macos-arm64-sha linux-x86_64-sha`.
/// `#` starts a comment; `-` stands for a platform with no archive.
public enum Lock {
    public static func parse(_ text: String) throws -> [PinnedTool] {
        var tools: [PinnedTool] = []
        for (index, rawLine) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = rawLine.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
            let fields = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            if fields.isEmpty { continue }
            guard fields.count == 4 else {
                throw QualityError.unavailable("lock line \(index + 1): expected 4 fields, found \(fields.count)")
            }
            guard fields[2] == "-" || isSHA256(fields[2]), fields[3] == "-" || isSHA256(fields[3]) else {
                throw QualityError.unavailable("lock line \(index + 1): a hash is not 64 hexadecimal digits")
            }
            tools.append(
                PinnedTool(
                    name: fields[0],
                    version: fields[1],
                    macOSArm64SHA: fields[2] == "-" ? nil : fields[2],
                    linuxX86SHA: fields[3] == "-" ? nil : fields[3]
                )
            )
        }
        return tools
    }

    static func isSHA256(_ text: String) -> Bool {
        text.count == 64 && text.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }
}
