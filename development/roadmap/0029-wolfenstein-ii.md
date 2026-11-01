---
status: in-progress
blocked-by: []
date: 2026-10-31
---

# 0029: Wolfenstein II: The New Colossus

The game uses Vulkan only (`NewColossus_x64vk.exe`, idTech 6.5), so it runs through winevulkan and MoltenVK 1.4.1.

## Fixed (2026-10-31)

### It didn't start
`FATAL ERROR: vkCreateDevice failed with error (VK_ERROR_FEATURE_NOT_PRESENT)`. MoltenVK named the 39th
`VkPhysicalDeviceFeatures` flag, counted from 1 in `MVKDevice::enableFeatures`: `shaderCullDistance`, which Metal
doesn't have.

Wine 53e3e70 drops core features the host lacks from the request, with a FIXME naming each one. After it, the game
reaches its menus.

### It flashed black
A screenshot burst showed whole black frames between normal ones. Every present returned `VK_SUBOPTIMAL_KHR` from
MoltenVK. The image size (5120x2880) equalled the client rect, but not the Metal layer's natural size, so Wine
didn't request present scaling. The game then destroyed its surface and swapchain, re-posted its window (392 times
in a short session) and created new ones, and each new Metal view showed a black frame.

Wine 48554b1 always creates the swapchain with deliberate scaling when swapchain maintenance is available. In the
next session there were 2 SUBOPTIMAL results at startup (the window still sizing) and no surface teardown.

### Still flashing, and the window not fullscreen (fixed later on 2026-10-31)
- **Present scaling was never requested** (Wine 9001874). `convert_instance_create_info` cleared
  `has_VK_KHR_win32_surface` before testing it, so `VK_EXT_surface_maintenance1` was never enabled. The swapchain
  code also tested the KHR swapchain_maintenance1 flag, which winevulkan doesn't expose, and it replaced the game's
  `pNext` chain. In the fullscreen Space the game recreated its swapchain 1,119 times in a minute. After the fix: 0.
- **The game used a decorated window** whose client area fills the screen. winemac now gives such a window no
  Cocoa title bar, so it enters the fullscreen Space (cb9d708).
- **Dock and menu bar:** in the Space winemac keeps them hidden (`HideDock | HideMenuBar`). A native probe showed
  that with AppKit's auto-hide options the Dock appears at the bottom edge, and with these it doesn't.
- **Hidden cursor:** while the game hides it in the Space, it is confined to the window.
- **Minimizing:** when the game minimizes itself on focus loss, the window stays in its Space instead of the
  refuse, restore and re-minimize loop that left and re-entered the Space each time.
- **Size after restore:** `ShowWindow` returned raw pixels, so a window restored from minimized was 10240x5760
  (zoomed in, pixelated). It now returns the window's own coordinates.
- **Prefix setting:** `HKCU\Software\Wine\Mac Driver\FullscreenMode` was `borderless` (set by an unknown earlier
  session) and is now `native`, the fork's default, with the owner's agreement. It applies to every game in the
  prefix.

Owner-confirmed after these: the resolution is right and there is no flashing on Cmd-Tab.

## Regression on 2026-11-01: window wrong after Wine 24a06557322
The owner: "the window handling of wolfenstein is atrocious": not fullscreen, wrong ratio, black areas over Steam,
lost on a Space switch, mouse problems. With the win32u and winemac from before 24a06557322 the game stayed
fullscreen for a 54-minute session (14:22–15:16, no Space switch tried).

- **Cause of the mode change:** the game saves its resolution as an index into the mode list (`r_mode "19"` in
  `Wolfenstein II The New ColossusConfig.local`). Before the commit the list had 25 modes and index 19 was 2560x1440,
  the display's "looks like" size, which emulation maps 2:1 onto the 5120x2880 panel, so it looked native. With
  the host modes the list has 49 and the game ended at **1440x900** (EnumDisplaySettings during play): 16:10,
  pillarboxed on the 16:9 screen.
- **Black areas over Steam:** reproduced. During the game's 1440x900 mode Steam's web view was drawn small in the
  top-left with the rest of its window black, and it stayed that way after the game exited (the top-level window
  had its normal size; a child didn't). fstest holding 1440x900 for 60 s showed a related effect: Steam's window
  grew to 4419x2453 points during the mode (Win32 coordinates scaled by the emulated ratio, as when a real mode
  shrinks the Windows desktop) and came back intact, so the stuck child is not reproduced by fstest.
- **Fixed (Wine f5f21d89665):** an emulated mode now belongs to the process that set it. Other processes load the
  physical mode, so Steam keeps its window (1381x767 points during the game) and is drawn whole after it (1% black
  in its content against 78% before). The cost is a deliberate difference from Windows: a mode set by one process
  isn't seen by another (18 new failures in user32's monitor test, all of that kind).
- **Still open:** the game remembers `r_mode 19`, which is now 1440x900, so it is pillarboxed until 2560x1440 (or
  3840x2160) is picked again in its video options. Space switching and the mouse were not retested: they need
  someone playing.

## Open
- **Mouse after Cmd-Tab:** the hidden cursor is not confined again after switching back. On deactivation winemac
  probably un-hides the cursor, and the game never hides it again, because on Windows that state persists. Trace
  it with `+cursor` and restore the hidden state on reactivation.
- **Resolutions:** the game sees a 5120x2880 desktop (the HiDPI backing store) and lists sizes from it
  (roadmap 0015).
- **Steam bootstrapper crash:** once, after a client self-update, the bootstrapper died relaunching Steam
  (`nested exception on signal stack`, 20:54). The next start worked.

## Done when
The owner plays a level with no flashing, with mouse look and menu clicks that work, at a native-looking resolution.
