# How to restart or start the GameHub Wine server

Written 2026-10-11, after a full restart of the wineserver for the EA prefix.

## What was done on 2026-10-11, about 22:30

- The old wineserver (pid 20193) served `/Volumes/ExT2/GameHub/Prefix`. It had been
  running since about 20:12, together with EA Desktop and its services (about 18
  processes). Crysis 3 was no longer running.
- All of them were stopped with `wineserver -k`. `wineserver -w` returned, and no Wine
  process, x87sidecar or `.exe` was left.
- A fresh wineserver was started with the same environment as `bin/start-ea.sh`
  (msync on, runtime `hub-0-winemacfs-dxmtrtv`). It runs in persistent mode (`-p`), so it
  stays up until stopped. It is pid 55003 in the run above.
- EA Desktop was **not** restarted. Start it as described under "Start EA" below.

The runtime used is `/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv`, the default
of `bin/start-ea.sh`. Use the same runtime to stop and start; mixing runtimes on one
prefix gives a "wineserver version mismatch".

## Check what is running

```bash
ps -axo pid,etime,command | grep -iE "wineserver|\.exe|x87sidecar" | grep -v grep
```

Find the prefix a wineserver serves (its current directory is the prefix):

```bash
lsof -a -d cwd -c wineserv
```

## Stop everything in the prefix (full restart, step 1)

This closes EA Desktop and any running game. Unsaved progress is lost.

```bash
bash -c '
RT=/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv
export WINEPREFIX=/Volumes/ExT2/GameHub/Prefix
"$RT/bin/wineserver" -k        # kill every Wine process of this prefix, then the server
"$RT/bin/wineserver" -w        # wait until the server has exited
ps -axo pid,command | grep -iE "wineserver|\.exe|x87sidecar" | grep -v grep || echo "all stopped"
'
```

If something is still listed after a minute (a hung game), stop it with
`kill -9 <pid>` and run the two `wineserver` lines again.

## Start EA (normal way; it starts the wineserver itself)

```bash
/Volumes/ExT2/GameHub/bin/start-ea.sh
```

It prints `started pid … log /Volumes/ExT2/GameHub/Hub/Logs/ea-<date>.log`.

- To use another runtime (for example the clone with the Crysis 3 DXMT fix, once it is
  installed), stop everything first, then run
  `HUB_RUNTIME=/Volumes/ExT2/GameHub/Runtimes/<runtime name> /Volumes/ExT2/GameHub/bin/start-ea.sh`.
- Debug logging: `HUB_WINEDEBUG=err+all /Volumes/ExT2/GameHub/bin/start-ea.sh`.

## Start only the wineserver (without EA)

This is what was done today. It uses the same environment as `start-ea.sh`, which
matters because msync must match between the server and the programs:

```bash
bash -c '
RT=/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv
R="/Users/gc/Library/Application Support/BF3Mac"
cd "$R" && env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin LANG=en_US.UTF-8 USER=Player \
  HOME="$R/RuntimeHome/Player" TMPDIR="$R/Temporary" \
  WINEPREFIX=/Volumes/ExT2/GameHub/Prefix WINEDEBUG=-all WINEMSYNC=1 \
  "$RT/bin/wineserver" -p
'
```

It prints `msync: up and running.`

- `-p` keeps it running until `wineserver -k`.
- Without `-p` it exits a few seconds after the last Wine program closes. That is the
  normal behaviour when EA starts it.
- `start-ea.sh` connects to an already running server, so starting the server first is
  optional.

## Full restart in one go

Run "Stop everything", then `bin/start-ea.sh`.
