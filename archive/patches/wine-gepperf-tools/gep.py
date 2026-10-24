#!/usr/bin/env python3
"""EAGEP start -> IPC connect harness on the THROWAWAY prefix (never the live one).

A listener of ours on 127.0.0.1:50999 (the throwaway backgroundservice.ini points there) stands in
for BGS: the 'connect' time is when it accepts EAGEP's TCP connection.  The EAGEP process we start
is killed as soon as it connected (or after a 20 s cap).  Marker times come from the throwaway
EAGEPVerbose.log and are relative to the moment we exec wine.

usage: gep.py ROUNDS VARIANTS... [--drop]   VARIANT = name=RT[,ENV=VAL...]
  --drop  : before each run, evict EAGEP's files from the unified buffer cache (purge-free: read a
            large unrelated file set; see evict()).
"""
import os, re, socket, statistics, subprocess, sys, threading, time, datetime, resource, signal

T = "/Volumes/ExT2/GameHub/work/wine-gepperf-tools"
PFX = T + "/prefix"
LOG = PFX + "/drive_c/ProgramData/EA Desktop/Logs/EAGEPVerbose.log"
R = "/Users/gc/Library/Application Support/BF3Mac"
EXE = r"C:\Program Files\Electronic Arts\EA Desktop\13.805.11.6320-1791598480\EA Desktop\EAGEP.exe"
COMPAT = "v=3\nname=ea-cef;exe=EACefSubProcess.exe;dxgi=wined3d\nname=ea-gep;exe=EAGEP.exe;dxgi=wined3d\nname=default;exe=*;d3d9=mtld3d;dxgi=dxmt"
MARK = [("A", "EAGEP.rcc.enc"), ("B", "cacertificates.rcc.enc"), ("C", "setNormalMode"),
        ("D", "[global-io-0]"), ("E", "[global-io-1]"), ("F", "[PlatformNetworkMonitor]"),
        ("G", "machash"), ("H", "Request Url=[https://statsigapi"), ("I", "ExperimentsStatus=loaded"),
        ("J", "Ipc Server listening"), ("K", "target: [localhost"), ("L", "connected to [localhost")]

accepted = []
def listener():
    s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(("127.0.0.1", 50999)); s.listen(16)
    held = []
    while True:
        c, _ = s.accept(); accepted.append(time.time()); held.append(c)

def env_for(rt, extra):
    e = {"PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "LANG": "en_US.UTF-8", "USER": "Player",
         "HOME": R + "/RuntimeHome/Player", "TMPDIR": R + "/Temporary", "WINEPREFIX": PFX,
         "WINEDEBUG": "-all", "WINEMSYNC": "1", "WINE_TF_EMULATION": "1", "WINE_TF_MAX_STEPS": "0",
         "WINE_TF_MAX_NS": "0", "WINEDLLOVERRIDES": "IGOProxy32.exe=d;winemenubuilder.exe=d",
         "ROSETTA_X87_PATH": "/Volumes/ExT2/GameHub/Runtimes/hub-0-helpers-fpr/x87sidecar",
         "WINE_COMPATDB": COMPAT}
    e.update(extra); return e

def parse_markers(t0):
    out = {}
    try:
        for line in open(LOG, errors="replace"):
            m = re.search(r"\[(\d{4}-\d\d-\d\dT[\d:.]+)Z\]", line)
            if not m: continue
            t = datetime.datetime.fromisoformat(m.group(1)).replace(tzinfo=datetime.timezone.utc).timestamp()
            if t < t0 - 0.01: continue
            for k, s in MARK:
                if s in line and k not in out: out[k] = t - t0
    except FileNotFoundError: pass
    return out

LIVE_EA = "/Volumes/ExT2/GameHub/Prefix/drive_c/Program Files/Electronic Arts/EA Desktop/13.805.11.6320-1791598480"
TMP_EA = PFX + "/drive_c/Program Files/Electronic Arts/EA Desktop/13.805.11.6320-1791598480"
BASE_RT = "/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv"
PE_DIRS = ["lib/wine/x86_64-windows", "lib/wine/i386-windows"]

def cold_files(rt):
    """Fresh APFS clones (new vnodes, nothing in the buffer cache) of the throwaway EA install and of
    the runtime clone's PE directories.  The runtime's unix .so files keep their inodes, so Rosetta's
    AOT cache stays warm: only the file cache goes cold."""
    assert rt != BASE_RT and PFX in TMP_EA
    subprocess.run(["rm", "-rf", TMP_EA], check=True)
    subprocess.run(["/bin/cp", "-c", "-R", LIVE_EA, TMP_EA], check=True)
    for d in PE_DIRS:
        subprocess.run(["rm", "-rf", os.path.join(rt, d)], check=True)
        subprocess.run(["/bin/cp", "-c", "-R", os.path.join(BASE_RT, d), os.path.join(rt, d)], check=True)

