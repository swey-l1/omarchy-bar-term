# Sourced by the bash running in each Bar Terminal tmux session, instead of
# ~/.bashrc directly, so the widget can know how the last command went.
#
# The session is a real interactive shell and the user may attach to it in a
# terminal at any time, so this must not change what they see: no prompt of our
# own, no output, nothing in the scrollback. It writes one number to one file.

[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"

__bar_term_status() {
  # First in PROMPT_COMMAND, so $? is still the command's own status.
  local rc=$?
  [ -n "${BAR_TERM_RC_FILE:-}" ] || return

  # Never write through a link. The directory this lives in is checked by the
  # shim to be one only this user can write, and this is the second lock on the
  # same door: a redirection follows a symlink and truncates whatever is at the
  # end of it, which would make this shell overwrite its own user's files on
  # every prompt.
  [ -L "$BAR_TERM_RC_FILE" ] && return

  # Written beside it and moved into place, so a reader never sees the file
  # half-written and nothing is truncated in the meantime.
  local tmp="$BAR_TERM_RC_FILE.$$"
  if printf '%s' "$rc" > "$tmp" 2>/dev/null; then
    mv -f "$tmp" "$BAR_TERM_RC_FILE" 2>/dev/null || rm -f "$tmp" 2>/dev/null
  fi
}

case "$PROMPT_COMMAND" in
  *__bar_term_status*) ;;
  "") PROMPT_COMMAND="__bar_term_status" ;;
  *)  PROMPT_COMMAND="__bar_term_status; $PROMPT_COMMAND" ;;
esac
