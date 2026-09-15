#!/usr/bin/env bash
# Runs the shim and checks what it prints, what status it exits with, and what
# it asked the shell and the terminal launcher to do. The only half of the
# plugin that can be tested without a compositor, so it is.
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
  out=$(env PATH="$here/fake-launcher:$PATH" FAKE_LOG="$FAKE_LOG" "${envs[@]}" "$shim" "$@" 2>&1)
  status=$?
}
called() { cat "$FAKE_LOG" 2>/dev/null || true; }   # what reached the fake, one call per line
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); printf 'FAIL %s\n  want: %s\n  got:  %s\n' "$1" "$2" "$3"; fi; }
contains() { case "$3" in *"$2"*) pass=$((pass+1));; *) fail=$((fail+1)); printf 'FAIL %s\n  want substring: %s\n  got: %s\n' "$1" "$2" "$3";; esac; }

# ---- status ---------------------------------------------------------------
run status_up -- status
check "status: the shell is there" "up" "$out"
run status_notool MINI_TERM_SHELL="$tmp/no-such-shell" -- status
check "status: no shell to run with" "notool" "$out"

# ---- run ------------------------------------------------------------------
run out -- run echo hello
check "run: prints what the command printed" "hello" "$out"

run rc -- run 'exit 3'
check "run: exits with the command's status" "3" "$status"

run stderr -- run 'echo out; echo err >&2'
check "run: stderr lands in the same stream" "out
err" "$out"

run cwd WORKDIR="$tmp" -- run pwd
check "run: runs in the configured directory" "$tmp" "$out"

run badcwd WORKDIR="$tmp/missing" -- run pwd
check "run: a directory that is gone is an error, not a run elsewhere" "2" "$status"

run slow TIMEOUT=1 -- run 'sleep 5'
check "run: a command that hangs is cut off" "124" "$status"

run big MAXBYTES=100 -- run 'yes abcdefgh'
check "run: output is bounded" "100" "$(printf '%s' "$out" | wc -c)"

# The shell is injected by path rather than shadowed on PATH, so this asserts
# the exact invocation without the harness losing its own shell.
run shellargs MINI_TERM_SHELL="$here/fake-shell/shell" -- run echo hi
check "run: asks the shell for a login shell and the command" "-lc echo hi" "$(called)"

run noargs -- run
check "run: nothing to run is a usage error" "2" "$status"

# ---- open -----------------------------------------------------------------
run open WORKDIR="$tmp" -- open htop
contains "open: hands the command to a terminal" "cd $tmp; htop" "$(called)"
contains "open: leaves a shell behind afterwards" "exec bash -l" "$(called)"

# ---- usage ----------------------------------------------------------------
run bogus -- bogus
check "unknown verb exits 2" "2" "$status"

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
