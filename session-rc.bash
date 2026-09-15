# Sourced by the bash running in each Bar Terminal tmux session, instead of
# ~/.bashrc directly, so the widget can know how the last command went.
#
# The session is a real interactive shell and the user may attach to it in a
# terminal at any time, so this must not change what they see: no prompt of our
# own, no output, nothing in the scrollback. It writes one number to one file.

[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"

__bar_term_status() {
  # First in PROMPT_COMMAND, so $? is still the command's own status.
  printf '%s' "$?" > "$BAR_TERM_RC_FILE" 2>/dev/null
}

case "$PROMPT_COMMAND" in
  *__bar_term_status*) ;;
  "") PROMPT_COMMAND="__bar_term_status" ;;
  *)  PROMPT_COMMAND="__bar_term_status; $PROMPT_COMMAND" ;;
esac
