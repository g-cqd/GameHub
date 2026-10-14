root = "/Volumes/ExT2/GameHub/work/mtld3d-merge/"


def rep(path, old, new):
    p = root + path
    s = open(p).read()
    assert s.count(old) == 1, (path, old[:80])
    open(p, "w").write(s.replace(old, new))


rep("windows/tests/tests/e2e/render_target.rs",
"""    // An additional swap chain's back buffer aliases the device's texture here
    // but is another surface to the application, so a stretch from it into the
    // device's back buffer is accepted and lands as one between two surfaces.
    let extra = h.additional_swapchain();
    let extra_bb = extra.back_buffer();
    assert_eq!(
""",
"""    // An additional swap chain's back buffer is a surface of its own, over
    // storage of its own in this layer, so a stretch from it into the device's
    // back buffer is accepted and lands as one between two surfaces. Its block
    // is painted red first, since that storage holds nothing yet.
    let extra = h.additional_swapchain();
    let extra_bb = extra.back_buffer();
    assert_eq!(
        h.color_fill_rect_hr(&extra_bb, (0, 0, 64, 64), RED),
        D3D_OK,
        "paint the additional back buffer's source block",
    );
    assert_eq!(
""")

rep("windows/d3d9/src/device.rs",
"""    // two surfaces and may stretch. So may an additional swap chain's back
    // buffer and the device's, which alias one texture here but are two
    // surfaces to the application. The back-buffer indices of one swap chain""",
"""    // two surfaces and may stretch. So may an additional swap chain's back
    // buffer and the device's, which are two surfaces over two textures
    // here. The back-buffer indices of one swap chain""")
print("ok")
