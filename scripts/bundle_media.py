#!/usr/bin/env python3
"""Bundle GStreamer (curated plugins) and the FFmpeg libs into a Wine runtime.

usage: bundle_media.py RUNTIME_ROOT

Copies the x86_64 Homebrew (/usr/local) dylibs that winegstreamer.so, winedmo.so and a curated
set of GStreamer plugins need into RUNTIME_ROOT/lib/external/media, rewrites every install name to
a relative one, ad-hoc signs, and relinks the Wine unix modules. The runtime then needs no
Homebrew at run time; set GST_PLUGIN_SYSTEM_PATH_1_0 / GST_PLUGIN_PATH to lib/external/media/plugins.
"""
import os, re, shutil, subprocess, sys

PLUGINS = """coreelements typefindfunctions playback app audioconvert audioresample audioparsers audiorate
volume videoconvertscale videorate videofilter videoparsersbad asf avi isomp4 matroska mpegtsdemux
mpegpsdemux flv ogg vorbis opus theora vpx dav1d libav wavparse id3demux mpg123 applemedia
subparse lame xingmux deinterlace interlace audiofx equalizer""".split()
WINE_MODULES = ["winegstreamer.so", "winedmo.so"]
BREW = "/usr/local"

def otool(path):
    out = subprocess.run(["otool", "-L", path], capture_output=True, text=True).stdout.splitlines()[1:]
    return [l.strip().split(" (")[0] for l in out]

def is_x86(path):
    return b"x86_64" in subprocess.run(["lipo", "-archs", path], capture_output=True).stdout

def main(root):
    ext = os.path.join(root, "lib/external/media")
    plug = os.path.join(ext, "plugins")
    os.makedirs(plug, exist_ok=True)
    libs = {}          # basename -> source realpath
    todo = []
    for p in PLUGINS:
        src = os.path.realpath(f"{BREW}/lib/gstreamer-1.0/libgst{p}.dylib")
        if not os.path.exists(src):
            print("missing plugin", p); continue
        shutil.copy2(src, os.path.join(plug, f"libgst{p}.dylib")); os.chmod(os.path.join(plug, f"libgst{p}.dylib"), 0o755)
        todo.append(os.path.join(plug, f"libgst{p}.dylib"))
    for m in WINE_MODULES:
        todo.append(os.path.join(root, "lib/wine/x86_64-unix", m))
    seen = set(); i = 0
    # gst-plugin-scanner helper
    scanner = None
    for cand in [f"{BREW}/libexec/gstreamer-1.0/gst-plugin-scanner"]:
        if os.path.exists(cand): scanner = os.path.realpath(cand)
    if scanner:
        d = os.path.join(ext, "gst-plugin-scanner"); shutil.copy2(scanner, d); os.chmod(d, 0o755); todo.append(d)
    while i < len(todo):
        f = todo[i]; i += 1
        if f in seen: continue
        seen.add(f)
        for dep in otool(f):
            if dep.startswith("/usr/lib") or dep.startswith("/System") or dep.startswith("@"):
                continue
            if not (dep.startswith(BREW) or dep.startswith("/opt/homebrew")):
                continue
            real = os.path.realpath(dep)
            if not is_x86(real):
                print("skip non-x86", dep); continue
            base = os.path.basename(dep)
            dst = os.path.join(ext, base)
            if base not in libs:
                libs[base] = real
                shutil.copy2(real, dst); os.chmod(dst, 0o755)
                todo.append(dst)
    # rewrite install names
    def rel_for(f):
        d = os.path.dirname(f)
        return os.path.relpath(ext, d) or "."
    for f in list(seen):
        r = rel_for(f)
        subprocess.run(["install_name_tool", "-id", f"@loader_path/{os.path.basename(f)}"] if f.startswith(ext) and os.path.dirname(f) == ext and f.endswith(".dylib") else ["true"], capture_output=True)
        for dep in otool(f):
            if dep.startswith(BREW) or dep.startswith("/opt/homebrew"):
                base = os.path.basename(dep)
                new = f"@loader_path/{r}/{base}" if r != "." else f"@loader_path/{base}"
                subprocess.run(["install_name_tool", "-change", dep, new, f], check=True, capture_output=True)
        subprocess.run(["codesign", "-s", "-", "-f", f], capture_output=True)
    print(f"bundled {len(libs)} libs, {len(PLUGINS)} plugins into {ext}")
    tot = subprocess.run(["du", "-sh", ext], capture_output=True, text=True).stdout.split()[0]
    print("size", tot)

if __name__ == "__main__":
    main(sys.argv[1])
