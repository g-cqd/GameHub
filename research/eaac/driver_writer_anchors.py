"""Inventory driver-path and writer-import anchors, without executing the PE.

Only plain literals and direct RIP-relative references are covered. A candidate
instruction is not proof of reachable control flow or of driver ownership.
"""
import argparse
import bisect
import hashlib
import json
import re
import signal
import struct
from pathlib import Path
from capstone import Cs, CS_ARCH_X86, CS_MODE_64

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path)
parser.add_argument('capture', type=Path)
args = parser.parse_args()
signal.alarm(60)
results = []
for path, mapped in [(args.source, False), (args.capture, True)]:
    if path.stat().st_size > 128 * 1024 * 1024:
        raise SystemExit('Input exceeds 128 MiB')
    data = path.read_bytes()
    def read(fmt, offset):
        size = struct.calcsize(fmt)
        if not 0 <= offset <= len(data) - size:
            raise ValueError('Field exceeds artifact')
        return struct.unpack_from(fmt, data, offset)
    if data[:2] != b'MZ':
        raise SystemExit('Missing DOS header')
    pe, = read('<I', 60)
    if data[pe:pe+4] != b'PE\0\0':
        raise SystemExit('Missing PE header')
    machine, count = read('<HH', pe + 4)
    optional_size, = read('<H', pe + 20)
    optional = pe + 24
    magic, = read('<H', optional)
    if machine != 0x8664 or magic != 0x20b or count > 96:
        raise SystemExit('Unsupported PE layout')
    base, = read('<Q', optional + 24)
    image_size, = read('<I', optional + 56)
    if mapped and image_size != len(data):
        raise SystemExit('Mapped capture is incomplete')
    sections = []
    for i in range(count):
        offset = optional + optional_size + i * 40
        vs, va, rs, rp = read('<IIII', offset + 8)
        flags, = read('<I', offset + 36)
        sections.append((va, vs, rp, rs, flags))
    def raw(rva, size):
        if mapped:
            if rva < 0 or rva + size > len(data):
                raise ValueError('RVA exceeds capture')
            return rva
        for va, vs, rp, rs, flags in sections:
            if va <= rva and rva - va <= rs and size <= rs - (rva - va):
                start = rp + rva - va
                if start + size <= len(data):
                    return start
        raise ValueError('RVA is not raw-backed')
    def rva_of(offset):
        if mapped:
            return offset
        for va, vs, rp, rs, flags in sections:
            if rp <= offset < rp + rs:
                return va + offset - rp
        return None
    def cstring(rva):
        offset = raw(rva, 1)
        end = data.find(b'\0', offset, min(offset+256, len(data)))
        if end < 0:
            raise ValueError('Unterminated name')
        return data[offset:end].decode('ascii')
    directory_count, = read('<I', optional + 108)
    if directory_count < 4 or optional_size < 144:
        raise SystemExit('Missing required PE directories')
    pdata, pdata_size = read('<II', optional + 136)
    functions = []
    if pdata_size % 12:
        raise SystemExit('Invalid exception directory')
    for offset in range(raw(pdata, pdata_size), raw(pdata, pdata_size)+pdata_size, 12):
        start, end, unwind = read('<III', offset)
        if 0 < start < end <= image_size:
            functions.append((start, end))
    functions.sort()
    starts = [f[0] for f in functions]
    def function_of(rva):
        i = bisect.bisect_right(starts, rva)-1
        return functions[i] if i >= 0 and rva < functions[i][1] else None
    anchors = []
    lower = data.lower()
    for name in ['eaanticheat.sys', '\\drivers\\', '.sys', 'packer_functionality']:
        for encoding in ['ascii', 'utf-16-le']:
            needle = name.encode(encoding)
            position = 0
            hits = 0
            while True:
                hit = lower.find(needle, position)
                if hit < 0:
                    break
                position = hit+1
                rva = rva_of(hit)
                if rva is not None:
                    anchors.append({'kind': 'literal', 'name': name, 'encoding': encoding,
                                    'rva': rva, 'bytes': len(needle)})
                hits += 1
                if hits >= 64:
                    raise SystemExit('Literal hit budget exceeded; incomplete')
    # Use original lookup thunks, not resolved capture IAT contents.
    imports, import_size = read('<II', optional + 120)
    selected_imports = []
    if imports:
        for i in range(min(import_size // 20, 256)):
            desc = read('<IIIII', raw(imports+i*20, 20))
            lookup, timestamp, chain, dll_name, iat = desc
            if not any(desc):
                break
            if not lookup:
                selected_imports.append({'limitation': 'No original lookup thunk', 'dll': cstring(dll_name)})
                continue
            for j in range(4096):
                value, = read('<Q', raw(lookup+j*8, 8))
                if not value:
                    break
                if value >> 63:
                    continue
                name = cstring(value+2)
                if re.search(r'(CreateFile|WriteFile|FindResource|LoadResource|ReadFile|WinHttp|URLDownload|GetProcAddress)', name):
                    item = {'kind': 'import', 'name': name, 'dll': cstring(dll_name), 'rva': iat+j*8, 'bytes': 8}
                    selected_imports.append(item)
                    anchors.append(item)
    references = []
    decoder = Cs(CS_ARCH_X86, CS_MODE_64)
    patterns = [re.compile(b'[\x48-\x4f][\x8d\x8b][\x05\x0d\x15\x1d\x25\x2d\x35\x3d]....', re.S),
                re.compile(b'\xff[\x15\x25]....', re.S)]
    for va, vs, rp, rs, flags in sections:
        if not flags & 0x20000000:
            continue
        size = vs if mapped else min(vs, rs)
        start = raw(va, size)
        region = data[start:start+size]
        for pattern in patterns:
            for match in pattern.finditer(region):
                instruction = match.group()
                rva = va + match.start()
                displacement = struct.unpack_from('<i', instruction, len(instruction)-4)[0]
                target = rva + len(instruction) + displacement
                for anchor in anchors:
                    if anchor['rva'] <= target < anchor['rva']+anchor['bytes']:
                        decoded = next(decoder.disasm(instruction, base+rva, count=1), None)
                        function = function_of(rva)
                        references.append({'anchor': anchor, 'instruction_va': hex(base+rva),
                            'instruction': (decoded.mnemonic+' '+decoded.op_str) if decoded else None,
                            'function_rva': [hex(x) for x in function] if function else None,
                            'flow_validated': False})
                        if len(references) > 128:
                            raise SystemExit('Reference output budget exceeded; incomplete')
    results.append({'path': str(path), 'mapped': mapped, 'sha256': hashlib.sha256(data).hexdigest(),
        'base': hex(base), 'literal_anchors': [x for x in anchors if x['kind']=='literal'],
        'selected_imports': selected_imports, 'references': references,
        'coverage': 'Plain ASCII/UTF16 literals; original import lookup; bounded direct RIP-relative references. Computed names, encrypted imports and indirect calls excluded.'})
print(json.dumps(results, indent=2))
