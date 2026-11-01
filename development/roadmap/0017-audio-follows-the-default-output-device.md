---
status: in-progress
blocked-by: []
date: 2026-10-31
---

# 0017: winecoreaudio follows the macOS default output device

When the default output changes (headphones, the display's speakers), running games keep playing to the old device.
Use the `DefaultOutput` unit, or listen to `kAudioHardwarePropertyDefaultOutputDevice` and move the streams.

## Done when
Switching the output in macOS moves a running game's audio within a second, with no restart.

## Progress (2026-11-01)
Wine branch `wip/coreaudio-default-endpoint` (6cbabb9a169), kept off `main` because it doesn't work yet. It follows
winepulse's design: a render endpoint "macOS Default Output" with an empty device name at index 0 is the default.
Its streams use `kAudioUnitSubType_DefaultOutput`, and its device queries resolve the unit's current device.

Checked in a scratch prefix with the build tree:
- mmdevapi tests: capture, render, mmdevenum, propstore and dependency have 0 failures. spatialaudio has 8
  failures, as before the change.
- The endpoint is listed and is the default.
- A tone plays 30 s on it without error.

**It doesn't follow yet.** The owner heard the tone stay in the headphones. A trace showed the unit stayed on device
98 while the default was switched to 110 and back.

Facts, each tested on its own (tools in `tools/audio-probe/`):
- A native reference (`deftrack.swift`) with the same unit follows both switches within 2 s. It also follows when
  built for x86_64 (Rosetta), with Wine's stream format and channel layout, with the work on a secondary thread
  while the main thread runs `CFRunLoopRun` or `NSApplication.run`, and with `CFNotificationCenterGetDistributedCenter`.
- In the Wine process, a `kAudioHardwarePropertyDefaultOutputDevice` listener never fires, whether it is a
  callback or a block on a private dispatch queue. A direct `AudioObjectGetPropertyData` read keeps returning
  the old device.
- So the HAL client in a Wine process is not told about system-wide default changes. The DefaultOutput unit
  can't follow until it is.

## Next
Find what in a Wine process stops the HAL client's updates from coreaudiod. Compare the threads of a sampled Wine
process with the reference, then test in the reference what Wine does early in a process (its preloader address
reservations, its Mach exception ports), one at a time. Polling `default_device_id()` and moving the stream by hand
would not help: the polled value is stale too.

