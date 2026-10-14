#!/usr/bin/env python3
"""Read-only probe of a Wine server directory: is its wineserver alive?

usage: wineserver_probe.py SOCKDIR      (SOCKDIR = /tmp/.wine-<uid>/server-<hex st_dev>-<hex st_ino>)
exit 0: idle (SOCKDIR absent, or its `lock` is free and no process has its cwd inside SOCKDIR)
exit 1: held   (reason on stdout)
exit 2: unprobeable (reason on stdout); callers must treat this like "held" (fail closed)

The lock is tested with fcntl(F_GETLK) on `SOCKDIR/lock` (wineserver keeps a write lock on it for its
whole life), which does not depend on lsof. struct flock on macOS (sys/fcntl.h) is
  off_t l_start; off_t l_len; pid_t l_pid; short l_type; short l_whence;   -> struct format "qqihh", 24 bytes.
A wineserver also chdir()s into SOCKDIR, so a process with its cwd there counts as well (lsof -d cwd).
"""
import errno
import fcntl
import os
import stat
import struct
import subprocess
import sys

FLOCK = "qqihh"
assert struct.calcsize(FLOCK) == 24


def main(argv):
    if len(argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    sockdir = argv[1].rstrip("/")
    try:
        st = os.stat(sockdir)
    except FileNotFoundError:
        return 0                                       # no server directory: no server was ever started
    except OSError as exc:
        print("cannot stat %s: %s" % (sockdir, exc))   # exists (or may) but unreadable: unknown
        return 2
    if not stat.S_ISDIR(st.st_mode):
        print("%s exists but is not a directory" % sockdir)
        return 2
    lock = os.path.join(sockdir, "lock")
    try:
        fd = os.open(lock, os.O_RDONLY)
    except FileNotFoundError:
        fd = None
    except OSError as exc:
        print("cannot open %s: %s" % (lock, exc))
        return 2
    if fd is not None:
        try:
            req = struct.pack(FLOCK, 0, 0, 0, fcntl.F_WRLCK, os.SEEK_SET)
            res = fcntl.fcntl(fd, fcntl.F_GETLK, req)
            _, _, pid, ltype, _ = struct.unpack(FLOCK, res)
        except OSError as exc:
            print("F_GETLK on %s failed: %s" % (lock, exc))
            return 2
        finally:
            os.close(fd)
        if ltype != fcntl.F_UNLCK:
            print("wineserver lock %s is held (kernel-reported pid %d, l_type %d)" % (lock, pid, ltype))
            return 1
    try:
        r = subprocess.run(["/usr/sbin/lsof", "-d", "cwd", "-Fpn"], stdout=subprocess.PIPE,
                           stderr=subprocess.DEVNULL, timeout=60)
    except (OSError, subprocess.SubprocessError) as exc:
        print("lsof -d cwd failed: %s" % exc)
        return 2
    out = r.stdout.decode("utf-8", "replace")
    if r.returncode not in (0, 1) or "\np" not in "\n" + out:
        print("lsof -d cwd gave no usable output (rc=%d)" % r.returncode)
        return 2
    names = {sockdir, os.path.realpath(sockdir)}      # /tmp is a symlink to /private/tmp; lsof prints the real path
    pid = "?"
    for line in out.splitlines():
        if line.startswith("p"):
            pid = line[1:]
        elif line.startswith("n") and any(line[1:] == n or line[1:].startswith(n + "/") for n in names):
            print("process %s has its cwd in %s" % (pid, sockdir))
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
