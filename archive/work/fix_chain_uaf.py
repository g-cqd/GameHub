"""Keep the device alive across the chain decrement in an additional back buffer's last Release.

With the chain retained privately, the chain holds no device reference once the
application released it, so the back buffer's own forwarded reference can be
the device's last one: com_release would tear the device down and the chain's
finalize after it would touch the freed device. A temporary device reference
brackets the decrement so the device is released after the chain.
"""
root = "/Volumes/ExT2/GameHub/work/mtld3d-merge/windows/d3d9/src/"


def rep(path, old, new):
    p = root + path
    s = open(p).read()
    assert s.count(old) == 1, (path, old[:90])
    open(p, "w").write(s.replace(old, new))


rep("surface.rs",
"""        let chain = {
            // SAFETY: this is the live surface whose reference is being released.
            let surface = unsafe { &*this.cast::<Direct3DSurface9>() };
            if surface.refcount == 0 {
                return 0;
            }
            surface.forward_swapchain()
        };
        // SAFETY: the surface owns the public reference being released.
        let count = unsafe { crate::com_ref::com_release::<Direct3DSurface9>(this) };
        if count == 0 && !chain.is_null() {
            // SAFETY: the 0-to-1 edge retained this chain privately. Releasing it
            // can free the cached surface, so this call must not access the
            // surface again.
            unsafe {
                crate::swapchain::Direct3DSwapChain9::private_refcount_dec_maybe_finalize(chain);
            };
        }
        return count;""",
"""        let (chain, device) = {
            // SAFETY: this is the live surface whose reference is being released.
            let surface = unsafe { &*this.cast::<Direct3DSurface9>() };
            if surface.refcount == 0 {
                return 0;
            }
            let chain = surface.forward_swapchain();
            let device = if chain.is_null() {
                core::ptr::null_mut()
            } else {
                crate::com_ref::ComChild::device_forward_target(surface)
            };
            (chain, device)
        };
        // An additional chain retained privately holds no device reference once
        // the application has released it, so this surface's forwarded one can
        // be the device's last: hold the device across the chain's finalize,
        // which still reaches it, and release it after.
        crate::device::device_wrapper_add_ref(device);
        // SAFETY: the surface owns the public reference being released.
        let count = unsafe { crate::com_ref::com_release::<Direct3DSurface9>(this) };
        if count == 0 && !chain.is_null() {
            // SAFETY: the 0-to-1 edge retained this chain privately. Releasing it
            // can free the cached surface, so this call must not access the
            // surface again.
            unsafe {
                crate::swapchain::Direct3DSwapChain9::private_refcount_dec_maybe_finalize(chain);
            };
        }
        crate::device::device_wrapper_release(device);
        return count;""")

rep("swapchain.rs",
"""// `private_refcount` the back buffer's binding references; `finalize` frees an app-owned""",
"""// `private_refcount` the back buffer's references; `finalize` frees an app-owned""")

rep("com_ref.rs",
"""    /// `0` for wrappers that have none (queries, state blocks, swapchains).""",
"""    /// `0` for wrappers that have none (queries, state blocks); an additional
    /// swap chain counts its back buffer's references here.""")
print("ok")
