# Bar Terminal: developing it

Contributor notes. Not `CLAUDE.md`: the plugin marketplace refuses a tracked one inside
an installed plugin. For Claude Code, a gitignored one-line `CLAUDE.md` containing
`@DEVELOPING.md` imports this file (a symlink would fail `omarchy plugin validate`).

An Omarchy shell plugin: a bar widget whose tabs are tmux sessions. Plugin id
`io.github.swey-l1.bar-term`, kind `bar-widget`. Everything that talks to tmux is in the
`bar-term` script; the QML types into sessions and reads their screens back through it.

- `Panel.qml`: the bar widget: the icon, the sessions and which tab is active, and the
  model everything reads through `panel`. It *is* a `Theme.qml`, which holds palette and
  metrics.
- `Pad.qml`: the popup: scrollback, prompt, keys, tab strip, hint line, key catcher.
- `TabButton.qml`: one tab in that strip, and the three things it has to show.
- `Bindings.qml`: `keyMap`, the single definition of every key binding.
- `Config.qml`: the widget's `shell.json` entry, read and written (`setting`, `persist`).
- `Service.qml`: the process layer. Owns one `Session` per tab, every call to the shim,
  and the two pollers.
- `Session.qml`: one tab's data -- its screen, state, last exit, history and half-typed
  line. Nothing here shells out.
- `PadKey.qml`, `Action.qml`, `Field.qml`, `FormButton.qml`, `HintArea.qml`,
  `PadText.qml`: the pieces. Each takes `panel`; theme values and metrics come from it.
- `bar-term`: a plain bash script that runs the command, bounds it and hands it off.
  `test/bar-term.sh` runs it against a fake shell and a fake terminal launcher.
- `manifest.json`: the widget and its settings schema. Values live in the user's
  `~/.config/omarchy/shell.json`, never here.

## Commands

```sh
./bar-term status                        # up | notool (is tmux installed)
./bar-term send 1 'ls -la'               # what the widget does, from a terminal
./bar-term capture 1 40                  # what the pad would be showing
./bar-term states 4                      # one line per tab: idle | running | gone
tmux attach -t bar-term-1                # the session itself, no widget involved
./test/bar-term.sh                       # 23 cases against a fake tmux
/usr/lib/qt6/bin/qmllint *.qml 2>&1 | grep -E '^Error'
omarchy plugin validate .
omarchy plugin update io.github.swey-l1.bar-term --yes       # pull commits into the install
omarchy restart shell                     # the only dependable way to see an edit
omarchy-shell shell toggle io.github.swey-l1.bar-term        # open the pad without a click
wtype "uptime" && wtype -k Return         # and drive it without a mouse: it is all keyboard
```

The last one is worth knowing: this widget can be verified end to end from a script,
because everything it does is reachable from the keyboard. `wtype -M ctrl -k c -m ctrl`
sends Ctrl+C.

## Only the shim has tests; verify the rest by looking

A QML syntax error removes the widget from the bar with one log line
(`WARN qml: Plugin widget io.github.swey-l1.bar-term failed: …`) and no stack. qmllint
cannot check anything under `KeyboardPanel`, so read `Pad.qml` through by eye after
editing it. Saving into `~/.config/omarchy/plugins/` does not reliably re-render an open
pad; restart the shell.

## What this plugin learned the hard way

- **The sessions are the product; the widget is a view onto them.** Each tab is the tmux
  session `bar-term-<n>`. They outlive the shell, the widget and this process, which is
  the point: a restart loses nothing, and `tmux attach -t bar-term-1` in any terminal is
  the same session the pad is showing. Nothing here should ever kill a session the user
  did not ask to lose.
- **A new pane is not a ready shell.** Keys sent before the shell has read anything are
  echoed raw by the pty and then read back as input, which showed up as the first command
  of a session appearing twice. `#{pane_current_command}` is no help -- it says `bash`
  from the moment the pane exists -- so `ensure` waits for the prompt to be drawn, by
  capturing until the pane is not blank.
- **Poll for every tab at once.** `states` answers for all of them in one tmux call, and
  only the visible tab has its screen captured. This runs on a timer all day; four
  processes a tick to draw four dots is not a price worth paying.
- **Exit status comes from the session's own shell.** `session-rc.bash` sources the user's
  `~/.bashrc` and prepends one entry to `PROMPT_COMMAND` that writes `$?` to a file under
  `$XDG_RUNTIME_DIR/bar-term/`. It must stay invisible: the user can be attached to that
  session in a terminal, and anything it printed would be theirs to look at.
- **The prompt holds the keyboard the whole time the pad is open.** So `keyMap` is nearly
  all modified keys: bind a bare letter and that letter becomes impossible to type into a
  command. Enter, Up, Down and Esc are the exceptions, and they are keys a one-line field
  has no use for.
- **Quoting crosses two layers.** What is typed goes through `bash -c` (Quickshell's
  Process) and then through `"$*"` in the shim into `tmux send-keys -l`, which types it
  literally. `Util.shellQuote` on the whole command line is what keeps pipes and quotes
  intact; test with a pipeline and an embedded quote before believing a change here.
- **The pad's layer surface covers the screen.** Anything the widget opens -- a terminal,
  a window, a dialog -- appears *behind* it, so the pad has to close on the way out or the
  action looks like it did nothing. That is what "open in terminal does not work" turned
  out to be: it worked every time, invisibly.
- **A tab is a session, or it is decoration.** Screen, history and draft belong to
  `Session`, one instance per tab. The list of them is maintained in
  `onObjectAdded`/`onObjectRemoved` rather than read back with `Instantiator.objectAt()`,
  which is a plain function: a binding on it would not re-evaluate when the active tab
  changed.
- **Output is bounded by what is read, not by what is produced.** tmux keeps the
  scrollback; the pad asks for the last `maxLines` of it and draws that in a view of fixed
  height. A command that floods the session is the session's business, exactly as it would
  be in a terminal.

## Hard rules

- Every key binding lives in `keyMap` in `Bindings.qml`, and only there.
- Keys reach a field through `Field`'s `onKey`, never `Keys.on*` on the field.
- Never chain two `bar.run()` calls that depend on order; it is fire-and-forget.
- `bar.shellQuote()` does not exist; use `Util.shellQuote` from `qs.Commons`.
- `bar.showTooltip` does nothing from inside the pad; use the hint line.
- `updateEntryInline` replaces the entry; always merge current settings.
- Never write nerd-font glyphs as `\u` escapes; use the literal character.
- `-t =name` is an exact-match *session* target. Pane targets (`send-keys`, `capture-pane`,
  `clear-history`) take the plain name; with `=` they fail with "can't find pane".
- Anything printed into a session is something the user may be sitting in front of. Keep
  the widget's bookkeeping out of the pane.
- A new key means a new `keyMap` entry, a new row in the README's key table, and a
  retaken shortcuts screenshot: the list in the pad is generated from the table, so those
  three are the same fact written three times and they drift silently.
- Screenshots go in `docs/`, cropped to the pad, and are checked for paths, hostnames and
  addresses before committing.
