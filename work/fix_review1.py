root = "/Volumes/ExT2/GameHub/work/mtld3d-merge/"


def rep(path, old, new):
    p = root + path
    s = open(p).read()
    assert s.count(old) == 1, (path, s.count(old), old[:80])
    open(p, "w").write(s.replace(old, new))


# D2: our fork implements MULTIPLYADD/LERP through COLORARG0/ALPHAARG0; only PREMODULATE stays unsupported.
rep("docs/STATUS.md",
"""- The fixed-function texture operations `D3DTOP_PREMODULATE`,
  `D3DTOP_MULTIPLYADD` and `D3DTOP_LERP`: absent from `TextureOpCaps`, and a
  stage that names one is warned once and runs as `D3DTOP_SELECTARG1`.
  `D3DTSS_COLORARG0` and `D3DTSS_ALPHAARG0`, which only the last two read,
  are stored and reported back, and warned once when written away from
  their default.
""",
"""- The fixed-function texture operation `D3DTOP_PREMODULATE`: absent from
  `TextureOpCaps`, and a stage that names it is warned once and runs as
  `D3DTOP_SELECTARG1`.
""")

# D1: the swap chain is retained by its back buffer's references, not by upstream's pin.
rep("windows/d3d9/src/swapchain.rs",
"""/// Its back buffer goes with it, so this runs only once the back buffer is
/// referenced by nothing either: the last public `Release` of an unpinned
/// swap chain, or [`unpin_for_backbuffer`] after it. The device-owned
/// implicit swapchain is never finalized (its shell is leaked at device
/// teardown).""",
"""/// Its back buffer goes with it, so this runs only once the back buffer is
/// referenced by nothing either: the back buffer's public references retain
/// this chain publicly and its binding references retain it privately, so
/// whichever of the two counts reaches zero last finalizes it. The
/// device-owned implicit swapchain is never finalized (its shell is leaked at
/// device teardown).""")
rep("windows/d3d9/src/swapchain.rs",
"""    // mirroring how `device_release` finalizes the implicit RT/DS surfaces). It
    // pins this swap chain while referenced, so nothing references it now.""",
"""    // mirroring how `device_release` finalizes the implicit RT/DS surfaces). Its
    // references retain this swap chain, so nothing references it now.""")

# D4: upstream checks the out-pointer before `null_out`; the later re-check is dead.
rep("windows/d3d9/src/device.rs",
"""    null_out(swap_chain);
    if swap_chain.is_null() {
        return D3DERR_INVALIDCALL;
    }
    // SAFETY: vtable in/out-param; `present_params` is *mut D3DPRESENT_PARAMETERS""",
"""    null_out(swap_chain);
    // SAFETY: vtable in/out-param; `present_params` is *mut D3DPRESENT_PARAMETERS""")

# D4: both sides listed test-unit-perf in .PHONY.
rep("Makefile",
"""	test test-unit test-unit-perf test-e2e-i686""",
"""	test test-unit test-e2e-i686""")

# D4: no two surfaces alias the additional chain's texture in this fork.
rep("windows/core/src/stretch_rect.rs",
"""/// texture, between two surfaces that alias one texture (an additional swap
/// chain's back buffer and the device's), and between two equal rects of one""",
"""/// texture, between two surfaces that alias one texture, and between two
/// equal rects of one""")
print("ok")
