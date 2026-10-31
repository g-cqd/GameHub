---
status: not-started
blocked-by: []
date: 2026-10-31
---

# 0017: winecoreaudio follows the macOS default output device

When the default output changes (headphones, the display's speakers), running games keep playing to the old device.
Use the `DefaultOutput` unit, or listen to `kAudioHardwarePropertyDefaultOutputDevice` and move the streams.

## Done when
Switching the output in macOS moves a running game's audio within a second, with no restart.
