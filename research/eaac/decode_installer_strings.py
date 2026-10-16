"""Decode evidenced installer string helpers; verify their vector masks agree.

Supports only the two helpers inspected in installer SHA-256 d0396b7f... .
This performs static arithmetic, not execution of the Windows installer.
"""
import argparse
import hashlib
import json
import re
import struct
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('image', type=Path)
parser.add_argument('analysis', type=Path)
parser.add_argument('--helper', choices=['cli', 'registry'], required=True)
args = parser.parse_args()
if args.image.stat().st_size > 320 * 1024 * 1024 or args.analysis.stat().st_size > 1024 * 1024:
    raise SystemExit('Input size budget exceeded')
data = args.image.read_bytes()
expected = 'd0396b7fe0331cef94278ed015c93012cd9ab67eb02e3775abd6660e96f5b6eb'
digest = hashlib.sha256(data).hexdigest()
if digest != expected:
    raise SystemExit('Unvalidated installer version; helper offsets may differ')
pe = struct.unpack_from('<I', data, 60)[0]
count = struct.unpack_from('<H', data, pe + 6)[0]
optional_size = struct.unpack_from('<H', data, pe + 20)[0]
base = struct.unpack_from('<Q', data, pe + 48)[0]

def raw_at(rva, size):
    """Read only a fully backed RVA range from the validated artifact."""
    for i in range(count):
        _, va, raw_size, raw_pointer = struct.unpack_from('<IIII', data, pe + 24 + optional_size + i * 40 + 8)
        if va <= rva and rva - va <= raw_size and size <= raw_size - (rva - va):
            start = raw_pointer + rva - va
            if start + size <= len(data):
                return data[start:start + size]
    raise ValueError('RVA range is not fully backed')

if args.helper == 'cli':
    helper, table, xor = '14002ec80', 0x9f2e0, 0x7d
    vectors, width = [0x9f1f0, 0x9f200, 0x9f210, 0x9f220], 4
else:
    helper, table, xor = '140040af0', 0x9fba0, 0xffffffb0
    vectors, width = [0x9fb80, 0x9fb90], 8
key = raw_at(table, 16)

def mask(index):
    signed = key[index & 15] if key[index & 15] < 128 else key[index & 15] - 256
    value = (signed ^ xor) & 0xffffffff
    quotient = ((((value + index) & 0xffffffff) * 0x80808081) >> 39)
    return ((quotient & 255) + (value & 255) + index) & 255

vector_mask = b''.join(raw_at(rva, width) for rva in vectors)
scalar_mask = bytes(mask(i) for i in range(16))
if vector_mask != scalar_mask:
    raise SystemExit('Vector/scalar prefix disagreement; decoded results rejected')
text = args.analysis.read_text()
pairs = sorted(set((int(a, 16), int(b, 0)) for a, b in re.findall(
    r'FUN_' + helper + r'\((0x[0-9a-f]+),(0x[0-9a-f]+|[0-9]+)\)', text)))
if not pairs:
    raise SystemExit('No inspected helper calls in analysis')
results = []
for address, length in pairs:
    if not 0 < length <= 256:
        raise SystemExit('Literal exceeds decoding budget')
    raw = raw_at(address - base, length)
    decoded = bytes(value ^ mask(i) for i, value in enumerate(raw))
    if not decoded.endswith(b'\0'):
        raise SystemExit('Expected terminated string; decoded result rejected')
    results.append({'address': hex(address), 'length': length, 'decoded': decoded[:-1].decode('ascii')})
print(json.dumps({'image_sha256': digest,
    'analysis_sha256': hashlib.sha256(args.analysis.read_bytes()).hexdigest(),
    'helper': helper, 'vector_scalar_prefix_agree': True,
    'coverage': 'Identified scalar arithmetic and inspected vector-prefix masks on this artifact only; no native execution claimed.',
    'results': results}, indent=2))
