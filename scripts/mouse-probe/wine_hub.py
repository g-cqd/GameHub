import importlib.machinery, types, subprocess, sys
l = importlib.machinery.SourceFileLoader("hub", "/Users/gc/Developer/GameHub/launcher/hub"); m = types.ModuleType("hub")
m.__file__ = "/Users/gc/Developer/GameHub/launcher/hub"; l.exec_module(m)
o = types.SimpleNamespace(debug=None, dxgi=None, metalfx=None)
env = m.session_env("hub-1", "steam", o)
bg = sys.argv[1] == "bg"
cmd = [str(m.RUNTIMES/"hub-1/bin/wine")] + sys.argv[2:]
if bg:
    subprocess.Popen(cmd, env=env, cwd=str(m.TEMP), stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
else:
    r = subprocess.run(cmd, env=env, cwd=str(m.TEMP), capture_output=True, text=True, timeout=90)
    print("\n".join(x for x in (r.stdout + r.stderr).splitlines() if not x.startswith(("compatdb", "info:", "warn:"))))