def warm_files(rt):
    """What a pre-warmer does: read every file of the EA install and the runtime PE dirs once."""
    n = 0
    for top in [TMP_EA] + [os.path.join(rt, d) for d in PE_DIRS]:
        for dp, _, fs in os.walk(top):
            for f in fs:
                try:
                    with open(os.path.join(dp, f), "rb") as fh:
                        while True:
                            b = fh.read(4 << 20)
                            if not b: break
                            n += len(b)
                except OSError: pass
    return n

def prewarm_files(rt):
    """Read exactly what EAGEP loads (eagep-dlls.txt, from a +loaddll trace): the native EA files,
    the builtin PE DLLs, every unix library and the loader binaries."""
    paths = []
    ea_dir = TMP_EA + "/EA Desktop"
    for line in open(os.path.join(os.path.dirname(__file__), "eagep-dlls.txt")):
        kind, name = line.split(None, 1); name = name.strip()
        if kind == "native": paths.append(os.path.join(ea_dir, name))
        else: paths.append(os.path.join(rt, "lib/wine/x86_64-windows", name.lower()))
    for d in ["bin", "lib/wine/x86_64-unix", "lib/external"]:
        for dp, _, fs in os.walk(os.path.join(rt, d)):
            paths += [os.path.join(dp, f) for f in fs]
    n = 0
    for path in paths:
        try:
            with open(path, "rb") as fh:
                while True:
                    b = fh.read(4 << 20)
                    if not b: break
                    n += len(b)
        except OSError: pass
    return n

def run_once(rt, extra, stderr_path=None):
    try:
        return _run_once(rt, extra, stderr_path)
    except Exception as e:          # e.g. a file of the runtime clone briefly missing
        print(f"   run failed: {e!r}", flush=True)
        global last_faults
        last_faults = (0, 0, 0, 0)
        return None, 0.0, {}

