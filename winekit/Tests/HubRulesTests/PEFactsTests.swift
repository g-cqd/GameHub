import Testing

@testable import HubRules

@Suite struct PEFactsTests {
    @Test func readsMachineSectionsAndImportsOfPE32Plus() throws {
        let read = try #require(facts(PEImage()))
        #expect(read.machine == PEFacts.machineAMD64)
        #expect(names(read.sections) == [".text", ".idata"])
        #expect(names(read.imports) == ["KERNEL32.dll", "user32.dll"])
    }

    @Test func readsPE32ImportsFromTheirOwnDirectoryOffset() throws {
        let read = try #require(facts(PEImage(machine: PEFacts.machineI386, magic: 0x10b)))
        #expect(read.machine == PEFacts.machineI386)
        #expect(names(read.imports) == ["KERNEL32.dll", "user32.dll"])
    }

    @Test func rejectsWhatIsNotAPEFile() {
        #expect(PEFacts.read(from: PEBytes(Array("not a PE".utf8))) == nil)
        #expect(PEFacts.read(from: PEBytes([0x4d, 0x5a])) == nil)
        var noSignature = PEImage().bytes
        noSignature[0x80] = 0
        #expect(PEFacts.read(from: PEBytes(noSignature)) == nil)
        var notMZ = PEImage().bytes
        notMZ[1] = 0
        #expect(PEFacts.read(from: PEBytes(notMZ)) == nil)
    }

    @Test func rejectsAnNTHeaderOutsideTheFile() {
        // past the end of the file; negative as the C LONG
        for lfanew: [UInt8] in [[0xf0, 0xff, 0xff, 0x7f], [0xf0, 0xff, 0xff, 0xff]] {
            var bytes = PEImage().bytes
            bytes.replaceSubrange(0x3c ..< 0x40, with: lfanew)
            #expect(PEFacts.read(from: PEBytes(bytes)) == nil)
        }
    }

    @Test func rejectsATruncatedSectionTable() {
        let cut = Array(PEImage().bytes.prefix(0x80 + 24 + 240 + 50))
        #expect(PEFacts.read(from: PEBytes(cut)) == nil)
    }

    @Test func keepsMachineAndSectionsWhenImportsCantBeRead() throws {
        let headersOnly = Array(PEImage().bytes.prefix(0x400))
        let read = try #require(PEFacts.read(from: PEBytes(headersOnly)))
        #expect(names(read.sections) == [".text", ".idata"])
        #expect(read.imports.isEmpty)
    }

    @Test func hasNoImportsWithoutAnImportDirectory() throws {
        #expect(try #require(facts(PEImage(importRVA: nil))).imports.isEmpty)
        #expect(try #require(facts(PEImage(importRVA: 0x9000))).imports.isEmpty)  // in no section
    }

    @Test func ignoresImportsOfAnUnknownOptionalHeader() throws {
        #expect(try #require(facts(PEImage(magic: 0x107))).imports.isEmpty)
    }

    @Test func needsTheOptionalHeaderToHoldTheImportDirectory() throws {
        #expect(try #require(facts(PEImage(optionalSize: 112 + 15))).imports.isEmpty)
        #expect(try #require(facts(PEImage(magic: 0x10b, optionalSize: 96 + 15))).imports.isEmpty)
        #expect(names(try #require(facts(PEImage(optionalSize: 112 + 16))).imports).count == 2)
        #expect(names(try #require(facts(PEImage(magic: 0x10b, optionalSize: 96 + 16))).imports).count == 2)
    }

    @Test func sectionNamesStopAtNULAndAtEightBytes() throws {
        var image = PEImage()
        image.sections[0].name = ".verylongname"
        let read = try #require(facts(image))
        #expect(names(read.sections) == [".verylon", ".idata"])
    }

    @Test func readsAtMostNinetySixSections() throws {
        var image = PEImage(imports: [], importRVA: nil)
        image.sections = (0 ..< 100).map { ("s\($0)", UInt32(0x1000 * ($0 + 1)), 0x10, 0x10, 0) }
        let read = try #require(PEFacts.read(from: PEBytes(image.bytes)))
        #expect(read.sections.count == 96)
        #expect(names(read.sections).last == "s95")
    }

    @Test func emptyImportNamesAreSkippedAndTheListStopsAtAZeroName() throws {
        var image = PEImage()
        image.imports = ["", "d3d11.dll"]
        let read = try #require(facts(image))
        #expect(names(read.imports) == ["d3d11.dll"])
    }

    @Test func importNamesAreCutAtSixtyThreeBytes() throws {
        var image = PEImage()
        image.imports = [String(repeating: "a", count: 80)]
        let read = try #require(facts(image))
        #expect(read.imports.first?.count == 63)
    }

    @Test func importNamesOutsideAnySectionAreSkipped() throws {
        var bytes = PEImage().bytes
        bytes[0x600 + 12] = 0xff  // the first descriptor's name RVA now points nowhere
        bytes[0x600 + 13] = 0xff
        bytes[0x600 + 14] = 0x0f
        let read = try #require(PEFacts.read(from: PEBytes(bytes)))
        #expect(names(read.imports) == ["user32.dll"])
    }

    @Test func rvaOffsetsHonourTheRawDataOfTheSection() {
        let raw = PEImage().bytes
        let table = 0x80 + 24 + 240
        let sections = (0 ..< 2).map { PEFacts.Section(raw, at: table + $0 * 40) }
        #expect(PEFacts.offset(of: 0x1000, in: sections) == 0x400)
        #expect(PEFacts.offset(of: 0x11ff, in: sections) == 0x5ff)
        #expect(PEFacts.offset(of: 0x1200, in: sections) == nil)
        #expect(PEFacts.offset(of: 0x0fff, in: sections) == nil)
        #expect(PEFacts.offset(of: 0x2010, in: sections) == 0x610)
    }

    @Test func rvaInVirtualOnlyPartIsNotBackedByTheFile() {
        var image = PEImage()
        image.sections[0].virtualSize = 0x800
        let raw = image.bytes
        let sections = (0 ..< 2).map { PEFacts.Section(raw, at: 0x80 + 24 + 240 + $0 * 40) }
        #expect(PEFacts.offset(of: 0x1300, in: sections) == nil)
        #expect(PEFacts.offset(of: 0x11ff, in: sections) == 0x5ff)
    }

    @Test func inMemoryReadsFollowPreadSemantics() {
        let file = PEBytes([1, 2, 3])
        #expect(file.read(at: 1, count: 5) == [2, 3])
        #expect(file.read(at: 3, count: 1).isEmpty)
        #expect(file.read(at: -1, count: 1).isEmpty)
        #expect(file.read(at: 0, count: 0).isEmpty)
    }
}
