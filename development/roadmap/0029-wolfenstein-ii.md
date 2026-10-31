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

## Open
- **Mouse:** the owner reports the mouse "is not correctly picked up". The cursor trace shows relative motion
  reaching the game window (in steps of 2, the HiDPI scale) and the cursor confined to the window.
  `RegisterRawInputDevices` flags 0x230 (no-legacy and capture) are partly unhandled in Wine. The per-frame window
  re-posting reset the confinement on every frame, so check again with the flashing fixed before changing anything.
- **Display size:** the game sees a 5120x2880 desktop, the HiDPI backing size (roadmap 0015), and its Options menu
  offers 2560x1440 at most.

## Done when
The owner plays a level with no flashing, with mouse look and menu clicks that work, at a native-looking resolution.
