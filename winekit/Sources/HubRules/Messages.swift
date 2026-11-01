// What the rules engine tells ntdll as it goes: a report line for each match (printed on stderr) and a warning for each
// rule it can't use (printed with WARN, under +module). They come in rule order, as the C code printed them.

/// One message, in the order the rules produced it.
public enum RulesMessage: Equatable, Sendable {
    /// `hubrules: <exe> matches line <n>: <settings>`.
    case report(Bytes)
    /// A rule that can't be used, as the C code's WARN wrote it.
    case warning(Bytes)

    /// The C interface's encoding: a first byte, `R` or `W`, then the text and a newline.
    var line: Bytes {
        switch self {
            case .report(let text): [UInt8(ascii: "R")] + text + [ASCII.newline]
            case .warning(let text): [UInt8(ascii: "W")] + text + [ASCII.newline]
        }
    }
}

enum DebugString {
    /// `debugstr_a`: the text in double quotes, with \n, \r, \t, \", \\ escaped and other bytes outside printable ASCII
    /// as \xNN; past what its 300-byte buffer holds, the rest becomes "...".
    static func quoted(_ text: some Collection<UInt8>) -> Bytes {
        var out: Bytes = [UInt8(ascii: "\"")]
        var remaining = text.count
        var index = text.startIndex
        // The C loop tests `n-- > 0 && dst <= buffer + 300 - 9`: the count drops even when the buffer stops it.
        while true {
            let more = remaining > 0
            remaining -= 1
            guard more, out.count <= 300 - 9 else { break }
            out += escaped(text[index])
            index = text.index(after: index)
        }
        out.append(UInt8(ascii: "\""))
        if remaining > 0 { out += Bytes("...".utf8) }
        return out
    }

    private static func escaped(_ byte: UInt8) -> Bytes {
        let hex = Bytes("0123456789abcdef".utf8)
        switch byte {
            case ASCII.newline: return Bytes("\\n".utf8)
            case ASCII.carriageReturn: return Bytes("\\r".utf8)
            case ASCII.tab: return Bytes("\\t".utf8)
            case UInt8(ascii: "\""): return Bytes("\\\"".utf8)
            case UInt8(ascii: "\\"): return Bytes("\\\\".utf8)
            case 0x20 ..< 0x7f: return [byte]
            default: return [UInt8(ascii: "\\"), UInt8(ascii: "x"), hex[Int(byte >> 4)], hex[Int(byte & 0x0f)]]
        }
    }
}
