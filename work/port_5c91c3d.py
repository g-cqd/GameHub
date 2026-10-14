"""Port 5c91c3d's rect write-back geometry (core helpers + host tests) onto the merged surface.rs.

The core half (windows/core/src/surface_lock.rs and its tests) is applied with
`git diff bfabd76 5c91c3d -- windows/core | git apply --index` before this runs.
This script makes surface.rs call the two helpers instead of its inline copies.
"""
p = "/Volumes/ExT2/GameHub/work/mtld3d-merge/windows/d3d9/src/surface.rs"
s = open(p).read()


def rep(old, new):
    global s
    assert s.count(old) == 1, old[:80]
    s = s.replace(old, new)


rep("""    surface_lock::{ColorSurfaceLock, classify_color_surface_lock},""",
    """    surface_lock::{
        ColorSurfaceLock, classify_color_surface_lock, region_offset, writeback_regions,
    },""")
rep("""    let offset = if read_only {
        Some(0)
    } else {
        (region.y as usize)
            .checked_mul(pitch as usize)
            .and_then(|row| {
                (region.x as usize)
                    .checked_mul(bpp as usize)
                    .and_then(|column| row.checked_add(column))
            })
    };""",
    """    let offset = if read_only {
        Some(0)
    } else {
        region_offset(region, pitch, bpp, page.len())
    };""")
rep("""        source_region: snapshot.region,
        destination_region: {
            let region = snapshot.region;
            let (x, y, w, h) = scale.rect(region.x, region.y, region.w, region.h);
            StretchRegion { x, y, w, h }
        },
        bytes_per_row: src_stride,""",
    """        source_region,
        destination_region,
        bytes_per_row: src_stride,""")
# the regions are computed where the snapshot is in hand, before the upload struct
rep("""    let target = ResampledUpload {
        color_handle,
        format,
        logical: (width, height),""",
    """    let (source_region, destination_region) = writeback_regions(scale, snapshot.region);
    let target = ResampledUpload {
        color_handle,
        format,
        logical: (width, height),""")
open(p, "w").write(s)
print("ok")
