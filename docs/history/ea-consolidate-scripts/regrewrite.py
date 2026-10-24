#!/usr/bin/env python3
"""regrewrite.py: literal byte rewrite of the EA library paths in the Wine hives and the EA ini.

usage: regrewrite.py --rule BF4|BF3 [--apply] [--root PREFIX] [--expect NAME=N ...]
                     [--stage Sx] [--log FILE]

Rules (literal bytes, exactly as stored; BS2 means two backslash characters):
  BF4  .reg : E:BS2EA GamesBS2BF4BS2                   -> E:BS2EA GamesBS2
       ini  : user.downloadinplacedir=E:\\EA Games\\BF4\\ -> user.downloadinplacedir=E:\\EA Games\\
  BF3  .reg : C:BS2Program FilesBS2EA GamesBS2Battlefield 3BS2 -> E:BS2EA GamesBS2Battlefield 3BS2
Targets: PREFIX/system.reg, user.reg, userdef.reg and, for BF4, every
PREFIX/drive_c/users/crossover/AppData/Local/Electronic Arts/EA Desktop/user_*.ini that
contains the old value.

Default is a dry run (count, diff summary, no write). --apply writes. --expect NAME=N
(repeatable; NAME is a file's basename, or "ini" for each ini file) makes any other
occurrence count a refusal. PREFIX defaults to /Volumes/ExT2/GameHub/Prefix.

Exit codes: 0 ok; 2 refused (wine running for PREFIX, expectation mismatch, header
collision, missing file, concurrent change); 3 verification failed after a write (every
file already written is restored from memory); 64 usage error.
"""
import argparse
import collections
import datetime
import glob
import os
import stat
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
G = "/Volumes/ExT2/GameHub"
DEFAULT_ROOT = G + "/Prefix"
DEFAULT_LOG = G + "/docs/ea-library-consolidation-20261011.log"
INI_DIR = "drive_c/users/crossover/AppData/Local/Electronic Arts/EA Desktop"
BS = b"\\"
BS2 = BS * 2

RULES = {
    "BF4": {
        "reg": (b"E:" + BS2 + b"EA Games" + BS2 + b"BF4" + BS2,
                b"E:" + BS2 + b"EA Games" + BS2),
        "ini": (b"user.downloadinplacedir=E:" + BS + b"EA Games" + BS + b"BF4" + BS,
                b"user.downloadinplacedir=E:" + BS + b"EA Games" + BS),
        "reg_files": ["system.reg", "user.reg", "userdef.reg"],
    },
    "BF3": {
        "reg": (b"C:" + BS2 + b"Program Files" + BS2 + b"EA Games" + BS2 + b"Battlefield 3" + BS2,
                b"E:" + BS2 + b"EA Games" + BS2 + b"Battlefield 3" + BS2),
        "ini": None,
        "reg_files": ["system.reg", "user.reg", "userdef.reg"],
    },
}


class Refusal(Exception):
    pass


class VerifyFailure(Exception):
    pass


class Out:
    def __init__(self, apply_mode, stage, logfile):
        self.apply_mode, self.stage, self.logfile = apply_mode, stage, logfile

    def log(self, text):
        line = "[%s] [%s] %s" % (datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                                 self.stage, text)
        print(line if self.apply_mode else "[DRY-RUN] " + line, flush=True)
        if self.apply_mode:
            with open(self.logfile, "a", encoding="utf-8") as fh:
                fh.write(line + "\n")


class Target:
    def __init__(self, path, kind, old, new):
        self.path, self.kind, self.old, self.new = path, kind, old, new
        self.name = os.path.basename(path)
        self.orig = None
        self.st = None
        self.count = 0
        self.lines = None
        self.new_lines = None

    def load(self):
        self.st = os.stat(self.path)
        if not stat.S_ISREG(self.st.st_mode):
            raise Refusal("%s is not a regular file" % self.path)
        with open(self.path, "rb") as fh:
            self.orig = fh.read()
        if len(self.orig) != self.st.st_size:
            raise Refusal("%s changed while reading" % self.path)
        self.count = self.orig.count(self.old)
        self.lines = self.orig.split(b"\n")
        self.new_lines = [ln.replace(self.old, self.new) for ln in self.lines]

    @property
    def new_data(self):
        return b"\n".join(self.new_lines)

    def changed_idx(self):
        return [i for i, ln in enumerate(self.lines) if self.old in ln]


