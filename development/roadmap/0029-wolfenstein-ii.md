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