def _run_once(rt, extra, stderr_path=None):
    extra = dict(extra); pre = extra.pop("PRE", "")
    if pre == "prewarm":
        t = time.time(); n = prewarm_files(rt)
        print(f"   (prewarm read {n/1e6:.0f} MB in {(time.time()-t)*1000:.0f} ms)", flush=True)
    if pre.startswith("cold"):
        cold_files(rt)
    if pre == "coldwarm":
        t = time.time(); n = warm_files(rt)
        print(f"   (warmer read {n/1e6:.0f} MB in {(time.time()-t)*1000:.0f} ms)", flush=True)
    try: os.remove(LOG)
    except FileNotFoundError: pass
    via = extra.pop("VIA", "")
    n0 = len(accepted)
    ru0 = resource.getrusage(resource.RUSAGE_CHILDREN)
    t0 = time.time()
    if via == "launch32":
        # BGS-like: a 32-bit parent CreateProcess()es EAGEP; time from the call, as BGS's timer does
        p = subprocess.Popen([rt + "/bin/wine", r"C:\standin\launch32.exe"], env=env_for(rt, extra), cwd="/tmp",
                             stdout=subprocess.PIPE, text=True,
                             stderr=open(stderr_path, "w") if stderr_path else subprocess.DEVNULL)
        line = p.stdout.readline()
        m = re.search(r"createprocess_epoch=([0-9.]+)", line)
        if m: t0 = float(m.group(1))
    else:
        p = subprocess.Popen([rt + "/bin/wine", EXE], env=env_for(rt, extra), cwd="/tmp",
                             stdout=subprocess.DEVNULL,
                             stderr=open(stderr_path, "w") if stderr_path else subprocess.DEVNULL)
    conn = None
    while time.time() - t0 < 20:
        if len(accepted) > n0: conn = accepted[n0] - t0; break
        if p.poll() is not None and via != "launch32": break
        time.sleep(0.005)
    # let the log line for L land, then stop our own processes (throwaway prefix only)
    time.sleep(1.0)
    if via == "launch32":
        subprocess.run([rt + "/bin/wine", "taskkill", "/f", "/im", "EAGEP.exe"], env=env_for(rt, {}),
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if p.poll() is None:
        p.send_signal(signal.SIGKILL)
    p.wait()
    ru1 = resource.getrusage(resource.RUSAGE_CHILDREN)
    cpu = (ru1.ru_utime - ru0.ru_utime) + (ru1.ru_stime - ru0.ru_stime)
    global last_faults
    last_faults = (ru1.ru_majflt - ru0.ru_majflt, ru1.ru_minflt - ru0.ru_minflt, ru1.ru_nivcsw - ru0.ru_nivcsw,
                   ru1.ru_inblock - ru0.ru_inblock)
    return conn, cpu, parse_markers(t0)

def p90(x): s = sorted(x); return s[min(len(s) - 1, int(round(0.9 * (len(s) - 1))))]

def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    rounds = int(args[0]); variants = []
    for spec in args[1:]:
        name, rest = spec.split("=", 1); parts = rest.split(",")
        variants.append((name, parts[0], dict(p.split("=", 1) for p in parts[1:])))
    threading.Thread(target=listener, daemon=True).start()
    # persistent wineserver of the first variant, same environment (WINEMSYNC) as the clients
    subprocess.run([variants[0][1] + "/bin/wineserver", "-p"], env=env_for(variants[0][1], {}))
    # the throwaway stand-in service (C:\standin\EABackgroundService.exe) plays BGS's liveness
    subprocess.run([variants[0][1] + "/bin/wine", "sc", "start", "EABackgroundService"],
                   env=env_for(variants[0][1], {}), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    # a hidden window keeps the session's desktop process alive, as EA's windows do in the live
    # prefix (otherwise EAGEP's first GDI call has to start explorer.exe /desktop)
    out = subprocess.run(["ps", "-axo", "command"], capture_output=True, text=True).stdout
    if "keepdesk.exe" not in out:
        subprocess.Popen([variants[0][1] + "/bin/wine", r"C:\standin\keepdesk.exe"],
                         env=env_for(variants[0][1], {}), stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True)
        time.sleep(3)
    if "--warm" in sys.argv:   # one unrecorded run per variant
        for name, rt, extra in variants: run_once(rt, extra)
    res = {v[0]: [] for v in variants}
    gap = next((float(a.split("=", 1)[1]) for a in sys.argv if a.startswith("--gap=")), 0)
    first = True
    for i in range(rounds):
        order = variants if i % 2 == 0 else variants[::-1]
        for name, rt, extra in order:
            if "--drop" in sys.argv: evict()
            if gap and not (first and "--warm" not in sys.argv):
                time.sleep(gap)       # idle period before every recorded run: cold-ish conditions
            first = False
            conn, cpu, mk = run_once(rt, extra)
            res[name].append((conn, cpu, mk))
            segs = " ".join(f"{k}={mk[k]*1000:.0f}" for k, _ in MARK if k in mk)
            print(f"round {i} {name}: connect={conn*1000 if conn else -1:.0f} ms cpu={cpu*1000:.0f} ms "
                  f"majflt={last_faults[0]} minflt={last_faults[1]} nivcsw={last_faults[2]} inblk={last_faults[3]} "
                  f"load={os.getloadavg()[0]:.1f} | {segs}", flush=True)
    print("\nload avg at end:", os.getloadavg())
    for name, _, _ in variants:
        c = [r[0] * 1000 for r in res[name] if r[0]]; cpu = [r[1] * 1000 for r in res[name]]
        if not c: print(name, "no connects"); continue
        q = statistics.quantiles(c, n=4) if len(c) > 1 else [c[0]] * 3
        print(f"{name}: n={len(c)}/{len(res[name])} connect median={statistics.median(c):.0f} ms "
              f"IQR={q[2]-q[0]:.0f} p90={p90(c):.0f} min={min(c):.0f} max={max(c):.0f} | "
              f"cpu median={statistics.median(cpu):.0f} ms")
        for k, _ in MARK:
            v = [r[2][k] * 1000 for r in res[name] if k in r[2]]
            if v: print(f"   {k} median {statistics.median(v):6.0f} ms (n={len(v)})")

EVICT_DIR = "/Volumes/ExT2/GameHub/work/wine-gepperf-tools/evict"
def evict():
    """Push EAGEP's files out of the UBC without root: stream a set of large files (8 GiB of
    unrelated data on the same volume) through the cache with F_NOCACHE off."""
    for f in sorted(os.listdir(EVICT_DIR)):
        with open(os.path.join(EVICT_DIR, f), "rb") as fh:
            while fh.read(16 << 20): pass

if __name__ == "__main__":
    main()
