@testable import HubRules

/// Builds a small PE image in memory: DOS header, NT headers, a section table and an import directory.
struct PEImage {
    var machine: UInt16 = PEFacts.machineAMD64
    var magic: UInt16 = 0x20b
    var optionalSize: UInt16?
    var sections: [(name: String, rva: UInt32, virtualSize: UInt32, rawSize: UInt32, rawPointer: UInt32)] = [
        (".text", 0x1000, 0x200, 0x200, 0x400),
        (".idata", 0x2000, 0x400, 0x400, 0x600)
    ]
    /// Imported DLL names, written into .idata after the descriptors.
    var imports: [String] = ["KERNEL32.dll", "user32.dll"]
    var importRVA: UInt32? = 0x2000
    var lfanew: UInt32 = 0x80

    var bytes: [UInt8] {
        let tableEnd = Int(lfanew) + 24 + Int(optionalSize ?? 240) + sections.count * 40
        var out = [UInt8](repeating: 0, count: max(0xa00, tableEnd + 0x100))
        put16(&out, 0, 0x5a4d)
        put32(&out, 0x3c, lfanew)
        let nt = Int(lfanew)
        put32(&out, nt, 0x4550)
        put16(&out, nt + 4, machine)
        put16(&out, nt + 6, UInt16(sections.count))
        let directories = magic == 0x20b ? 112 : 96
        let size = optionalSize ?? UInt16(directories + 16 * 8)
        put16(&out, nt + 20, size)
        put16(&out, nt + 24, magic)
        if let importRVA { put32(&out, nt + 24 + directories + 8, importRVA) }
        let table = nt + 24 + Int(size)
        for (index, section) in sections.enumerated() {
            let base = table + index * 40
            for (offset, byte) in section.name.utf8.prefix(8).enumerated() { out[base + offset] = byte }
            put32(&out, base + 8, section.virtualSize)
            put32(&out, base + 12, section.rva)
            put32(&out, base + 16, section.rawSize)
            put32(&out, base + 20, section.rawPointer)
        }
        // import descriptors at .idata (file 0x600), names from 0x700 on
        var namePos = 0x700
        for (index, name) in imports.enumerated() {
            put32(&out, 0x600 + index * 20 + 12, UInt32(0x2000 + namePos - 0x600))
            for (offset, byte) in name.utf8.enumerated() { out[namePos + offset] = byte }
            namePos += name.utf8.count + 1
        }
        return out
    }
}

private func put16(_ bytes: inout [UInt8], _ at: Int, _ value: UInt16) {
    bytes[at] = UInt8(value & 0xff)
    bytes[at + 1] = UInt8(value >> 8)
}

private func put32(_ bytes: inout [UInt8], _ at: Int, _ value: UInt32) {
    put16(&bytes, at, UInt16(value & 0xffff))
    put16(&bytes, at + 2, UInt16(value >> 16))
}

func facts(_ image: PEImage) -> PEFacts? { PEFacts.read(from: PEBytes(image.bytes)) }

func names(_ list: [Bytes]) -> [String] { list.map { String(decoding: $0, as: UTF8.self) } }
