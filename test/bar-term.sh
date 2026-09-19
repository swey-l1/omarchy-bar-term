#!/usr/bin/env bash
# Runs the shim against a fake tmux and a fake terminal launcher, and checks
# what it asked them to do. The only half of the plugin that can be tested
# without a compositor, so it is -- and the half worth testing, since every
# session the widget has runs through these eight verbs.
#
#   ./test/bar-term.sh          # exit 0 when every case passes
set -u
here=$(cd "$(dirname "$0")" && pwd)
shim="$here/../bar-term"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0

run() {  # run <name> [VAR=value ...] -- <shim args...>
  name=$1; shift; envs=()
  while [ "$1" != "--" ]; do envs+=("$1"); shift; done; shift
  FAKE_LOG="$tmp/$name.log"; rm -f "$FAKE_LOG"
  out=$(env PATH="$here/fake-launcher:$PATH" FAKE_LOG="$FAKE_LOG" \
            BAR_TERM_TMUX="$here/fake-tmux/tmux" XDG_RUNTIME_DIR="$tmp" \
            "${envs[@]}" "$shim" "$@" 2>&1)
  status=$?
}
called() { cat "$FAKE_LOG" 2>/dev/null || true; }   # what reached the fakes
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); printf 'FAIL %s\n  want: %s\n  got:  %s\n' "$1" "$2" "$3"; fi; }
contains() { case "$3" in *"$2"*) pass=$((pass+1));; *) fail=$((fail+1)); printf 'FAIL %s\n  want substring: %s\n  got: %s\n' "$1" "$2" "$3";; esac; }
absent() { case "$3" in *"$2"*) fail=$((fail+1)); printf 'FAIL %s\n  should not contain: %s\n  got: %s\n' "$1" "$2" "$3";; *) pass=$((pass+1));; esac; }

# ---- is there anything to run sessions with -------------------------------
run status_up -- status
check "status: tmux is there" "up" "$out"
run status_notool BAR_TERM_TMUX="$tmp/no-such-tmux" -- status
check "status: no tmux to make sessions with" "notool" "$out"

# ---- every session on the server, not only ours ---------------------------
run list FAKE_SESSIONS="bar-term-1	bash	0	/home/you
work	vim	1	/home/you/src" -- list
check "list: offers every session, whoever made it" "bar-term-1	/home/you
work	/home/you/src" "$out"

# ---- making a session exist ------------------------------------------------
run ensure_new WORKDIR=/srv -- ensure bar-term-2
check "ensure: hands back the name it was asked for" "bar-term-2" "$out"
contains "ensure: starts it in the configured directory" "-c /srv" "$(called)"
contains "ensure: gives it our rc file, not the user's shell as-is" "session-rc.bash" "$(called)"

run ensure_existing FAKE_SESSIONS="bar-term-2	bash	0	/tmp" -- ensure bar-term-2
absent "ensure: does not build a session that already exists" "new-session" "$(called)"

# ---- sending a command -----------------------------------------------------
run send FAKE_SESSIONS="bar-term-1	bash	0	/tmp" -- send bar-term-1 'git log --oneline | head -3'
contains "send: types the command literally" "send-keys -t bar-term-1 -l -- git log --oneline | head -3" "$(called)"
contains "send: presses Enter separately" "send-keys -t bar-term-1 Enter" "$(called)"

run send_makes FAKE_SESSIONS="" -- send bar-term-3 uptime
contains "send: makes the session first if it is gone" "new-session" "$(called)"

# ---- typing into it, a key at a time ---------------------------------------
# The pad types rather than sending whole lines, so the shell's own completion
# and line editing do the work instead of being imitated.
run type FAKE_SESSIONS=$'bar-term-1\tbash\t0\t/tmp' -- type bar-term-1 'ls ~/sr'
contains "type: sends the text literally, with no Enter" "send-keys -t bar-term-1 -l -- ls ~/sr" "$(called)"
absent "type: does not press Enter" "send-keys -t bar-term-1 Enter" "$(called)"

run key FAKE_SESSIONS=$'bar-term-1\tbash\t0\t/tmp' -- key bar-term-1 Tab
contains "key: presses a named key" "send-keys -t bar-term-1 -- Tab" "$(called)"

run keys FAKE_SESSIONS=$'bar-term-1\tbash\t0\t/tmp' -- key bar-term-1 C-u Enter
contains "key: several at once, in order" "send-keys -t bar-term-1 -- C-u Enter" "$(called)"

run typenone -- type bar-term-1
check "type with nothing to type is an error" "2" "$status"

# ---- reading the screen ----------------------------------------------------
run capture FAKE_SESSIONS="bar-term-1	bash	0	/tmp" FAKE_CAPTURE="one
two


" -- capture bar-term-1 50
check "capture: drops the blank rows that are just pane height" "one
two" "$out"
contains "capture: reaches back through the scrollback" "-S -50" "$(called)"

# ---- where the status files live -------------------------------------------
# They must sit in a directory only this user can write, and the hook must not
# write through anything it did not create.
mkdir -p "$tmp/home"
rc_hook() { HOME="$tmp/home" BAR_TERM_RC_FILE="$1" bash -c '. "$0"; false; __bar_term_status' \
             "$here/../session-rc.bash" 2>/dev/null; }

