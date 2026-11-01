// hub-rules.txt holds two kinds of lines:
//
//   name=...;exe=...;key=value          a compatdb rule, passed through as is
//   when pred[;pred...] => key=value;.. a detection rule: when every predicate holds for the executable that is
//                                       starting, the settings apply to it as a compatdb rule
//
// Two settings are runtime capabilities rather than compatdb settings and are taken out of the rule:
// `gate_selector_fixup=true` and `hub_dll_dir=<dir relative to lib/wine>`.

public struct RulesResult: Equatable, Sendable {
    /// The WINE_COMPATDB value: "v=3", the runtime rules, then the launcher's rules.
    public var compatDB: Bytes
    public var gateSelectorFixup: Bool
    public var dllDirectory: Bytes?
    /// The line numbers (1-based) of the detection rules that matched.
    public var matchedLines: [Int]
    /// The report lines and warnings, in rule order.
    public var messages: [RulesMessage]

    /// The report lines, each with its newline: what ntdll prints on stderr for the matches.
    public var report: Bytes {
        messages.flatMap { message -> Bytes in
            if case .report(let text) = message { return text + [ASCII.newline] }
            return []
        }
    }
}

public enum RulesEngine {
    static let gateKey = Bytes("gate_selector_fixup=true".utf8)
    static let dllDirKey = Bytes("hub_dll_dir=".utf8)

    /// The rules for the executable `exe` (a file name), its PE facts, and the launcher's own WINE_COMPATDB (`launcher`).
    public static func apply(rules: Bytes, exe: Bytes, facts: PEFacts?, launcher: Bytes) -> RulesResult {
        var result = RulesResult(
            compatDB: [],
            gateSelectorFixup: false,
            dllDirectory: nil,
            matchedLines: [],
            messages: []
        )
        var lines: [Bytes] = [Bytes("v=3".utf8)]
        for (index, rawLine) in ASCII.split(rules[...], on: ASCII.newline).enumerated() {
            let line = rawLine.prefix { $0 != ASCII.carriageReturn }.drop { $0 == ASCII.space || $0 == ASCII.tab }
            if line.isEmpty || line.first == ASCII.hash { continue }
            guard ASCII.hasPrefix(line, "when ".utf8) else {
                lines.append(Bytes(line))
                continue
            }
            if let rule = detection(line, number: index + 1, exe: exe, facts: facts, into: &result) {
                lines.append(rule)
            }
        }
        let base = launcherRules(launcher)
        if !base.isEmpty { lines.append(base) }
        // The C code ends every line with a newline and then drops one: joining gives the same bytes, including a newline
        // that ends the launcher's rules.
        result.compatDB = Bytes(lines.joined(separator: [ASCII.newline]))
        return result
    }

    /// The compatdb line of a matching detection rule, or nil. Capabilities found in it are recorded in `result`.
    private static func detection(
        _ line: ArraySlice<UInt8>,
        number: Int,
        exe: Bytes,
        facts: PEFacts?,
        into result: inout RulesResult
    ) -> Bytes? {
        guard let arrow = ASCII.firstRange(of: Bytes("=>".utf8), in: line) else {
            result.messages.append(.warning(Bytes("line ".utf8) + ASCII.decimal(number) + Bytes(": no =>".utf8)))
            return nil
        }
        let predicates = line[(line.startIndex + 5) ..< arrow.lowerBound]
        guard Predicates.hold(predicates, exe: exe, facts: facts, messages: &result.messages) else { return nil }
        result.matchedLines.append(number)
        let written = line[arrow.upperBound...].drop { $0 == ASCII.space }
        result.messages.append(
            .report(
                Bytes("hubrules: ".utf8) + exe + Bytes(" matches line ".utf8) + ASCII.decimal(number) + Bytes(": ".utf8)
                    + written
            )
        )
        var fields = ASCII.split(written, on: ASCII.semicolon)
        if let gate = fields.firstIndex(where: { $0.elementsEqual(gateKey) }) {
            fields.remove(at: gate)
            result.gateSelectorFixup = true
        }
        if let dir = fields.firstIndex(where: { $0.count > dllDirKey.count && ASCII.hasPrefix($0, dllDirKey) }) {
            let value = Bytes(fields[dir].dropFirst(dllDirKey.count))
            fields.remove(at: dir)
            // relative to lib/wine only: no parent references, no absolute paths
            if ASCII.firstRange(of: Bytes("..".utf8), in: value[...]) == nil, value.first != UInt8(ascii: "/") {
                result.dllDirectory = value
            } else {
                result.messages.append(
                    .warning(
                        Bytes("line ".utf8) + ASCII.decimal(number) + Bytes(": ".utf8) + dllDirKey + value
                            + Bytes(" must be relative to lib/wine, ignored".utf8)
                    )
                )
            }
        }
        let settings = Bytes(fields.joined(separator: [ASCII.semicolon]))
        if settings.isEmpty { return nil }  // only runtime capabilities, nothing for compatdb
        return Bytes("name=hubrules-".utf8) + ASCII.decimal(number) + Bytes(";exe=".utf8) + exe + [ASCII.semicolon]
            + settings
    }

    /// The launcher's rules without its own "v=" header line.
    static func launcherRules(_ launcher: Bytes) -> Bytes {
        guard ASCII.hasPrefix(launcher, "v=".utf8) else { return launcher }
        guard let newline = launcher.firstIndex(of: ASCII.newline) else { return [] }
        return Bytes(launcher[(newline + 1)...])
    }
}
