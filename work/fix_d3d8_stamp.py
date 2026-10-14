p = "/Volumes/ExT2/GameHub/work/mtld3d-merge/windows/d3d8/src/lib.rs"
s = open(p).read()
old = """    log::debug!(target: "mtld3d::d3d8", "d3d8.dll {} created", mtld3d_shared::identity::BUILD);"""
new = """    log::info!(target: "mtld3d::d3d8", "d3d8.dll {} created", mtld3d_shared::identity::BUILD);"""
assert s.count(old) == 1
open(p, "w").write(s.replace(old, new))
print("ok")
