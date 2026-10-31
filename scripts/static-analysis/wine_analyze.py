#!/usr/bin/env python3
"""Clang static analyzer over the Wine fork's sources that we changed (development/adr/0015).

For each C/ObjC file touched by our commits, ask make for the real compile command of its object (unix .o, then the
x86_64 and i386 PE .o), turn it into `clang --analyze`, and print every analyzer warning as `object :: warning`.
Nothing is built or run. Usage:

    scripts/static-analysis/wine_analyze.py [--all-authors] > wine-analyze.txt

Env: WINE_SRC (default ~/Developer/wine), WINE_BUILD (default $HUB_ROOT/build/wine-ours), JOBS (default all cores).
Triage the output with `git blame`: upstream lines are fixed only when the finding is real (ADR-0015).
"""
import concurrent.futures as cf, os, re, shlex, subprocess, sys

S = os.environ.get("WINE_SRC", os.path.expanduser("~/Developer/wine"))
B = os.environ.get("WINE_BUILD", os.path.join(os.environ.get("HUB_ROOT", "/Volumes/ExT2/GameHub"), "build/wine-ours"))
ENV = dict(os.environ, PATH="/opt/homebrew/bin:" + os.environ["PATH"])
CHECKERS = ("core,unix,deadcode,nullability,security.insecureAPI.UncheckedReturn,optin.portability.UnixAPI,"
            "alpha.unix.cstring.OutOfBounds,alpha.security.ArrayBoundV2,alpha.core.CastSize")


def our_files(all_authors):
    cmd = ["git", "-C", S, "log", "--name-only", "--format="]
    if not all_authors:
        cmd[4:4] = ["--author=g-cqd", "--author=Gigi"]
    names = set(subprocess.run(cmd, capture_output=True, text=True, check=True).stdout.split())
    return sorted(f for f in names if re.search(r"\.(c|m)$", f) and "/tests/" not in f
                  and not f.startswith(("macos-arm64/", "tests/")) and os.path.exists(os.path.join(S, f)))


def compile_command(src, obj):
    out = subprocess.run(["make", "-n", "-W", os.path.join(S, src), obj], cwd=B, env=ENV, capture_output=True,
                         text=True, check=False).stdout.replace("\\\n", " ")
    for line in out.splitlines():
        if os.path.join(S, src) in line and re.match(r"\s*\S*clang\b", line) and " -c " in line:
            return line
    return None


def objects(src):
    d, b = os.path.split(src.rsplit(".", 1)[0])
    cands = [f"{d}/{b}.o", f"{d}/x86_64-windows/{b}.o", f"{d}/i386-windows/{b}.o"]
    return [(o, c) for o in cands if (c := compile_command(src, o))][:2]


def analyze(job):
    obj, cmd = job
    a = shlex.split(cmd)
    i = a.index("-o")
    del a[i:i + 2]
    a = [x for x in a if x != "-c"]
    a[1:1] = ["--analyze", "-Xanalyzer", "-analyzer-output=text", "-Xanalyzer", f"-analyzer-checker={CHECKERS}",
              "-Wno-everything", "-o", "/dev/null"]
    r = subprocess.run(a, cwd=B, env=ENV, capture_output=True, text=True, check=False)
    return "".join(f"{obj} :: {line}\n" for line in r.stderr.splitlines() if ": warning: " in line)


def main():
    files = our_files("--all-authors" in sys.argv)
    with cf.ThreadPoolExecutor(int(os.environ.get("JOBS", os.cpu_count() or 4))) as ex:
        jobs = [j for js in ex.map(objects, files) for j in js]
        print(f"{len(files)} files, {len(jobs)} objects", file=sys.stderr)
        for r in ex.map(analyze, jobs):
            sys.stdout.write(r)


if __name__ == "__main__":
    main()