def prefix_running(root):
    """True (or an explanation) when any process uses WINEPREFIX=root; identical to common.sh."""
    r = subprocess.run(["/bin/bash", os.path.join(HERE, "prefix-running.sh"), root],
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    text = r.stdout.decode("utf-8", "replace").strip()
    if r.returncode == 1:
        return None
    return text or "prefix-running.sh exited %d" % r.returncode


def header_name(line):
    return line[1:line.rfind(b"]")] if line.startswith(b"[") and b"]" in line else None


def check_collisions(t):
    if t.kind != "reg":
        return
    orig = collections.Counter()
    final = collections.Counter()
    for a, b in zip(t.lines, t.new_lines):
        n0 = header_name(a)
        if n0 is not None:
            orig[n0.lower()] += 1
            final[header_name(b).lower()] += 1
    bad = [n for n, c in final.items() if c > 1 and c > orig[n]]
    if bad:
        raise Refusal("%s: rewritten key header would collide with an existing header: %s" % (
            t.path, "; ".join(n.decode("utf-8", "replace")[:150] for n in bad[:3])))


def atomic_write(path, data, st):
    d = os.path.dirname(path)
    fd, tmp = tempfile.mkstemp(dir=d, prefix="." + os.path.basename(path) + ".regrewrite-")
    try:
        with os.fdopen(fd, "wb") as fh:
            os.fchmod(fh.fileno(), stat.S_IMODE(st.st_mode))
            if os.fstat(fh.fileno()).st_uid != st.st_uid or os.fstat(fh.fileno()).st_gid != st.st_gid:
                os.fchown(fh.fileno(), st.st_uid, st.st_gid)
            fh.write(data)
            fh.flush()
            os.fsync(fh.fileno())
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise
    dfd = os.open(d, os.O_RDONLY)
    try:
        os.fsync(dfd)
    finally:
        os.close(dfd)


def verify_after(t):
    with open(t.path, "rb") as fh:
        got = fh.read()
    if got.count(t.old) != 0:
        raise VerifyFailure("%s: old literal still present (%d)" % (t.path, got.count(t.old)))
    want_new = t.orig.count(t.new) + t.count * (t.new.count(t.new) - t.old.count(t.new))
    if got.count(t.new) != want_new:
        raise VerifyFailure("%s: new literal count %d, expected %d" % (t.path, got.count(t.new), want_new))
    gl = got.split(b"\n")
    if len(gl) != len(t.lines):
        raise VerifyFailure("%s: line count %d != %d" % (t.path, len(gl), len(t.lines)))
    for i, (a, b, c) in enumerate(zip(t.lines, gl, t.new_lines)):
        if (b != c) or (t.old not in a and b != a):
            raise VerifyFailure("%s: line %d differs unexpectedly" % (t.path, i + 1))
    if got != t.new_data:
        raise VerifyFailure("%s: content differs from the intended result" % t.path)
    st = os.stat(t.path)
    if (stat.S_IMODE(st.st_mode), st.st_uid, st.st_gid) != (stat.S_IMODE(t.st.st_mode), t.st.st_uid, t.st.st_gid):
        raise VerifyFailure("%s: mode/owner not preserved" % t.path)


def show(t, out):
    idx = t.changed_idx()
    out.log("%s: %d occurrence(s) on %d line(s)" % (t.path, t.count, len(idx)))
    for i in idx[:5]:
        out.log("  @@ line %d @@" % (i + 1))
        out.log("  - " + t.lines[i].rstrip(b"\r").decode("utf-8", "replace")[:240])
        out.log("  + " + t.new_lines[i].rstrip(b"\r").decode("utf-8", "replace")[:240])


def main(argv):
    ap = argparse.ArgumentParser(description="literal byte rewrite of EA library paths", add_help=True)
    ap.add_argument("--rule", required=True, choices=sorted(RULES))
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--root", default=DEFAULT_ROOT, help="prefix directory (default %(default)s)")
    ap.add_argument("--expect", action="append", default=[], metavar="NAME=N")
    ap.add_argument("--stage", default="RR")
    ap.add_argument("--log", default=DEFAULT_LOG)
    try:
        a = ap.parse_args(argv)
    except SystemExit as e:
        return 64 if e.code else 0
    if os.environ.get("EA_TEST_MODE") == "1" and a.log == DEFAULT_LOG:
        if not os.environ.get("EA_LOG"):      # test mode: the shell scripts export their scratch log
            print("EA_TEST_MODE=1 needs EA_LOG (or --log) so a test never writes the real log", file=sys.stderr)
            return 64
        a.log = os.environ["EA_LOG"]
    out = Out(a.apply, a.stage, a.log)
    expect = {}
    for e in a.expect:
        name, sep, n = e.rpartition("=")
        if not sep or not n.isdigit() or not name:
            print("bad --expect %r (want NAME=N)" % e, file=sys.stderr)
            return 64
        expect[name] = int(n)
    written = []
    try:
        root = a.root.rstrip("/") or "/"
        why = prefix_running(root)
        if why:
            raise Refusal("wine process(es) use the prefix %s: %s" % (root, why.replace("\n", " | ")[:300]))
        rule = RULES[a.rule]
        targets = []
        for n in rule["reg_files"]:
            p = os.path.join(root, n)
            if not os.path.isfile(p):
                raise Refusal("missing hive %s" % p)
            targets.append(Target(p, "reg", *rule["reg"]))
        if rule["ini"]:
            for p in sorted(glob.glob(os.path.join(glob.escape(root), glob.escape(INI_DIR), "user_*.ini"))):
                with open(p, "rb") as fh:
                    if rule["ini"][0] in fh.read():
                        targets.append(Target(p, "ini", *rule["ini"]))
        known = {t.name for t in targets} | {"ini"}
        for name in expect:
            if name not in known:
                raise Refusal("--expect %s names no target (targets: %s)" % (
                    name, ", ".join(sorted(known))))
        if rule["ini"] and "ini" in expect and not any(t.kind == "ini" for t in targets) and expect["ini"] != 0:
            raise Refusal("expected ini=%d but no EA ini file contains the old value" % expect["ini"])
        out.log("rule %s on %s (%s)" % (a.rule, root, "APPLY" if a.apply else "dry-run"))
        for t in targets:
            t.load()
            want = expect.get(t.name, expect.get("ini") if t.kind == "ini" else None)
            out.log("count %s = %d%s" % (t.name, t.count, "" if want is None else " (expected %d)" % want))
            if want is not None and want != t.count:
                raise Refusal("%s: %d occurrence(s), expected %d" % (t.path, t.count, want))
            check_collisions(t)
        for t in targets:
            if t.count:
                show(t, out)
        if not a.apply:
            out.log("dry-run: nothing written (%d occurrence(s) in %d file(s) would be rewritten)" % (
                sum(t.count for t in targets), sum(1 for t in targets if t.count)))
            return 0
        why = prefix_running(root)
        if why:
            raise Refusal("wine process(es) appeared for the prefix %s: %s" % (root, why[:300]))
        for t in targets:
            if not t.count:
                out.log("%s: nothing to rewrite, left untouched" % t.path)
                continue
            st = os.stat(t.path)
            if (st.st_ino, st.st_size, st.st_mtime_ns) != (t.st.st_ino, t.st.st_size, t.st.st_mtime_ns):
                raise Refusal("%s changed since it was read" % t.path)
            atomic_write(t.path, t.new_data, t.st)
            written.append(t)
            verify_after(t)
            out.log("%s: rewrote %d occurrence(s) on %d line(s), verified (old=0, line-by-line)" % (
                t.path, t.count, len(t.changed_idx())))
        out.log("done: %d occurrence(s) rewritten in %d file(s)" % (
            sum(t.count for t in written), len(written)))
        return 0
    except Refusal as exc:
        out.log("REFUSED: %s" % exc)
        return 2
    except (VerifyFailure, OSError) as exc:
        out.log("FAILED: %s" % exc)
        for t in written:
            try:
                atomic_write(t.path, t.orig, t.st)
                out.log("restored original %s" % t.path)
            except OSError as e2:
                out.log("RESTORE FAILED for %s: %s (backup needed)" % (t.path, e2))
        return 3


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
