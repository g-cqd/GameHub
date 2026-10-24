# GTA V (Legacy, Epic) graphics: black outlines, dark textures, texture reloading

Status: **investigation, nothing here is verified yet.** Symptoms reported on this Mac (MacBook Pro, M2 Pro, 16 GB): black
strokes around shapes and polygons, textures that load, unload and load again, and effects and textures that look very dark
or black.

## What the game runs on

| Item | Value | Source |
|---|---|---|
| Renderer | `GTA5.exe` uses DXMT (Direct3D 11 on Metal), feature level 11_0 | compatdb line in `Hub/Logs/epic-*.log`; `DX_Version=2` in `settings.xml` |
| Display mode | 1920x1200, fullscreen, VSync on, Wine Retina mode on | `Documents/Rockstar Games/GTA V/settings.xml` |
| Anti-aliasing | MSAA 4x **and** FXAA on, reflection MSAA 2x, TXAA off | same file |
| Heavy settings | Tessellation very high, SSAO high, shadows high with soft shadows 2, textures High | same file |
| Memory the game sees | `DedicatedVideoMemory` = half of Metal's recommended working set = **6.36 GB**, `SharedSystemMemory` = 0, budget 12.7 GB | DXMT `src/dxgi/dxgi_adapter.cpp` (`FIXME: use a more appropriate value`); working set 12.71 GB measured on this Mac with `MTLDevice.recommendedMaxWorkingSetSize` |
| Anti-cheat | `GTA5.exe` is started by the Rockstar Launcher with `-nobattleye -noBE` | `Library/Epic/GTAV/args.txt` |

## Hypotheses, in the order to test them

1. **Black outlines and black effects: NaN or infinity in a shader.** On Apple GPUs a NaN in a texture coordinate or a fused
   multiply-add gives black pixels, typically at geometry edges and in post-processing. DXMT has two switches for it,
   `d3d11.sampleNaNToZero` and `d3d11.defuseFma`; the BF3 tuning in this project turns both on. They are now on for
   `GTA5.exe` in `launcher/settings/GTAV/dxmt.conf`. Test: play with them on, then set both to `False` and compare.
2. **Black outlines: the MSAA resolve.** The game uses MSAA 4x and FXAA together. Test: set MSAA to Off in the game (FXAA
   stays) and look at the same scene.
3. **Texture reloading: the memory budget.** The game sizes its texture streaming from the 6.36 GB it is told it has, and the
   same unified memory also holds the frame buffers (MSAA 4x multiplies them), the shadow maps and the game's own
   RAM. With other heavy processes running, macOS also compresses and swaps (swap was 2 GB used of 3 GB). Test: lower the
   texture quality one step or turn MSAA off, close other heavy processes, and watch whether textures still reload.
4. **Dark picture: the HDR path of the XDR display.** DXMT can report an HDR output on this panel. Test:
   `dxgi.forceSDR = True` in the same file.
5. **MetalFX.** Not involved in the reports above (they predate it). Judge it separately: start with `hub play gtav --metalfx
   1.875` and compare; MetalFX is applied to `GTA5.exe` only and the factor multiplies the game's 1920x1200.

## How to test one change at a time

1. Edit `launcher/settings/GTAV/dxmt.conf` (DXMT reads it when the game starts) or the in-game graphics settings.
2. Start the game from the Epic launcher, or with `launcher/hub play gtav`. Do not change the launcher session in between.
3. Look at the same place each time. Note the three symptoms separately.
4. DXMT writes its warnings to `Hub/Logs/dxmt-gtav/GTA5_d3d11.log` and `GTA5_dxgi.log` (level `warn`); an unsupported format or
   feature would show there. Send those files with the result.

## Not tried yet

- Changing what DXMT reports as video memory (the 6.36 GB is a fixed fraction in DXMT's source, not a setting).
- Comparing with `dxgi=wined3d` for `GTA5.exe`; the Rockstar Launcher needs wined3d on OpenGL already, GTA V itself has not been
  run on it.
