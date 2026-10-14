#!/bin/bash
# prefix-running.sh PREFIX: exit 0 (and explain on stdout) if any process or wineserver lock uses the
# Wine prefix PREFIX; exit 1 if it is idle; exit 64 on a usage error. Read-only. Used by regrewrite.py.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
if [ "$#" -ne 1 ] || [ -z "$1" ]; then echo "usage: prefix-running.sh PREFIX" >&2; exit 64; fi
P=${1%/}
if prefix_wine_running; then
  printf '%s\n' "$PREFIX_RUN_REASON"
  exit 0
fi
exit 1
