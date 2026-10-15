#!/bin/bash
# Run a command with the cloned BF3 runtime (new winemac.so) in the throwaway prefix.
# Usage: run.sh <runtime-dir> <wine args...>
RT="$1"; shift
export WINEPREFIX=/Volumes/ExT2/GameHub/work/winemac-fs/prefix
export WINEDLLOVERRIDES="mscoree,mshtml=${EXTRA_OVERRIDES:+;$EXTRA_OVERRIDES}"
export WINEDEBUG="${WINEDEBUG:--all,err+all}"
exec "$RT/bin/wine" "$@"
