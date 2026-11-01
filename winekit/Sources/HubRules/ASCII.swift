// Byte-level text helpers. Rules files and PE names are ASCII; working on bytes keeps the library usable in Embedded Swift,
// where String's Unicode tables are an extra dependency. The byte primitives are Aemi's (AemiKernel); these are the C
// string functions the rules engine was written against, on top of them.

import AemiKernel

/// A byte string, as the C code sees `char *` text.
public typealias Bytes = [UInt8]

enum ASCII {
    static let newline = UInt8(ascii: "\n")
    static let carriageReturn = UInt8(ascii: "\r")
    static let space = UInt8(ascii: " ")
    static let tab = UInt8(ascii: "\t")
    static let semicolon = UInt8(ascii: ";")
    static let comma = UInt8(ascii: ",")
    static let equals = UInt8(ascii: "=")
    static let hash = UInt8(ascii: "#")

    static func lower(_ byte: UInt8) -> UInt8 {
        AemiKernel.ASCII.isUppercase(byte) ? byte + 32 : byte
    }

    /// `strcasecmp(a, b) == 0`
    static func equalsIgnoringCase(_ lhs: some Collection<UInt8>, _ rhs: some Collection<UInt8>) -> Bool {
        lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { lower($0) == lower($1) }
    }

    /// `strncasecmp(a, prefix, strlen(prefix)) == 0`
    static func hasPrefixIgnoringCase(_ bytes: some Collection<UInt8>, _ prefix: some Collection<UInt8>) -> Bool {
        bytes.count >= prefix.count && zip(bytes, prefix).allSatisfy { lower($0) == lower($1) }
    }

    static func hasPrefix(_ bytes: some Collection<UInt8>, _ prefix: some Collection<UInt8>) -> Bool {
        bytes.count >= prefix.count && zip(bytes, prefix).allSatisfy { $0 == $1 }
    }

    /// The fields between `separator`s, empty ones included (C's strchr walk).
    static func split(_ bytes: ArraySlice<UInt8>, on separator: UInt8) -> [ArraySlice<UInt8>] {
        bytes.split(separator: separator, omittingEmptySubsequences: false)
    }

    /// The bytes before the first NUL.
    static func untilNUL(_ bytes: some Collection<UInt8>) -> Bytes {
        Bytes(bytes.prefix { $0 != 0 })
    }

    /// The first range of `needle` in `haystack`, as `strstr`, in `haystack`'s own indices; nil for an empty needle.
    static func firstRange(of needle: Bytes, in haystack: ArraySlice<UInt8>) -> Range<Int>? {
        ByteSearch.firstRange(of: needle, in: haystack)
    }

    static func decimal(_ value: Int) -> Bytes {
        guard value > 0 else { return [UInt8(ascii: "0")] }
        var digits = Bytes()
        var rest = value
        while rest > 0 {
            digits.append(UInt8(ascii: "0") + UInt8(rest % 10))
            rest /= 10
        }
        return digits.reversed()
    }
}