rc_hook "$tmp/plain.rc"
check "the hook records the status" "1" "$(cat "$tmp/plain.rc" 2>/dev/null)"
check "and leaves nothing beside it" "0" "$(ls "$tmp"/plain.rc.* 2>/dev/null | wc -l)"

mkdir -m 700 -p "$tmp/rt"
run statedir XDG_RUNTIME_DIR="$tmp/rt" -- ensure bar-term-9
contains "a session is given a status file" "BAR_TERM_RC_FILE=" "$(called)"
check "under a directory private to this user" "700" "$(stat -c '%a' "$tmp/rt/bar-term" 2>/dev/null)"

run statenone XDG_RUNTIME_DIR="$tmp/missing" TMPDIR=/dev/null -- ensure bar-term-9
absent "no usable directory means no status file" "BAR_TERM_RC_FILE=" "$(called)"
contains "and the session is made anyway" "new-session" "$(called)"

# ---- the wheel, when a program owns the screen ------------------------------
# A full-screen program draws on the alternate screen, which tmux keeps no
# history for: the pad has nothing to scroll and the wheel belongs to the
# program. Only if it asked for one, or the escape sequence is typed as text.
run wheel FAKE_SESSIONS=$'bar-term-1\tclaude\t1\t/tmp' FAKE_MOUSE=1 -- wheel bar-term-1 up
contains "wheel: sends a wheel-up to a program that takes a mouse" "send-keys -t bar-term-1 -l --" "$(called)"

run wheelnone FAKE_SESSIONS=$'bar-term-1\tbash\t0\t/tmp' FAKE_MOUSE=0 -- wheel bar-term-1 up
absent "wheel: sends nothing to a shell, which has no use for it" "send-keys -t bar-term-1 -l --" "$(called)"

run wheelbad FAKE_SESSIONS=$'bar-term-1\tbash\t0\t/tmp' -- wheel bar-term-1 sideways
check "wheel: only up or down" "2" "$status"

# ---- sizing it to the pad --------------------------------------------------
run size FAKE_SESSIONS=$'bar-term-1\tbash\t0\t/tmp' -- size bar-term-1 75 19
contains "size: makes the session the pad's size" "resize-window -t bar-term-1 -x 75 -y 19" "$(called)"

run sizebad FAKE_SESSIONS=$'bar-term-1\tbash\t0\t/tmp' -- size bar-term-1 75
check "size without both numbers is an error" "2" "$status"

# Attaching hands sizing back, or the terminal inherits a window narrower than
# it is and sits in a box.
run attachsize FAKE_SESSIONS=$'bar-term-1\tbash\t0\t/tmp' -- attach bar-term-1
contains "attach: gives sizing back to whatever attaches" "set-window-option -t bar-term-1 window-size latest" "$(called)"

# ---- what every tab is doing, in one call ----------------------------------
mkdir -p "$tmp/bar-term" && printf '3' > "$tmp/bar-term/bar-term-1.rc"
run states FAKE_SESSIONS="bar-term-1	bash	0	/home/you/src
work	sleep	0	/etc" -- states bar-term-1 work missing
check "states: in the order asked, with exit, mouse mode and place" "1 idle 3 0 /home/you/src
2 running - 0 /etc
3 gone - 0 -" "$out"
check "states: one tmux call for every tab, not one each" "1" "$(grep -c list-sessions "$FAKE_LOG")"

# The tab strip is labelled from this, and a session outlives the widget, so a
# path with a space in it has to survive being the last field of the line.
rm -f "$tmp/bar-term/bar-term-1.rc"   # a session that has not finished anything yet
run states_spaces FAKE_SESSIONS="my work	bash	0	/home/you/My Projects" -- states "my work"
check "states: a name and a path with spaces both survive" "1 idle - 0 /home/you/My Projects" "$out"

# ---- the rest of the verbs -------------------------------------------------
run interrupt FAKE_SESSIONS="bar-term-1	bash	0	/tmp" -- interrupt bar-term-1
contains "interrupt: sends Ctrl+C into the session" "send-keys -t bar-term-1 C-c" "$(called)"

run reset FAKE_SESSIONS="bar-term-1	bash	0	/tmp" -- reset bar-term-1
contains "reset: empties the scrollback" "clear-history -t bar-term-1" "$(called)"
contains "reset: and redraws an empty screen" "-l -- clear" "$(called)"

printf '9' > "$tmp/bar-term/bar-term-1.rc"
run restart FAKE_SESSIONS="bar-term-1	bash	0	/tmp" -- restart bar-term-1
contains "restart: kills the old session" "kill-session -t =bar-term-1" "$(called)"
contains "restart: and builds a new one" "new-session" "$(called)"
check "restart: forgets the old session's last exit" "" "$(cat "$tmp/bar-term/bar-term-1.rc" 2>/dev/null)"

run attach FAKE_SESSIONS="bar-term-1	bash	0	/tmp" -- attach bar-term-1
contains "attach: opens a terminal on the same session, not a new shell" "attach -t =bar-term-1" "$(called)"

# ---- refusing nonsense -----------------------------------------------------
run noname -- send
check "a missing session name is an error" "2" "$status"
run nocmd -- send bar-term-1
check "a send with nothing to send is an error" "2" "$status"
run bogus -- bogus
check "unknown verb exits 2" "2" "$status"

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
