# Red Dead Redemption 2: button prompts flickering with a DualShock 4

Status: 2026-11-14. Fixed for sessions of the Rockstar launcher; confirmed by the owner in RDR2 with a DualShock 4 on USB
(prompts stay PlayStation, buttons, sticks and triggers work). Bluetooth, the DualSense and rumble are not tested.

## Cause

The prefix pins the DualShock 4 (`054C/05C4`) and the DualSense (`054C/0CE6`) to Wine's SDL-mapped device
(`HKLM\System\CurrentControlSet\Services\WineBus\Devices\<vid/pid>`, `Hidraw=0`). That is the NFS 2015 recipe
(`apps/bundler/docs/NFS2015.md` §3.5): games that only read XInput see nothing otherwise.

The mapped device is one pad with two faces: an XInput pad in slot 0, and a HID gamepad that keeps the Sony ids
(`hid#vid_054c&pid_05c4&ig_00`). RDR2 reads both. It opens every DirectInput gamepad and treats one with Sony ids as a
DualShock, and it polls XInput. Measured over one run of a few minutes (`WINEDEBUG=trace+dinput,trace+xinput`): 12700
`GetDeviceState` calls on the DirectInput device and 12701 `XInputGetState` calls on slot 0. Each report of either one makes
the game show that device's prompts, so they alternate between PlayStation and Xbox.

Restarting the prefix does not change it, and neither did the stale `winedevice.exe` of an earlier session that was found
alongside (ruled out: the flicker was still there with a single one).

## Fix

`launcher/hub` gives a session of the Rockstar launcher the pad's own HID device (`Hidraw=1`, `set_pad_mode`). WineBus then
ignores the SDL device and creates the raw one; RDR2 finds `hid#vid_054c&pid_05c4` (no `&ig_00`) in DirectInput, and no
XInput pad is connected. This is what the game sees on Windows.

- WineBus reads the keys when the session starts, so the hub writes them before starting the launcher, stops the prefix,
  and starts it again. With a session already running it prints a note and changes nothing.
- The values it replaced are kept in `Hub/State/pad-hidraw.json`; the next session of another launcher writes them back, so
  XInput-only games keep their mapped pad.
- The switch is per launcher session, not per game: a Rockstar title that reads only XInput would not see a Sony pad.
  None other than RDR2 has been tried.
- GTA V started through Epic is an Epic session and keeps the XInput mapping.

Evidence of both states: `Hub/Logs/rdr2-dualshock-evidence.txt` on the volume.
