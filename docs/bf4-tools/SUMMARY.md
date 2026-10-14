# Battlefield 4 on your Mac

`PLAN.md` has the detail and sources. Nothing was downloaded, installed or launched; mbp23 was only
read.

**The method transfers; the renderer is the gamble.** The EA client layer, app skeleton, recipe
system and all 20 packaging gates work for BF4 essentially unchanged.

**The odds, in two numbers.** BF4 is **ProtonDB Gold, 347 reports** - game, EA app and DRM all work
under Wine on Linux, multiplayer included. But CodeWeavers rates it **"Installs, Will Not Run" on
macOS**. Every Linux success routes D3D11 through DXVK/Vulkan; ours would use **DXMT, which nobody
has reported trying.** That decides the project.

**Genuinely new work.** `bf4.exe` is **x86_64**; our validator hardcodes `i386`. The launch chain is
**three processes** (EA app -> `BFLauncher.exe` -> `BF4WebHelper.exe`, a localhost HTTP server ->
`bf4.exe`). DICE confirmed **DX11.1** compute-shader lighting, with `Dx10`/`Dx10_1` as a fallback.
PunkBuster is **optional by EA's own design**; we will not work around it.

**Your decision, first: 64-bit `bf4.exe` or 32-bit `bf4_x86.exe`?** 64-bit is the real game; 32-bit is
where our tooling already lives but limits graphics and runs worse. I recommend 64-bit, after a
one-hour `nvapi64.dll` load check that could flip it.

**Free today:** open `battlelog.battlefield.com`. BF4's multiplayer UI *is* Battlelog, which EA calls
"no longer supported". If it is dead, this is campaign-only.

**Logistics:** download on mbp23 to `ExT2` (387 GiB free); this Mac has 27 GiB against ~32 GiB. The
folder already there is evidence, not an install. **Your part: pick the architecture, sign in to EA
once, start the download, play one session.**

**Legally:** your copy, your hardware, the genuine unmodified EA app, your own sign-in. No emulator,
crack, patched DLL or bypass. Import-only ships no EA bytes.
