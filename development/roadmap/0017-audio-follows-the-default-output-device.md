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

## Resolved (2026-11-01, Wine 88750cb47ad)
The branch works; the conclusion above was wrong. `tools/audio-probe/halprobe.c`, injected into Wine processes with
`DYLD_INSERT_LIBRARIES`, shows HAL notifications reaching them: a default-output listener fires within 10 ms of each
switch, registered before Wine starts or 4 s later from a secondary thread, in `cmd` and in `deftone.exe` with an
open stream. To see where a stream plays without anyone listening, a separate native process polls the speakers'
`kAudioDevicePropertyDeviceIsRunningSomewhere` while the default switches to them for 6 s and back:

| winecoreaudio | probe in the Wine process | speakers ran |
|---|---|---|
| branch | yes | 160 ms after the switch, released on the way back |
| branch | no | 180 ms after the switch, released on the way back |
| main (fixed device) | yes | never |

The earlier failure (the unit staying on device 98) came from that test's setup, a scratch prefix with the build
tree; device 98 doesn't exist now, so it wasn't reproduced. The endpoint is on `main` and installed in hub-2.
mmdevapi tests: 0 failures in capture, render, mmdevenum, propstore and dependency, as before.

## Next
- The owner hears it: a game running while the output is switched in macOS (the done-when). Not verified by ear.
- Capture still uses a fixed device (the default input at start): the same for input would use the HAL unit
  following `kAudioHardwarePropertyDefaultInputDevice`, as there is no DefaultInput unit.
