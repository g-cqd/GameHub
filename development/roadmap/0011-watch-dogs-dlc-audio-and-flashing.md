---
status: in-progress
blocked-by: []
date: 2026-10-31
---

# 0011: Watch_Dogs, the Bad Blood dialogue, crackling and flashing

## Problems
- No dialogue in the Bad Blood DLC.
- Crackling audio.
- A flashing screen and textures. Not the DXMT staging allocator (ADR-0016).
- winecoreaudio's channel layout always fails: -10851, `kAudioChannelLayoutTag_UseChannelBitmap` on AUHAL.

## Done so far
- 5be348b: shared-mode render streams use the mix format's channel count, and starvation is reported.
- d7f20b8: the Ubisoft overlay is kept out of the game.

## Next
1. The per-stream format WARN in `unix_create_stream`, uncommitted in the Wine tree. Use it to see the format of the
   DLC's dialogue streams.
2. The DLLs loaded after the DLC loads.
3. The channel-layout call: set a layout tag that AUHAL accepts, or skip it for stereo.

## Done when
The Bad Blood dialogue plays, with no crackling over a 10-minute session and no flashing.
