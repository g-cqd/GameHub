#!/usr/bin/env bash
# Host-runnable subset of `make check` / `make test` for this Mac.
# Usage: host_gates.sh <checkout> <logdir> <target-root>
# Runs every leg, never stops early; each leg's output goes to <logdir>/<leg>.log
# and its exit code to <logdir>/summary.txt.
set -u
# macOS tools first: Homebrew coreutils cp and a Python sample shim shadow the ones the tests expect.
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"
TREE=$1
LOGS=$2
TGT=$3
mkdir -p "$LOGS" "$TGT"
H=$(rustc -vV | sed -n 's/^host: //p')
DENY=(--config 'build.warnings="deny"')
SUM="$LOGS/summary.txt"
: > "$SUM"

leg() { # leg <name> <dir> <cmd...>
  local name=$1 dir=$2; shift 2
  local start=$(date +%s)
  (cd "$TREE/$dir" && "$@") > "$LOGS/$name.log" 2>&1
  local rc=$?
  echo "$name exit=$rc secs=$(( $(date +%s) - start )) cmd=[cd $dir && $*]" >> "$SUM"
}

{
  echo "tree=$TREE head=$(git -C "$TREE" rev-parse HEAD) index-tree=$(git -C "$TREE" write-tree)"
  echo "dirty-vs-index: $(git -C "$TREE" diff --name-only | wc -l | tr -d ' ') files"
  rustc -vV; cargo -V; cargo fmt --version; cargo clippy -V
  echo "host=$H"; echo "PATH=$PATH"; command -v cp sample python3 cargo
} > "$LOGS/versions.txt" 2>&1

# fmt-check (stable rustfmt; the Makefile pins nightly, so unstable options in rustfmt.toml are ignored)
leg fmt-windows windows cargo fmt --check
leg fmt-unix unix cargo fmt --check

# clippy-native
leg clippy-native-windows windows env CARGO_TARGET_DIR="$TGT/windows" cargo clippy -p mtld3d-core --features mtld3d-core/disk-cache --target "$H" --all-targets "${DENY[@]}"
leg clippy-native-unix unix env CARGO_TARGET_DIR="$TGT/unix" cargo clippy --all-targets "${DENY[@]}"

# clippy-perf (native half only; the PE half needs a Windows std)
leg clippy-perf-windows windows env MTLD3D_PERF=1 CARGO_TARGET_DIR="$TGT/perf-windows" cargo clippy -p mtld3d-core --features mtld3d-core/disk-cache --target "$H" --all-targets "${DENY[@]}"
leg clippy-perf-unix unix env MTLD3D_PERF=1 CARGO_TARGET_DIR="$TGT/perf-unix" cargo clippy --all-targets "${DENY[@]}"

# test-unit (cargo test stands in for nextest, doctests excluded as nextest excludes them)
leg test-unit-windows windows env CARGO_TARGET_DIR="$TGT/windows" cargo test -p mtld3d-core -p mtld3d-types --features mtld3d-core/disk-cache --target "$H" --lib --bins --tests --no-fail-fast
leg test-unit-unix unix env CARGO_TARGET_DIR="$TGT/unix" cargo test --lib --bins --tests --no-fail-fast

# test-unit-perf
leg test-unit-perf-windows windows env MTLD3D_PERF=1 CARGO_TARGET_DIR="$TGT/perf-windows" cargo test -p mtld3d-core -p mtld3d-types --features mtld3d-core/disk-cache --target "$H" --lib --bins --tests --no-fail-fast
leg test-unit-perf-unix unix env MTLD3D_PERF=1 CARGO_TARGET_DIR="$TGT/perf-unix" cargo test --lib --bins --tests --no-fail-fast

# audit and the Makefile's own regressions
leg audit . ./scripts/audit.sh
leg test-isolation . python3 scripts/test-isolation.py
leg test-e2e-discovery . python3 scripts/test-e2e-discovery.py

# doc (unix half; the windows half documents for a PE target)
leg doc-unix unix env CARGO_TARGET_DIR="$TGT/unix" cargo doc --no-deps "${DENY[@]}"
leg doc-core-host windows env CARGO_TARGET_DIR="$TGT/windows" cargo doc --no-deps -p mtld3d-core --features mtld3d-core/disk-cache --target "$H" "${DENY[@]}"

# probes: can the PE-only crates be type-checked here at all?
leg probe-pe-target windows env CARGO_TARGET_DIR="$TGT/windows" cargo check -p d3d9 --target i686-pc-windows-msvc
leg probe-d3d9-host windows env CARGO_TARGET_DIR="$TGT/windows" cargo check -p d3d9 --target "$H"
leg probe-d3d8-host windows env CARGO_TARGET_DIR="$TGT/windows" cargo check -p mtld3d-d3d8 --target "$H"
leg probe-tests-host windows env CARGO_TARGET_DIR="$TGT/windows" cargo check -p mtld3d-tests --tests --target "$H"

# test tallies
for f in "$LOGS"/test-unit*.log; do
  awk -v f="$(basename "$f")" '/^test result:/ {p+=$4; fl+=$6; ig+=$8; n++} END {printf "%s: binaries=%d passed=%d failed=%d ignored=%d\n", f, n, p, fl, ig}' \
    FS='[ ;.]+' "$f" >> "$SUM"
done
echo DONE >> "$SUM"
