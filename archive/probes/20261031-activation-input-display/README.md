# Probes of 2026-10-31: activation, input, display modes, KUSD

These are the sources of the probe programs one session built in `/tmp/kusd`, kept because `/tmp` doesn't survive a
reboot. The binaries were not kept: rebuild them from these sources if needed.

| Kind | Files | Built with |
|---|---|---|
| Windows probes | `*.c`; `loop.s` and `l2.s` (assembly) | llvm-mingw, run in the prefix as `C:\<name>.exe` |
| macOS probes | `*.swift` | `swiftc` |

What each one probes:
- `pcs`, `pcsall`: process and console state.
- `dbch`: debug channels.
- `wins`: windows.
- `dienum`, `dipad`: DirectInput.
- `fmt`: audio formats.
- `center`: window centring.
- `mode`, `mon`, `modes.swift`: display modes.
- `kusd`: KUSER_SHARED_DATA.
- `fg`, `front`, `activate`, `selfact`: activation.
- `handoff.swift`: the working activation handoff, now `launcher/macos/activate-handoff.swift`.

The outputs are in `out.txt`, `threads.txt` and `mon.out`.
