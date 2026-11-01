import Testing

@testable import HubRules

/// The edges of each comparison: the first and last byte of a range, equal lengths, and the readers' limits.
@Suite struct BoundaryTests {
    @Test func lowercasingCoversExactlyAToZ() {
        #expect(ASCII.lower(UInt8(ascii: "A")) == UInt8(ascii: "a"))
        #expect(ASCII.lower(UInt8(ascii: "Z")) == UInt8(ascii: "z"))
        #expect(ASCII.lower(UInt8(ascii: "@")) == UInt8(ascii: "@"))
        #expect(ASCII.lower(UInt8(ascii: "[")) == UInt8(ascii: "["))
    }

    @Test func aPrefixAsLongAsTheTextMatches() {
        #expect(ASCII.hasPrefixIgnoringCase(Bytes("AB".utf8), Bytes("ab".utf8)))
        #expect(ASCII.hasPrefix(Bytes("ab".utf8), Bytes("ab".utf8)))
    }

    @Test func aPrefixLongerThanTheTextDoesNot() {
        #expect(!ASCII.hasPrefixIgnoringCase(Bytes("ab".utf8), Bytes("abc".utf8)))
        #expect(!ASCII.hasPrefix(Bytes("ab".utf8), Bytes("abc".utf8)))
    }

    @Test func aNeedleAsLongAsTheHaystackIsFound() {
        #expect(ASCII.firstRange(of: Bytes("=>".utf8), in: Bytes("=>".utf8)[...]) == 0 ..< 2)
    }

    @Test func importsStopAtTwoHundredFiftySix() throws {
        var image = PEImage(imports: [])
        image.sections[1].virtualSize = 0x4000
        image.sections[1].rawSize = 0x4000
        let bytes = Self.relocatedImports(
            (0 ..< 300).map { "d\($0)" }, into: image.bytes + [UInt8](repeating: 0, count: 0x4000))
        let read = try #require(PEFacts.read(from: PEBytes(bytes)))
        #expect(read.imports.count == 256)
        #expect(names(read.imports).last == "d255")
    }

    @Test func importDescriptorsStopAtSixtyFourKilobytes() throws {
        // 3,300 descriptors whose names point nowhere, then one that names a DLL: the reader gives up at 64 KB (3,277).
        var image = PEImage(imports: [])
        image.sections[1].virtualSize = 0x20000
        image.sections[1].rawSize = 0x20000
        var bytes = image.bytes + [UInt8](repeating: 0, count: 0x20000)
        for index in 0 ..< 3_300 { Self.put32(&bytes, 0x600 + index * 20 + 12, 0x00ff_0000) }
        Self.put32(&bytes, 0x600 + 3_300 * 20 + 12, 0x2000 + 0x1_f000)
        for (offset, byte) in "late.dll".utf8.enumerated() { bytes[0x600 + 0x1_f000 + offset] = byte }
        let read = try #require(PEFacts.read(from: PEBytes(bytes)))
        #expect(read.imports.isEmpty)
    }

    @Test func anRVAAtTheEndOfASectionBelongsToTheNextOne() throws {
        var image = PEImage()
        image.sections = [(".a", 0x1000, 0x200, 0x200, 0x400), (".b", 0x1200, 0x200, 0x200, 0x600)]
        let raw = image.bytes
        let sections = (0 ..< 2).map { PEFacts.Section(raw, at: 0x80 + 24 + 240 + $0 * 40) }
        #expect(PEFacts.offset(of: 0x1200, in: sections) == 0x600)
        #expect(PEFacts.offset(of: 0x11ff, in: sections) == 0x5ff)
    }

    @Test func theFirstByteAfterTheRawDataIsNotInTheFile() {
        var image = PEImage()
        image.sections[0].virtualSize = 0x800
        let raw = image.bytes
        let sections = (0 ..< 2).map { PEFacts.Section(raw, at: 0x80 + 24 + 240 + $0 * 40) }
        #expect(PEFacts.offset(of: 0x1200, in: sections) == nil)
    }

    /// Rewrites the import descriptors and names of `imports` into a larger .idata (descriptors at 0x600, names at 0x2000).
    static func relocatedImports(_ imports: [String], into bytes: [UInt8]) -> [UInt8] {
        var out = bytes
        var namePos = 0x2000
        for (index, name) in imports.enumerated() {
            put32(&out, 0x600 + index * 20 + 12, UInt32(0x2000 + namePos - 0x600))
            for (offset, byte) in name.utf8.enumerated() { out[namePos + offset] = byte }
            out[namePos + name.utf8.count] = 0
            namePos += name.utf8.count + 1
        }
        return out
    }

    static func put32(_ bytes: inout [UInt8], _ at: Int, _ value: UInt32) {
        for shift in 0 ..< 4 { bytes[at + shift] = UInt8((value >> (8 * UInt32(shift))) & 0xff) }
    }
}
