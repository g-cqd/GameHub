#!/usr/bin/env python3
"""nfs_mirror.py: preflight, hash, remove and verify the NFS hard-link mirror (stage S3).

usage: nfs_mirror.py --mirror M --real R --hash-file F --files N --bytes N [--apply] [--stage S3] [--log FILE]

The mirror M must consist only of directories and regular files; every regular file must have
st_nlink == 2 and the same (st_dev, st_ino) as the file with the same relative path under R; there
must be exactly N of them; R must hold exactly N files / N bytes (a stray Finder .DS_Store is ignored) and no file outside the mirror set
with st_nlink > 1. --apply then writes sha256 of every R file to F (kept when F is from today and
older than every R file), unlinks the mirror files (re-checking each one immediately before its
unlink), removes the emptied mirror directories bottom-up and finally M itself (nothing above M).
Afterwards every R file must have st_nlink == 1, unchanged size and unchanged sha256.
Default is a dry run (preflight only; nothing is hashed or written).
Exit: 0 ok; 2 refused (preflight); 3 failure after changes started.
"""
import argparse
import datetime
import hashlib
import os
import stat
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from regrewrite import Out, DEFAULT_LOG  # noqa: E402


class Refusal(Exception):
    pass


class Failure(Exception):
    pass


def walk(root, what):
    """-> (dirs, files): relative paths; files maps rel -> os.stat_result (lstat)."""
    dirs, files = [], {}
    stack = [""]
    while stack:
        rel = stack.pop()
        with os.scandir(os.path.join(root, rel) if rel else root) as it:
            for e in it:
                r = os.path.join(rel, e.name) if rel else e.name
                st = e.stat(follow_symlinks=False)
                if stat.S_ISDIR(st.st_mode):
                    dirs.append(r)
                    stack.append(r)
                elif stat.S_ISREG(st.st_mode):
                    files[r] = st
                else:
                    raise Refusal("%s holds a non-regular entry (symlink, socket, device...): %s" % (what, os.path.join(root, r)))
    return sorted(dirs), files


def drop_finder_noise(rfiles, mfiles):
    """Finder re-creates .DS_Store files at will; one outside the mirror set is not game data."""
    ignored = sorted(r for r in rfiles if r not in mfiles and os.path.basename(r) == ".DS_Store")
    return {r: st for r, st in rfiles.items() if r not in ignored}, ignored


def sha256_of(path):
    with open(path, "rb") as fh:
        return hashlib.file_digest(fh, "sha256").hexdigest()


