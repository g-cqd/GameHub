"""Inventory literal resource-ID uses in a complete mapped x64 PE capture.

This is a bounded candidate finder, not a proof that resources have no consumer.
Obfuscated or computed IDs and indirect callers are outside its coverage.
"""
import argparse
import bisect
import hashlib
import json
import struct
import time
from pathlib import Path
from capstone import Cs, CS_ARCH_X86, CS_MODE_64, CS_OP_IMM

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('image', type=Path)
args = parser.parse_args()
started = time.monotonic()
if args.image.stat().st_size > 128 * 1024 * 1024:
    raise SystemExit('Image exceeds 128 MiB bound')
data = args.image.read_bytes()
def read(fmt, offset):
    size = struct.calcsize(fmt)
    if offset < 0 or offset + size > len(data):
        raise ValueError('PE field outside capture')
    return struct.unpack_from(fmt, data, offset)
if data[:2] != b'MZ':
    raise SystemExit('Expected mapped PE header at capture offset zero')
pe, = read('<I', 0x3c)
if data[pe:pe+4] != b'PE\0\0':
    raise SystemExit('Invalid PE signature')
machine, sections = read('<HH', pe + 4)
optional_size, = read('<H', pe + 20)
optional = pe + 24
magic, = read('<H', optional)
if machine != 0x8664 or magic != 0x20b or sections > 96:
    raise SystemExit('Expected bounded x64 PE32+ image')
base, = read('<Q', optional + 24)
image_size, = read('<I', optional + 56)
if image_size != len(data):
    raise SystemExit('Capture must exactly match SizeOfImage')
directory_count, = read('<I', optional + 108)
if directory_count < 4 or optional_size < 112 + 4 * 8:
    raise SystemExit('Missing exception directory')
pdata, pdata_size = read('<II', optional + 112 + 3 * 8)
if pdata_size % 12 or pdata + pdata_size > len(data):
    raise SystemExit('Invalid exception directory')
functions = []
for offset in range(pdata, pdata + pdata_size, 12):
    start, end, unwind = read('<III', offset)
    if 0 < start < end <= len(data):
        functions.append((start, end))
functions.sort()
starts = [x[0] for x in functions]
regions = []
for i in range(sections):
    offset = optional + optional_size + i * 40
    virtual_size, rva = read('<II', offset + 8)
    flags, = read('<I', offset + 36)
    if flags & 0x20000000:
        if rva + virtual_size > len(data):
            raise SystemExit('Executable section exceeds capture')
        regions.append((rva, rva + virtual_size))
candidates = {}
for resource_id in [10001, 10100, 10150]:
    needle = struct.pack('<I', resource_id)
    for begin, end in regions:
        position = begin
        while True:
            hit = data.find(needle, position, end)
            if hit < 0:
                break
            position = hit + 1
            if time.monotonic() - started > 60:
                raise SystemExit('Analysis deadline exceeded; result incomplete')
            index = bisect.bisect_right(starts, hit) - 1
            function = functions[index] if index >= 0 and hit < functions[index][1] else None
            candidates.setdefault(function, []).append((hit, resource_id))
            if sum(len(v) for v in candidates.values()) > 256:
                raise SystemExit('Candidate budget exceeded; result incomplete')
decoder = Cs(CS_ARCH_X86, CS_MODE_64)
decoder.detail = True
results = []
for function, hits in candidates.items():
    row = {'function_rva': [hex(x) for x in function] if function else None,
           'literal_hits': [{'rva': hex(h), 'resource_id': rid} for h, rid in hits],
           'decoded_immediate_uses': []}
    if function and function[1] - function[0] <= 65536:
        for instruction in decoder.disasm(data[function[0]:function[1]], base + function[0]):
            if time.monotonic() - started > 60:
                raise SystemExit('Analysis deadline exceeded; result incomplete')
            for hit, rid in hits:
                if instruction.address <= base + hit < instruction.address + instruction.size:
                    if any(op.type == CS_OP_IMM and op.imm == rid for op in instruction.operands):
                        row['decoded_immediate_uses'].append({'address': hex(instruction.address),
                            'resource_id': rid, 'instruction': instruction.mnemonic + ' ' + instruction.op_str})
    results.append(row)
print(json.dumps({'sha256': hashlib.sha256(data).hexdigest(), 'base': hex(base),
    'executable_regions': len(regions), 'functions': len(functions),
    'coverage': 'Four-byte literal IDs in executable sections; linear decode from exception-table start. Computed IDs, overlapping code and unrecognized instruction paths excluded.',
    'seconds': round(time.monotonic() - started, 3), 'results': results}, indent=2))
