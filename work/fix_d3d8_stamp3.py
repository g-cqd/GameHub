p = "/Volumes/ExT2/GameHub/work/mtld3d-merge/windows/d3d8/src/lib.rs"
s = open(p).read()
old_static = """/// The build identity, kept in the image whether or not anything logs it.
///
/// This DLL installs no logger of its own, so under fat LTO its `log` calls are
/// proven dead and removed together with the identity they name; `make bundle`
/// refuses a shipped DLL that does not carry it.
#[used]
static BUILD_STAMP: &str = mtld3d_shared::identity::BUILD;

"""
assert s.count(old_static) == 1
s = s.replace(old_static, "")
old = """pub extern "system" fn Direct3DCreate8(sdk_version: u32) -> *mut c_void {
"""
new = """pub extern "system" fn Direct3DCreate8(sdk_version: u32) -> *mut c_void {
    // Keeps the build identity in the image. This DLL installs no logger of its
    // own, so under fat LTO its `log` calls are proven dead and removed with the
    // identity they name, and a `#[used]` static still falls to the linker's
    // unreferenced-section removal; `make bundle` refuses a DLL without it.
    core::hint::black_box(mtld3d_shared::identity::BUILD);
"""
assert s.count(old) == 1
s = s.replace(old, new)
open(p, "w").write(s)
print("ok")
