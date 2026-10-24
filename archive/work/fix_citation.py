p = "/Volumes/ExT2/GameHub/work/mtld3d-merge/windows/d3d9/src/surface.rs"
s = open(p).read()
old = """            // The chain stays alive while its back buffer is referenced, but its
            // public count is the application's alone (Wine's test_refcount reads
            // it as 1 after GetBackBuffer), so the retain is a private one."""
new = """            // The chain stays alive while its back buffer is referenced, but its
            // public count is the application's alone (D3D9 leaves it unchanged
            // by GetBackBuffer), so the retain is a private one."""
assert s.count(old) == 1
open(p, "w").write(s.replace(old, new))
print("ok")
