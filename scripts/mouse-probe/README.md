# Mouse probe

Two small programs that show which mouse buttons, wheels and function keys reach macOS and which reach a Windows program under
the hub's Wine. They log mouse and scroll events and the keys F13-F24, `[`, `]`, browser and media keys; they log no other key.

| File | What it does |
|---|---|
| `macprobe.swift` | `swiftc -o macprobe macprobe.swift; ./macprobe LOGFILE SECONDS`: global macOS event monitor (what Wine's Mac driver is offered) |
| `winprobe.c` | `x86_64-w64-mingw32-clang -mwindows -o mxprobe.exe winprobe.c -luser32`: window that logs `WM_*BUTTON*`, `WM_XBUTTON*`, `WM_MOUSEWHEEL`, `WM_MOUSEHWHEEL`, Raw Input mouse flags and `GetSystemMetrics` button counts |
| `wine_hub.py` | `python3 wine_hub.py bg 'E:\work\mxprobe.exe' 'E:\work\mxprobe.log'` runs a Windows program under `hub-1` with the hub's environment (`fg` waits and prints) |

Copy the exe to `$HUB_ROOT/work/` first. Click the probe window before pressing controls; delete the logs afterwards.
