"""Row-wise 3-way merge of markdown table conflict blocks.

Rows keyed by first cell. One-sided changes are taken; rows changed on both
sides are printed (with a word diff hint) and left as a MANUAL marker unless an
override is supplied in OVERRIDES (key -> full row text).
"""
import re
import sys
import difflib

path = sys.argv[1]
mode = sys.argv[2] if len(sys.argv) > 2 else "report"
OVERRIDES = {}
if len(sys.argv) > 3:
    import json
    OVERRIDES = json.load(open(sys.argv[3]))

s = open(path, encoding="utf-8").read()
pat = re.compile(r"<<<<<<< ours\n(.*?)\|\|\|\|\|\|\| base\n(.*?)=======\n(.*?)>>>>>>> theirs\n", re.S)


def rows(txt):
    out = []
    for l in txt.split("\n"):
        if l.strip():
            out.append((l.split("|")[1].strip(), l))
    return out


def merge(m):
    o, b, t = (dict(rows(x)) for x in m.groups())
    order_t = [k for k, _ in rows(m.group(3))]
    order_o = [k for k, _ in rows(m.group(1))]
    keys = list(order_t)
    for i, k in enumerate(order_o):
        if k not in keys:
            prev = order_o[i - 1] if i else None
            keys.insert(keys.index(prev) + 1 if prev in keys else 0, k)
    res = []
    for k in keys:
        ov, bv, tv = o.get(k), b.get(k), t.get(k)
        if ov == tv:
            pick = ov
        elif ov == bv:
            pick = tv
        elif tv == bv:
            pick = ov
        elif k in OVERRIDES:
            pick = OVERRIDES[k]
        else:
            print(f"BOTH CHANGED: {k}")
            sm = difflib.SequenceMatcher(None, bv or "", ov or "")
            for op, a1, a2, b1, b2 in sm.get_opcodes():
                if op != "equal":
                    print(f"  ours {op}: base[{(bv or '')[a1:a2]!r}] -> ours[{(ov or '')[b1:b2]!r}]")
            sm = difflib.SequenceMatcher(None, bv or "", tv or "")
            for op, a1, a2, b1, b2 in sm.get_opcodes():
                if op != "equal":
                    print(f"  theirs {op}: base[{(bv or '')[a1:a2]!r}] -> theirs[{(tv or '')[b1:b2]!r}]")
            pick = "MANUAL::" + k
        if pick is None:
            print(f"DELETED on one side: {k}")
            continue
        res.append(pick)
    return "\n".join(res) + "\n"


new = pat.sub(merge, s)
if mode == "write":
    if "MANUAL::" in new:
        sys.exit("manual rows remain; not written")
    open(path, "w", encoding="utf-8").write(new)
    print("written")
