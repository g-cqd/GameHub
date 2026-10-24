p = "/Volumes/ExT2/GameHub/work/mtld3d-merge/windows/d3d8/src/lib.rs"
s = open(p).read()
# back to the original level: the stamp no longer depends on the log line
old = """    log::info!(target: "mtld3d::d3d8", "d3d8.dll {} created", mtld3d_shared::identity::BUILD);"""
new = """    log::debug!(target: "mtld3d::d3d8", "d3d8.dll {} created", mtld3d_shared::identity::BUILD);"""
assert s.count(old) == 1
s = s.replace(old, new)
anchor = """/// Creates an `IDirect3D8` interface with one owned reference, or null for an unsupported SDK."""
assert s.count(anchor) == 1
stamp = """/// The build identity, kept in the image whether or not anything logs it.
///
/// This DLL installs no logger of its own, so under fat LTO its `log` calls are
/// proven dead and removed together with the identity they name; `make bundle`
/// refuses a shipped DLL that does not carry it.
#[used]
static BUILD_STAMP: &str = mtld3d_shared::identity::BUILD;

"""
s = s.replace(anchor, stamp + anchor)
open(p, "w").write(s)
print("ok")
