#!/usr/bin/env bash
# Runs the shim against a fake omarchy-launch-terminal (test/fake-omarchy-launch-terminal) and checks what it
# prints and what it asked the tool to do. The only half of the plugin that can
# be tested without a compositor, so it is.
#
#   ./test/mini-term.sh          # exit 0 when every case passes
set -u
here=$(cd "$(dirname "$0")" && pwd)
shim="$here/../mini-term"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0

run() {  # run <name> [VAR=value ...] -- <shim args...>
  name=$1; shift; envs=()
  while [ "$1" != "--" ]; do envs+=("$1"); shift; done; shift
  FAKE_LOG="$tmp/$name.log"; rm -f "$FAKE_LOG"
  out=$(env PATH="$here/fake-omarchy-launch-terminal:$PATH" FAKE_LOG="$FAKE_LOG" "${envs[@]}" "$shim" "$@" 2>"$tmp/err")
  status=$?
}
called() { cat "$FAKE_LOG" 2>/dev/null || true; }   # what reached the tool, one call per line
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); printf 'FAIL %s\n  want: %s\n  got:  %s\n' "$1" "$2" "$3"; fi; }

mkdir -p "$tmp/nobin" && ln -s "$(command -v bash)" "$tmp/nobin/bash"
run notool PATH="$tmp/nobin" -- status;        check "status with no tool" "notool" "$out"
run up -- status;                               check "status: tool answers" "up" "$out"
# When reachable() means something, add: run down FAKE_FAIL=1 -- status; check "status: tool fails" "down" "$out"
run run TARGET=example -- run --flag value;     check "run passes args through" "--flag value" "$(called)"
run usage -- bogus;                             check "unknown verb exits 2" "2" "$status"

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
