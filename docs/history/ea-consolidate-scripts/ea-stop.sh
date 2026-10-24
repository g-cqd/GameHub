#!/bin/bash
# ea-stop.sh: stop EA Desktop and the Wine server of the SHARED prefix only.
# usage: ea-stop.sh [--dry-run|--apply]      (default --dry-run)
# Exit 0 only when no process uses WINEPREFIX=$P and the wineserver lock of $P is free; 1 if the
# prefix is still in use at the end. Other prefixes (e.g. work/wine-gepperf-tools/prefix) are never
# signalled: every wine command runs under `env -i ... WINEPREFIX=$P`, and the only pids this
# script ever signals are its own short-lived waiter children.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
STAGE=STOP
parse_mode "$@"
no_extra_args
install_trap

WAIT_SECS=${EA_STOP_WAIT_SECS:-120}        # bounded wineserver -w
TASKKILL_SECS=${EA_STOP_TASKKILL_SECS:-60}  # bounded taskkill / wineserver -k

require_work
log "ea-stop (shared prefix $P), mode=$([ "$APPLY" = 1 ] && echo APPLY || echo dry-run)"
if ! prefix_wine_running; then
  log "prefix idle, nothing to stop"
  exit 0
fi
log "prefix in use: $PREFIX_RUN_REASON"

if [ "$APPLY" != 1 ]; then
  for exe in EADesktop.exe EABackgroundService.exe EALocalHostSvc.exe; do
    log "WOULD: env -i ... WINEPREFIX=$P $RT/bin/wine taskkill /IM $exe"
  done
  log "WOULD: env -i ... WINEPREFIX=$P $RT/bin/wineserver -w   (bounded ${WAIT_SECS}s with work wait --pid)"
  log "WOULD: if still in use: wineserver -k, then wineserver -w again (bounded), under the same environment"
  exit 0
fi

# the server may exit between two steps; never start a fresh server for the prefix by accident
for exe in EADesktop.exe EABackgroundService.exe EALocalHostSvc.exe; do
  if ! prefix_wine_running; then log "prefix went idle before taskkill $exe"; break; fi
  rc=0
  run_bounded "$TASKKILL_SECS" "wine taskkill /IM $exe" "${WINE_ENV[@]}" "$RT/bin/wine" taskkill /IM "$exe" || rc=$?
  log "taskkill /IM $exe: rc=$rc (non-zero normally means the process was not running)"
done

if prefix_wine_running; then
  rc=0
  run_bounded "$WAIT_SECS" "wineserver -w" "${WINE_ENV[@]}" "$RT/bin/wineserver" -w || rc=$?
  log "wineserver -w: rc=$rc"
fi

if prefix_wine_running; then
  log "prefix still in use after graceful stop: $PREFIX_RUN_REASON; escalating to wineserver -k"
  rc=0
  run_bounded "$TASKKILL_SECS" "wineserver -k" "${WINE_ENV[@]}" "$RT/bin/wineserver" -k || rc=$?
  log "wineserver -k: rc=$rc"
  if prefix_wine_running; then
    rc=0
    run_bounded "$WAIT_SECS" "wineserver -w after -k" "${WINE_ENV[@]}" "$RT/bin/wineserver" -w || rc=$?
    log "wineserver -w (after -k): rc=$rc"
  fi
fi

if prefix_wine_running; then
  log "FAILED: prefix still in use: $PREFIX_RUN_REASON"
  exit 1
fi
log "prefix idle: EA and the wineserver of $P are stopped"
