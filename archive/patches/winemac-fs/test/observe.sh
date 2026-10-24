#!/bin/bash
# Observe a running fs_test from the macOS side, keyed on its log lines:
# physical display mode, the test's Cocoa windows, the frontmost app and a
# screenshot at each stage.
# Usage: observe.sh <test-log> <out-dir> <owner-substring>
LOG="$1"; OUT="$2"; OWNER="$3"
W=~/.agent-harness/bin/work
mkdir -p "$OUT"
snap() {
    echo "=== $1" >> "$OUT/observe.txt"
    /tmp/wfs/modes >> "$OUT/observe.txt"
    /tmp/wfs/winlist "$OWNER" >> "$OUT/observe.txt"
    [ -n "$2" ] && screencapture -x -t png "$OUT/$2.png"
}
snap before
$W wait --log "$LOG" "after same-size" --timeout 120 >/dev/null && snap after-same-size
$W wait --log "$LOG" "after smaller mode" --timeout 60 >/dev/null && snap after-smaller-mode
$W wait --log "$LOG" "t= 2s" --timeout 60 >/dev/null && snap t2 shot-t2
$W wait --log "$LOG" "t= 5s" --timeout 60 >/dev/null && snap t5 shot-t5
$W wait --log "$LOG" "after restore" --timeout 60 >/dev/null && snap after-restore