def real_dir(path, what):
    if os.path.islink(path) or not os.path.isdir(path) or os.path.realpath(path) != os.path.abspath(path):
        raise Refusal("%s is not a plain directory path without symlink components: %s" % (what, path))


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--mirror", required=True)
    ap.add_argument("--real", required=True)
    ap.add_argument("--hash-file", required=True)
    ap.add_argument("--files", type=int, required=True)
    ap.add_argument("--bytes", type=int, required=True)
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--stage", default="S3")
    ap.add_argument("--log", default=DEFAULT_LOG)
    try:
        a = ap.parse_args(argv)
    except SystemExit as e:
        return 64 if e.code else 0
    out = Out(a.apply, a.stage, a.log)
    M, R = a.mirror, a.real
    changed = False
    try:
        real_dir(M, "mirror")
        real_dir(R, "real library")
        mdirs, mfiles = walk(M, "mirror")
        out.log("mirror %s: %d dirs, %d regular files" % (M, len(mdirs), len(mfiles)))
        if len(mfiles) != a.files:
            raise Refusal("mirror holds %d regular files, expected exactly %d" % (len(mfiles), a.files))
        for rel, st in sorted(mfiles.items()):
            if st.st_nlink != 2:
                raise Refusal("mirror file has st_nlink=%d (need 2): %s" % (st.st_nlink, rel))
            try:
                rst = os.lstat(os.path.join(R, rel))
            except OSError:
                raise Refusal("mirror file has no counterpart under the real library: %s" % rel)
            if not stat.S_ISREG(rst.st_mode) or (rst.st_dev, rst.st_ino) != (st.st_dev, st.st_ino):
                raise Refusal("mirror file is not the same inode as the real file: %s" % rel)
        rdirs, rfiles = walk(R, "real library")
        rfiles, ignored = drop_finder_noise(rfiles, mfiles)
        if ignored:
            out.log("ignoring %d Finder .DS_Store file(s) outside the mirror set (not game data): %s" % (len(ignored), ", ".join(ignored[:3])))
        extra_multi = [r for r, st in rfiles.items() if r not in mfiles and st.st_nlink > 1]
        if extra_multi:
            raise Refusal("real library has file(s) outside the mirror set with st_nlink>1: %s" % ", ".join(extra_multi[:5]))
        rbytes = sum(st.st_size for st in rfiles.values())
        if len(rfiles) != a.files or rbytes != a.bytes:
            raise Refusal("real library holds %d files / %d bytes, expected %d / %d" % (len(rfiles), rbytes, a.files, a.bytes))
        out.log("preflight ok: %d mirror files, all nlink=2 and inode-identical to %s; real library %d files / %d bytes" % (
            len(mfiles), R, len(rfiles), rbytes))
        sizes = {r: st.st_size for r, st in rfiles.items()}

        hf = a.hash_file
        keep = False
        if os.path.exists(hf):
            hst = os.stat(hf)
            same_day = datetime.date.fromtimestamp(hst.st_mtime) == datetime.date.today()
            with open(hf, encoding="utf-8") as fh:
                have = {ln.rstrip("\n").split("  ", 1)[1] for ln in fh if "  " in ln}
            newer = [r for r, st in rfiles.items() if st.st_mtime_ns > hst.st_mtime_ns]
            keep = same_day and have == set(rfiles) and not newer
            out.log("hash file %s exists: dated today=%s, covers all %d files=%s, files modified after it=%d -> %s" % (
                hf, same_day, len(rfiles), have == set(rfiles), len(newer), "keep" if keep else "recompute"))
        else:
            out.log("hash file %s does not exist -> would compute" % hf)
        if not a.apply:
            out.log("dry-run: would %s sha256 of %d real files, unlink %d mirror files, rmdir %d mirror dirs bottom-up and %s, then verify nlink=1/sizes/sha256" % (
                "keep" if keep else "write", len(rfiles), len(mfiles), len(mdirs), M))
            return 0

        if not keep:
            out.log("hashing %d real files (%d bytes) into %s" % (len(rfiles), rbytes, hf))
            lines = []
            for i, rel in enumerate(sorted(rfiles), 1):
                lines.append("%s  %s\n" % (sha256_of(os.path.join(R, rel)), rel))
                if i % 20 == 0:
                    out.log("  hashed %d/%d" % (i, len(rfiles)))
            tmp = hf + ".tmp.%d" % os.getpid()
            with open(tmp, "w", encoding="utf-8") as fh:
                fh.writelines(lines)
                fh.flush()
                os.fsync(fh.fileno())
            os.replace(tmp, hf)
            out.log("wrote %s (%d lines)" % (hf, len(lines)))
        with open(hf, encoding="utf-8") as fh:
            before = dict((ln.rstrip("\n").split("  ", 1)[1], ln.split("  ", 1)[0]) for ln in fh)

        changed = True
        for n, rel in enumerate(sorted(mfiles), 1):
            mp, rp = os.path.join(M, rel), os.path.join(R, rel)
            ms, rs = os.lstat(mp), os.lstat(rp)
            if not (stat.S_ISREG(ms.st_mode) and ms.st_nlink == 2 and stat.S_ISREG(rs.st_mode)
                    and (ms.st_dev, ms.st_ino) == (rs.st_dev, rs.st_ino)):
                raise Failure("mirror file changed before its unlink, stopping: %s" % rel)
            parent = os.path.dirname(mp)
            if os.path.realpath(parent) != parent or not (mp + os.sep).startswith(M + os.sep):
                raise Failure("refusing to unlink %s: its directory is not a plain path under the mirror root" % mp)
            os.unlink(mp)
            out.log("unlinked %d/%d: %s" % (n, len(mfiles), mp))
        for rel in sorted(mdirs, key=lambda r: (r.count(os.sep), r), reverse=True):
            dp = os.path.join(M, rel)
            if os.path.realpath(dp) != dp or not (dp + os.sep).startswith(M + os.sep):
                raise Failure("refusing to rmdir %s: not a plain path under the mirror root" % dp)
            os.rmdir(dp)
            out.log("removed directory %s" % dp)
        os.rmdir(M)
        out.log("removed %d mirror dirs and %s itself (its parent is untouched)" % (len(mdirs), M))

        _, after = walk(R, "real library")
        after, _ = drop_finder_noise(after, mfiles)
        if set(after) != set(rfiles):
            raise Failure("real library file set changed")
        for rel, st in sorted(after.items()):
            if st.st_nlink != 1:
                raise Failure("real file still has st_nlink=%d: %s" % (st.st_nlink, rel))
            if st.st_size != sizes[rel]:
                raise Failure("size changed: %s" % rel)
        if len(after) != a.files or sum(s.st_size for s in after.values()) != a.bytes:
            raise Failure("real library totals changed")
        for i, rel in enumerate(sorted(after), 1):
            if sha256_of(os.path.join(R, rel)) != before[rel]:
                raise Failure("sha256 differs from the pre-removal hash: %s" % rel)
            if i % 20 == 0:
                out.log("  re-verified %d/%d" % (i, len(after)))
        out.log("post-check ok: %d files / %d bytes, all nlink=1, sizes and sha256 unchanged" % (len(after), a.bytes))
        return 0
    except Refusal as exc:
        out.log("REFUSED: %s" % exc)
        return 2
    except (Failure, OSError) as exc:
        out.log("FAILED%s: %s" % (" (changes had started)" if changed else "", exc))
        return 3


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
