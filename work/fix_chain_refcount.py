"""An additional swap chain's back buffer retains its chain without changing the chain's public count.

Wine's d3d9 device.c:1781 (test_refcount) checks that GetBackBuffer on an
additional swap chain leaves the swap chain's refcount at 1. The back buffer's
public references therefore retain the chain through its private count, the
same counter its binding references already use, instead of a public AddRef.
"""
p = "/Volumes/ExT2/GameHub/work/mtld3d-merge/windows/d3d9/src/surface.rs"
s = open(p).read()


def rep(old, new):
    global s
    assert s.count(old) == 1, old[:90]
    s = s.replace(old, new)


rep("""        // SAFETY: the chain is live; balance the surface's existing public reference.
        unsafe {
            crate::com_ref::com_add_ref::<crate::swapchain::Direct3DSwapChain9>(chain.cast())
        };
        surface_release(core::ptr::from_mut(self).cast());""",
"""        // SAFETY: the chain is live; balance the surface's existing public reference,
        // whose release below drops the chain reference its 1-to-0 edge holds.
        unsafe { &mut *chain }.private_refcount_inc();
        surface_release(core::ptr::from_mut(self).cast());""")

rep("""        if count == 1 && !chain.is_null() {
            // SAFETY: the cached surface names its live owning chain.
            unsafe {
                crate::com_ref::com_add_ref::<crate::swapchain::Direct3DSwapChain9>(chain.cast())
            };
        }
        return count;""",
"""        if count == 1 && !chain.is_null() {
            // The chain stays alive while its back buffer is referenced, but its
            // public count is the application's alone (Wine's test_refcount reads
            // it as 1 after GetBackBuffer), so the retain is a private one.
            // SAFETY: the cached surface names its live owning chain.
            unsafe { &mut *chain }.private_refcount_inc();
        }
        return count;""")

rep("""        if count == 0 && !chain.is_null() {
            // SAFETY: the 0-to-1 edge retained this chain. Releasing it can free
            // the cached surface, so this call must not access the surface again.
            unsafe {
                crate::com_ref::com_release::<crate::swapchain::Direct3DSwapChain9>(chain.cast())
            };
        }
        return count;""",
"""        if count == 0 && !chain.is_null() {
            // SAFETY: the 0-to-1 edge retained this chain privately. Releasing it
            // can free the cached surface, so this call must not access the
            // surface again.
            unsafe {
                crate::swapchain::Direct3DSwapChain9::private_refcount_dec_maybe_finalize(chain);
            };
        }
        return count;""")
open(p, "w").write(s)

# keep the swap chain's own description of the model accurate
p2 = "/Volumes/ExT2/GameHub/work/mtld3d-merge/windows/d3d9/src/swapchain.rs"
t = open(p2).read()
for old, new in [
    ("""/// referenced by nothing either: the back buffer's public references retain
/// this chain publicly and its binding references retain it privately, so
/// whichever of the two counts reaches zero last finalizes it.""",
     """/// referenced by nothing either: the back buffer's references, public or
/// binding, retain this chain through its private count, which leaves the
/// public count the application's own, so whichever of the two counts reaches
/// zero last finalizes it."""),
    ("""    /// Initialized before publication; unused on the implicit chain. Its
    /// public references retain this chain on their 0-to-1 edge, and each
    /// binding reference retains this chain privately.""",
     """    /// Initialized before publication; unused on the implicit chain. Its
    /// public references retain this chain privately on their 0-to-1 edge, as
    /// each binding reference does, so the chain's public count stays the
    /// application's."""),
    ("""    // The chain owns one stable, independently allocated surface. Its public
    // and binding references retain this chain until its last user releases it.""",
     """    // The chain owns one stable, independently allocated surface. Its public
    // and binding references retain this chain privately until its last user
    // releases it; the chain's public count is not touched."""),
]:
    assert t.count(old) == 1, old[:80]
    t = t.replace(old, new)
open(p2, "w").write(t)
print("ok")
