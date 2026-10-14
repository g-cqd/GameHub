root = "/Volumes/ExT2/GameHub/work/mtld3d-merge/"


def rep(path, old, new, count=1):
    p = root + path
    s = open(p).read()
    assert s.count(old) == count, (path, s.count(old), old[:80])
    open(p, "w").write(s.replace(old, new))


# Upstream's new FF tests predate our COLORARG0/ALPHAARG0 fields: give them D3D9's defaults.
rep("windows/core/src/dxso/ff/tests.rs",
"""        color_op: narrow(D3DTOP_BLENDTEXTUREALPHA),
        color_arg1: narrow(D3DTA_DIFFUSE),
        color_arg2: narrow(D3DTA_TFACTOR),
        alpha_op: narrow(D3DTOP_BLENDTEXTUREALPHA),
        alpha_arg1: narrow(D3DTA_DIFFUSE),""",
"""        color_op: narrow(D3DTOP_BLENDTEXTUREALPHA),
        color_arg0: narrow(D3DTA_CURRENT),
        color_arg1: narrow(D3DTA_DIFFUSE),
        color_arg2: narrow(D3DTA_TFACTOR),
        alpha_op: narrow(D3DTOP_BLENDTEXTUREALPHA),
        alpha_arg0: narrow(D3DTA_CURRENT),
        alpha_arg1: narrow(D3DTA_DIFFUSE),""")
rep("windows/core/src/dxso/ff/tests.rs",
"""        color_op: narrow(D3DTOP_SELECTARG1),
        color_arg1: narrow(D3DTA_TEXTURE),
        color_arg2: narrow(D3DTA_CURRENT),
        alpha_op: narrow(D3DTOP_SELECTARG1),
        alpha_arg1: narrow(D3DTA_TEXTURE),
        alpha_arg2: narrow(D3DTA_CURRENT),
        flags: FfStageFlags::HAS_TEXTURE,
    };
    ps.tt_projected_mask = 0b1;""",
"""        color_op: narrow(D3DTOP_SELECTARG1),
        color_arg0: narrow(D3DTA_CURRENT),
        color_arg1: narrow(D3DTA_TEXTURE),
        color_arg2: narrow(D3DTA_CURRENT),
        alpha_op: narrow(D3DTOP_SELECTARG1),
        alpha_arg0: narrow(D3DTA_CURRENT),
        alpha_arg1: narrow(D3DTA_TEXTURE),
        alpha_arg2: narrow(D3DTA_CURRENT),
        flags: FfStageFlags::HAS_TEXTURE,
    };
    ps.tt_projected_mask = 0b1;""")

# Upstream code read the table through the LazyLock; ours is a OnceLock behind `adapter_modes()`.
rep("windows/d3d9/src/direct3d9.rs",
"""    Some(
        ADAPTER_MODES
            .served
            .iter()
            .filter(move |m| m.format == format),
    )""",
"""    Some(
        adapter_modes()
            .served
            .iter()
            .filter(move |m| m.format == format),
    )""")

# Rust 1.99 (our pin) deprecates `fetch_update` in favour of `try_update`, same semantics.
rep("windows/d3d9/src/direct3d9.rs",
"""        .fetch_update(Ordering::Release, Ordering::Relaxed, |count| {""",
"""        .try_update(Ordering::Release, Ordering::Relaxed, |count| {""")
print("ok")
