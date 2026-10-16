"""Derive raw syscall numbers from a bounded straight-line captured code suffix.

Reads only captured RIP-relative key words. Unknown instructions, branches and
unknown registers stop derivation. Candidate calls are not validated live paths.
"""
import bisect
import collections
import hashlib
import json
import re
import signal
import struct
from pathlib import Path
from capstone import Cs, CS_ARCH_X86, CS_MODE_64, CS_OP_REG, CS_OP_IMM, CS_OP_MEM
from capstone.x86_const import X86_REG_EAX, X86_REG_RAX, X86_REG_RIP

signal.alarm(60)
path = Path('/Users/gc/eaac-archive/eaac-acquisition-20261015/codex-service-complete-module.bin')
if path.stat().st_size > 128 * 1024 * 1024:
    raise SystemExit('Capture size bound exceeded')
data = path.read_bytes()
digest = hashlib.sha256(data).hexdigest()
if digest != 'ed84fa5a5b24c6bdcf5f0d34c93eedbf9fcd38fdd2fe689c45356984cad940eb':
    raise SystemExit('Unexpected capture identity')
pe = struct.unpack_from('<I', data, 60)[0]
base = struct.unpack_from('<Q', data, pe + 48)[0]
size = struct.unpack_from('<I', data, pe + 80)[0]
if data[:2] != b'MZ' or data[pe:pe+4] != b'PE\0\0' or size != len(data):
    raise SystemExit('Incomplete mapped PE')
n = struct.unpack_from('<H', data, pe+6)[0]
optional_size = struct.unpack_from('<H', data, pe+20)[0]
regions = []
for i in range(n):
    offset = pe+24+optional_size+i*40
    length, rva = struct.unpack_from('<II', data, offset+8)
    flags = struct.unpack_from('<I', data, offset+36)[0]
    if flags & 0x20000000:
        if rva+length > size:
            raise SystemExit('Section exceeds capture')
        regions.append((rva, rva+length))
pdata, pdata_size = struct.unpack_from('<II', data, pe+24+136)
if pdata_size % 12 or pdata+pdata_size > size:
    raise SystemExit('Invalid exception directory')
functions = []
for offset in range(pdata, pdata+pdata_size, 12):
    start, end, unwind = struct.unpack_from('<III', data, offset)
    if 0 < start < end <= size:
        functions.append((start, end))
functions.sort()
starts = [f[0] for f in functions]
def function_of(rva):
    index = bisect.bisect_right(starts, rva)-1
    return functions[index] if index >= 0 and rva < functions[index][1] else None

decoder = Cs(CS_ARCH_X86, CS_MODE_64)
decoder.detail = True
wrappers = []
raw_sites = 0
for begin, end in regions:
    position = begin
    while True:
        site = data.find(b'\x0f\x05', position, end)
        if site < 0:
            break
        position = site+2
        raw_sites += 1
        if raw_sites > 10000:
            raise SystemExit('Raw site budget exceeded')
        derived = None
        # Require a reset of the accumulator; never supply a guessed input register.
        for candidate in range(max(begin, site-64), site):
            if data[candidate] != 0xb8 and data[candidate:candidate+2] != b'\x48\xb8':
                continue
            value = None
            keys = []
            suffix = []
            valid = True
            consumed = 0
            for ins in decoder.disasm(data[candidate:site+2], base+candidate):
                consumed += ins.size
                suffix.append(hex(ins.address)+' '+ins.mnemonic+' '+ins.op_str)
                if ins.mnemonic == 'syscall':
                    if ins.address != base+site:
                        valid = False
                    break
                operands = ins.operands
                accumulator = operands and operands[0].type == CS_OP_REG and operands[0].reg in (X86_REG_EAX,X86_REG_RAX)
                if accumulator:
                    width = operands[0].size*8
                    mask = (1 << width)-1
                    if len(operands) != 2:
                        valid = False; break
                    source = operands[1]
                    if source.type == CS_OP_IMM:
                        argument = source.imm & mask
                    elif source.type == CS_OP_MEM and source.mem.base == X86_REG_RIP and not source.mem.index:
                        address = ins.address+ins.size+source.mem.disp-base
                        if not 0 <= address <= size-source.size:
                            valid = False; break
                        argument = int.from_bytes(data[address:address+source.size], 'little')
                        keys.append({'rva':hex(address),'bytes':source.size,'value':hex(argument)})
                    else:
                        valid = False; break
                    if ins.mnemonic in ('mov','movabs'):
                        value = argument
                    elif value is None:
                        valid = False; break
                    elif ins.mnemonic == 'xor': value ^= argument
                    elif ins.mnemonic == 'add': value += argument
                    elif ins.mnemonic == 'sub': value -= argument
                    elif ins.mnemonic in ('rol','ror'):
                        value &= mask
                        shift = argument % width
                        if shift:
                            value = ((value << shift) | (value >> (width-shift))) if ins.mnemonic == 'rol' else ((value >> shift) | (value << (width-shift)))
                    else:
                        valid = False; break
                    value &= mask
                elif ins.mnemonic not in ('mov','movabs','movsxd','nop'):
                    valid = False; break
            if valid and value is not None and consumed == site+2-candidate:
                derived = {'suffix_rva':hex(candidate),'syscall_rva':hex(site),'number':value,
                    'key_reads':keys,'instructions':suffix,'function_rva':function_of(site)}
                break
        if derived:
            wrappers.append(derived)
header = Path('/Users/gc/Developer/wine/dlls/ntdll/unix/win10_19045_syscalls.h').read_text()
names = {int(a,16):b for a,b in re.findall(r'\{\s*(0x[0-9a-fA-F]+),\s*"([^"]+)"', header)}
selected = [x for x in wrappers if names.get(x['number']) in ['NtCreateFile','NtOpenFile','NtWriteFile','NtWriteFileGather']]
for row in selected:
    row['name_in_win10_19045_table'] = names[row['number']]
    row['direct_call_candidates'] = []
for begin, end in regions:
    position = begin
    while selected:
        hit = data.find(b'\xe8', position, end-4)
        if hit < 0:
            break
        position = hit+1
        target = hit+5+struct.unpack_from('<i', data, hit+1)[0]
        for row in selected:
            function = row['function_rva']
            low, high = function if function else (int(row['suffix_rva'],16),int(row['syscall_rva'],16)+2)
            if low <= target < high and len(row['direct_call_candidates']) < 32:
                row['direct_call_candidates'].append({'call_rva':hex(hit),'target_rva':hex(target),
                    'caller_function_rva':function_of(hit),'flow_validated':False})
summary = collections.Counter(names.get(x['number'],hex(x['number'])) for x in wrappers)
print(json.dumps({'capture_sha256':digest,'base':hex(base),'raw_opcode_sites':raw_sites,
    'derived_suffixes':len(wrappers),'derived_name_counts':dict(summary),'selected_writer_wrappers':selected,
    'coverage':'Straight-line accumulator reset and supported operations with captured key bytes only. Names use local Win10 table. Opcode and direct-call candidates may be unreachable; no syscall or target execution performed. Writer arguments, caller reachability and byte sources remain unknown.'},indent=2))
