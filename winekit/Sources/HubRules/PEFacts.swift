// What the rules can ask of an executable: its machine, its section names and the DLLs it imports. Read from the headers
// only, with every offset checked; a truncated or hostile file yields fewer facts, never a crash.

/// Random access to a file, with `pread` semantics: up to `count` bytes at `offset`, fewer at the end of the file, none on error.
public protocol PEFile {
    func read(at offset: Int, count: Int) -> Bytes
}

/// A file held in memory.
public struct PEBytes: PEFile {
    public let bytes: Bytes
    public init(_ bytes: Bytes) { self.bytes = bytes }

    public func read(at offset: Int, count: Int) -> Bytes {
        guard offset >= 0, offset < bytes.count, count > 0 else { return [] }
        return Bytes(bytes[offset ..< min(bytes.count, offset + count)])
    }
}

public struct PEFacts: Equatable, Sendable {
    public static let machineI386: UInt16 = 0x014c
    public static let machineAMD64: UInt16 = 0x8664

    /// The limits of the C reader (hubrules.c), kept so both give the same answers.
    static let maxSections = 96
    static let maxImports = 256
    static let maxImportSpan = 64 * 1024
    static let importNameLength = 63

    public var machine: UInt16
    public var sections: [Bytes]
    public var imports: [Bytes]

    public init(machine: UInt16, sections: [Bytes], imports: [Bytes]) {
        self.machine = machine
        self.sections = sections
        self.imports = imports
    }

    /// The facts of the PE file, or nil when it is not one (or its headers can't be read). Imports are optional: a file whose
    /// import directory can't be followed still gives its machine and sections.
    public static func read(from file: some PEFile) -> Self? {
        let dos = file.read(at: 0, count: 64)
        guard dos.count == 64, le16(dos, 0) == 0x5a4d else { return nil }
        let ntOffset = Int(Int32(bitPattern: le32(dos, 60)))
        let nt = file.read(at: ntOffset, count: 26)
        guard ntOffset >= 0, nt.count == 26, le32(nt, 0) == 0x0000_4550 else { return nil }

        let count = min(Int(le16(nt, 6)), maxSections)
        let optionalSize = Int(le16(nt, 20))
        let raw = file.read(at: ntOffset + 24 + optionalSize, count: count * 40)
        guard raw.count == count * 40 else { return nil }
        let sections = (0 ..< count).map { Section(raw, at: $0 * 40) }
        var facts = Self(machine: le16(nt, 4), sections: sections.map(\.name), imports: [])
        facts.imports = readImports(file, ntOffset: ntOffset, magic: le16(nt, 24), optionalSize: optionalSize, sections)
        return facts
    }

    private static func readImports(
        _ file: some PEFile,
        ntOffset: Int,
        magic: UInt16,
        optionalSize: Int,
        _ sections: [Section]
    ) -> [Bytes] {
        // DataDirectory[1] (imports): optional header offsets 112 (PE32+) and 96 (PE32), each directory 8 bytes.
        let directories: Int
        switch magic {
            case 0x20b: directories = 112
            case 0x10b: directories = 96
            default: return []
        }
        guard optionalSize >= directories + 16 else { return [] }
        let dir = file.read(at: ntOffset + 24 + directories + 8, count: 8)
        guard dir.count == 8, le32(dir, 0) != 0, let start = offset(of: le32(dir, 0), in: sections) else { return [] }

        var imports: [Bytes] = []
        var index = 0
        while imports.count < maxImports, index * 20 < maxImportSpan {
            let descriptor = file.read(at: start + index * 20, count: 20)
            index += 1
            guard descriptor.count == 20, le32(descriptor, 12) != 0 else { break }
            guard let namePos = offset(of: le32(descriptor, 12), in: sections) else { continue }
            let name = ASCII.untilNUL(file.read(at: namePos, count: importNameLength))
            if !name.isEmpty { imports.append(name) }
        }
        return imports
    }

    /// The file offset of `rva`, or nil when no section holds it or the section doesn't back it with file data.
    static func offset(of rva: UInt32, in sections: [Section]) -> Int? {
        for section in sections {
            let size = max(section.virtualSize, section.rawSize)
            guard rva >= section.virtualAddress, rva - section.virtualAddress < size else { continue }
            let delta = rva - section.virtualAddress
            return delta >= section.rawSize ? nil : Int(section.rawPointer) + Int(delta)
        }
        return nil
    }

    struct Section {
        let name: Bytes
        let virtualSize, virtualAddress, rawSize, rawPointer: UInt32

        init(_ raw: Bytes, at base: Int) {
            name = ASCII.untilNUL(raw[base ..< base + 8])
            virtualSize = le32(raw, base + 8)
            virtualAddress = le32(raw, base + 12)
            rawSize = le32(raw, base + 16)
            rawPointer = le32(raw, base + 20)
        }
    }
}

private func le16(_ bytes: Bytes, _ at: Int) -> UInt16 {
    UInt16(bytes[at]) | UInt16(bytes[at + 1]) << 8
}

private func le32(_ bytes: Bytes, _ at: Int) -> UInt32 {
    UInt32(le16(bytes, at)) | UInt32(le16(bytes, at + 2)) << 16
}
