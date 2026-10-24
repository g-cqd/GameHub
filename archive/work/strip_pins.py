p = "/Volumes/ExT2/GameHub/work/mtld3d-merge/windows/d3d9/src/surface.rs"
s = open(p).read()


def rep(old, new):
    global s
    assert s.count(old) == 1, old[:100]
    s = s.replace(old, new)


rep("""    pub fn new_implicit_backbuffer(device_inner: *mut DeviceInner, container: u64) -> Self {
        Self::backbuffer(device_inner, container, SurfaceFlags::empty())
    }

    /// The back buffer of an additional swap chain, which pins that swap chain while referenced.
    ///
    /// Shaped like [`Self::new_implicit_backbuffer`]: the swap chain caches it
    /// and frees it with itself, and it resolves its colour handle live from
    /// the device. `swap_chain` is the `Direct3DSwapChain9` wrapper that is its
    /// `GetContainer` and that it pins (see [`SurfaceFlags::PINS_SWAP_CHAIN`]).
    pub fn new_swap_chain_backbuffer(device_inner: *mut DeviceInner, swap_chain: u64) -> Self {
        Self::backbuffer(device_inner, swap_chain, SurfaceFlags::PINS_SWAP_CHAIN)
    }

    fn backbuffer(device_inner: *mut DeviceInner, container: u64, flags: SurfaceFlags) -> Self {
""", """    pub fn new_implicit_backbuffer(device_inner: *mut DeviceInner, container: u64) -> Self {
""")
rep("""            system_memory: None,
            flags,
            private_data""", """            system_memory: None,
            flags: SurfaceFlags::empty(),
            private_data""")
rep("""    /// The additional swap chain this back buffer pins while referenced, or 0.
    ///
    /// See [`SurfaceFlags::PINS_SWAP_CHAIN`].
    fn pinned_swap_chain(&self) -> u64 {
        if self.inner().flags.contains(SurfaceFlags::PINS_SWAP_CHAIN) {
            self.inner().container
        } else {
            0
        }
    }

    /// Whether nothing references this surface, publicly or through a device binding.
    const fn unreferenced(&self) -> bool {
        self.refcount == 0 && self.private_refcount == 0
    }

""", "")
rep("""        const CONTAINER_CACHED = 1 << 2;
        /// The back buffer of an additional swap chain, which it pins while referenced.
        ///
        /// Its first reference of either kind, public or a device binding,
        /// pins the swap chain it names as `container`, and its last one
        /// unpins it, so the swap chain and this surface with it are freed
        /// only once neither the application nor the device references the
        /// surface. Clear on the device's own implicit back buffer, which the
        /// device keeps.
        const PINS_SWAP_CHAIN = 1 << 3;
""", """        const CONTAINER_CACHED = 1 << 2;
""")
rep("""    if tex.is_null() {
        // The first reference of either kind pins an additional swap chain.
        let pin = {
            // SAFETY: live wrapper per the thunk; the borrow ends before the engine call.
            let obj = unsafe { &*this.cast::<Direct3DSurface9>() };
            if obj.unreferenced() {
                obj.pinned_swap_chain()
            } else {
                0
            }
        };
""", """    if tex.is_null() {
""")
rep("""    if tex.is_null() {
        // The release that takes the last reference of either kind unpins an
        // additional swap chain. Decided before the engine call, which can
        // free an ordinary surface and, through the device release it
        // forwards, tear down a device whose binding was this surface's other
        // reference; a release past zero is not the last reference.
        let swap_chain = {
            // SAFETY: live wrapper per the thunk; the borrow ends before the engine call.
            let obj = unsafe { &*this.cast::<Direct3DSurface9>() };
            if obj.refcount == 1 && obj.private_refcount == 0 {
                obj.pinned_swap_chain()
            } else {
                0
            }
        };
""", """    if tex.is_null() {
""")
rep("""    fn private_refcount_inc(&mut self) {
        let pin = if self.unreferenced() {
            self.pinned_swap_chain()
        } else {
            0
        };
        self.private_refcount += 1;""", """    fn private_refcount_inc(&mut self) {
        self.private_refcount += 1;""")
open(p, "w").write(s)
print("ok")
