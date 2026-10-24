# Start, stop and restart the GameHub Wine session

All launchers share one prefix (`$HUB_ROOT/Prefix`, default `/Volumes/ExT2/GameHub`) and one runtime (`hub-1`). One
wineserver serves the prefix, so a launcher or game started with a different runtime or environment needs a restart.
Use `launcher/hub`; it picks the runtime and prefix itself.

```bash
launcher/hub status               # runtime and launchers that are running
launcher/hub start steam|ea|ubisoft|epic [--metalfx [FACTOR]] [--dxgi wined3d] [--debug SPEC]
launcher/hub play <game>          # starts the launcher it needs, then the game
launcher/hub stop [game]          # no argument: stop everything in the prefix (wineserver -k, then -w)
launcher/hub play <game> --restart   # stop what runs in the prefix first
```

`hub play` restarts the session by itself when the runtime, MetalFX factor or backend differs from the running one, and
refuses while another game runs unless `--restart` is given. Stopping closes the launcher and any running game; unsaved
progress is lost.

## Check what is running

```bash
ps -axo pid,etime,command | grep -iE "wineserver|\.exe|x87sidecar" | grep -v grep
lsof -a -d cwd -c wineserv        # the current directory of a wineserver is the prefix it serves
```

## Stop by hand (when `hub stop` cannot)

```bash
RT=/Volumes/ExT2/GameHub/Runtimes/hub-1
export WINEPREFIX=/Volumes/ExT2/GameHub/Prefix
"$RT/wineserver" -k      # kill every Wine process of this prefix, then the server
"$RT/wineserver" -w      # wait until the server has exited
```

If a hung game stays after a minute, `kill -9 <pid>` it and run the two `wineserver` lines again. Never mix runtimes on
one prefix: it gives a "wineserver version mismatch".

Logs are in `$HUB_ROOT/Hub/Logs/` (`<launcher>-<date>.log`, `play-<game>-<date>.log`).
