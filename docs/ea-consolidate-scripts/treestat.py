#!/usr/bin/env python3
"""Read-only tree statistics: treestat.py DIR [--expect FILES BYTES]

Walks DIR without following symlinks (lstat only) and prints one line:
  files=N bytes=N dirs=N symlinks=N nlink_gt1=N dsstore=N other=N
"files" are regular files (S_ISREG), "bytes" the sum of their st_size, "dirs" the
sub-directories (the root is not counted), "dsstore" the regular files named .DS_Store.
With --expect FILES BYTES the exit status is 0 only when both match (1 otherwise).
Exit 2 on a usage or I/O error.
"""
import os
import stat
import sys


def walk(root):
    files = nbytes = dirs = links = multi = dsstore = other = 0
    stack = [root]
    while stack:
        d = stack.pop()
        with os.scandir(d) as it:
            for e in it:
                st = e.stat(follow_symlinks=False)
                m = st.st_mode
                if stat.S_ISDIR(m):
                    dirs += 1
                    stack.append(e.path)
                elif stat.S_ISREG(m):
                    files += 1
                    nbytes += st.st_size
                    if st.st_nlink > 1:
                        multi += 1
                    if e.name == ".DS_Store":
                        dsstore += 1
                elif stat.S_ISLNK(m):
                    links += 1
                else:
                    other += 1
    return dict(files=files, bytes=nbytes, dirs=dirs, symlinks=links,
                nlink_gt1=multi, dsstore=dsstore, other=other)


def main(argv):
    if len(argv) not in (2, 5) or (len(argv) == 5 and argv[2] != "--expect"):
        print(__doc__, file=sys.stderr)
        return 2
    root = argv[1]
    try:
        if not os.path.isdir(root) or os.path.islink(root):
            print("not a directory (or a symlink): %s" % root, file=sys.stderr)
            return 2
        s = walk(root)
    except OSError as exc:
        print("error: %s" % exc, file=sys.stderr)
        return 2
    print(" ".join("%s=%d" % kv for kv in s.items()))
    if len(argv) == 5:
        return 0 if (s["files"] == int(argv[3]) and s["bytes"] == int(argv[4])) else 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
