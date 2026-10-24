#!/usr/bin/env python3
"""resolve.py FILE INDEX  (replacement text on stdin)

Replaces the INDEX-th (1-based) conflict block (<<<<<<< ... >>>>>>>) in FILE
with stdin verbatim. Special stdin values: '@ours' / '@theirs' / '@base' pick
that side of THIS block only (used after reading both sides).
"""
import sys

path, idx = sys.argv[1], int(sys.argv[2])
repl = sys.stdin.read()
lines = open(path, encoding="utf-8").read().split("\n")
out, i, n = [], 0, 0
while i < len(lines):
    if lines[i].startswith("<<<<<<< "):
        n += 1
        j = i
        while not lines[j].startswith(">>>>>>> "):
            j += 1
        if n == idx:
            block = lines[i + 1 : j]
            b = next(k for k, l in enumerate(block) if l.startswith("||||||| "))
            e = next(k for k, l in enumerate(block) if l == "=======")
            sides = {"@ours": block[:b], "@base": block[b + 1 : e], "@theirs": block[e + 1 :]}
            key = repl.strip()
            if key in sides:
                out.extend(sides[key])
            else:
                r = repl[:-1] if repl.endswith("\n") else repl
                if r != "":
                    out.extend(r.split("\n"))
            out.extend(lines[j + 1 :])
            open(path, "w", encoding="utf-8").write("\n".join(out))
            print(f"{path}: block {idx} resolved; remaining={sum(l.startswith('<<<<<<< ') for l in out)}")
            sys.exit(0)
        out.extend(lines[i : j + 1])
        i = j + 1
        continue
    out.append(lines[i])
    i += 1
sys.exit(f"block {idx} not found in {path}")
