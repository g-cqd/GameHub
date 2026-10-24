p = "/Volumes/ExT2/GameHub/work/mtld3d-merge/windows/tests/tests/e2e/render_states.rs"
s = open(p).read()
old = """    let left = z0 + gap - slope * 320.5;
    let right = left + slope * 640.0;"""
new = """    let left = slope.mul_add(-320.5, z0 + gap);
    let right = slope.mul_add(640.0, left);"""
assert s.count(old) == 1
open(p, "w").write(s.replace(old, new))
print("ok")
