#!/bin/zsh
# clang-tidy (analyzer + bugprone) over a compile database (development/adr/0015).
# usage: tidy.sh BUILD_DIR FILE...      e.g. tidy.sh $HUB_ROOT/build/dxmt/x64 ~/Developer/dxmt/src/dxmt/*.cpp
# DXMT: copy toolchains/dxmt-cross/ to /tmp/dxmt-cross/ first. x87sidecar: BUILD_DIR is its build/ (cmake).
# Prints unique warnings with the in-tree path, then a count per check.
set -eu
B=${1:?build dir with compile_commands.json}; shift
LLVM=/opt/homebrew/opt/llvm/bin
C='-*,clang-analyzer-*,-clang-analyzer-optin.core.EnumCastOutOfRange,-clang-analyzer-optin.performance.Padding,-clang-analyzer-security.insecureAPI.DeprecatedOrUnsafeBufferHandling,bugprone-*,-bugprone-easily-swappable-parameters,-bugprone-narrowing-conversions,-bugprone-implicit-widening-of-multiplication-result,-bugprone-reserved-identifier,-bugprone-macro-parentheses,-bugprone-signed-bitwise,-bugprone-branch-clone,-bugprone-assignment-in-if-condition,-bugprone-switch-missing-default-case,-bugprone-multi-level-implicit-pointer-conversion,-bugprone-casting-through-void,-bugprone-exception-escape,-bugprone-derived-method-shadowing-base-method,-bugprone-crtp-constructor-accessibility,-bugprone-argument-comment'
out=$(mktemp)
$LLVM/run-clang-tidy -clang-tidy-binary $LLVM/clang-tidy -p "$B" -j "$(sysctl -n hw.ncpu)" -quiet -checks="$C" "$@" > "$out" 2>&1 || true
grep -E '^\S+:[0-9]+:[0-9]+: (warning|error)' "$out" | sed -E 's|^(\.\./)+|/|' | sort -u | tee "$out.u"
echo; sed -E 's/.*\[(.*)\]$/\1/' "$out.u" | sort | uniq -c | sort -rn
rm -f "$out" "$out.u"
