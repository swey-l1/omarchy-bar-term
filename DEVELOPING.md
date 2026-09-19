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
- `SessionPicker.qml`: choosing which tmux session a tab shows. Covers the scrollback
  while open and sees keys before the key table does.
- `Bindings.qml`: `keyMap`, the single definition of every key binding.
- `Config.qml`: the widget's `shell.json` entry, read and written (`setting`, `persist`).
- `Service.qml`: the process layer. Owns one `Session` per tab, every call to the shim,
  and the two pollers.
- `Session.qml`: one tab's data -- its screen, state, last exit, history and half-typed
  line. Nothing here shells out.
- `PadKey.qml`, `Action.qml`, `FormButton.qml`, `HintArea.qml`, `TabButton.qml`,
  `PadText.qml`: the pieces. Each takes `panel`; theme values and metrics come from it.
- `bar-term`: a plain bash script that owns every conversation with tmux.
  `test/bar-term.sh` runs it against a fake tmux and a fake terminal launcher.
- `manifest.json`: the widget and its settings schema. Values live in the user's
  `~/.config/omarchy/shell.json`, never here.

The README's artwork lives in `assets/readme/`. It is generated, not hand-written; the
generator and the rules behind the page are in the `omarchy-plugin-dev` skill, not here.

## Commands

```sh
./bar-term status                        # up | notool (is tmux installed)
./bar-term list                          # every session on the server
./bar-term send bar-term-1 'ls -la'      # what the widget does, from a terminal
./bar-term capture bar-term-1 40         # what the pad would be showing
./bar-term states bar-term-1 notes       # a line per name, in the order asked
tmux attach -t bar-term-1                # the session itself, no widget involved
tmux switch-client -t bar-term-1         # the same, from inside another tmux session
./test/bar-term.sh                       # 36 cases against a fake tmux
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

- **The sessions are the product; the widget is a view onto them.** A tab shows the tmux
  session named in `session<n>`, defaulting to `bar-term-<n>` -- it can be any session on
  the server, including one the user made in a terminal. Every shim verb takes a *name* for
  that reason. A borrowed session gets no exit status (no rc file) and must never be
  treated as disposable. They outlive the shell, the widget and this process, which is
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
- **The status files live somewhere only this user can write, and that is checked.** They
  are truncated by each session's shell on every prompt, so a directory another local user
  can pre-create is a way to make that shell overwrite its own user's files: leave a
  symlink named after a session and every prompt writes through it. `state_dir` refuses a
  symlink, refuses a directory it does not own, forces 0700, and falls back to a per-uid
  path rather than a shared one. When none of that can be satisfied the widget runs with
  no exit statuses rather than writing somewhere unsafe, and `session-rc.bash` writes
  beside the file and moves it into place rather than redirecting through whatever is
  there.
- **Exit status comes from the session's own shell.** `session-rc.bash` sources the user's
  `~/.bashrc` and prepends one entry to `PROMPT_COMMAND` that writes `$?` to a file under
  `$XDG_RUNTIME_DIR/bar-term/`, named after the session. It must stay invisible: the user can be attached to that
  session in a terminal, and anything it printed would be theirs to look at.
- **The keyboard divides on one rule: Alt is the pad's, everything else is the shell's.**
  Keys the pad does not claim are typed into the session, which is what makes completion,
  readline and bash's own history work instead of being imitated. Binding anything outside
  Alt takes a key away from the shell, and the shell has a use for nearly all of them.
- **Keystrokes are queued through one Process, never fire-and-forget.** Two detached calls
  can land in either order, and a shell that receives "l" then "s" when you typed "ls" is
  worse than a slow one. Consecutive characters coalesce into a single `type`.
- **A full-screen program leaves no scrollback.** It draws on the alternate screen, which
  tmux keeps no history for, so the pad has one screenful and scrolling it does nothing --
  which reads as a bug and is not one. The wheel is sent to the program instead when
  `mouse_any_flag` says it asked for a mouse; a shell session scrolls the pad as before.
  The escape sequence must never reach a shell, which would type it as text.
- **The session is sized to the pad, and the pad measures itself.** A session wider than
  the pad wraps every full-width line into a ragged remnant underneath it, which is what a
  TUI's boxes and rules turn into: running anything full-screen in here was unreadable
  until `size` existed. `attach` hands sizing back to the terminal that attaches, and the
  pad takes it again next time it looks.
- **A binding that calls a method never re-evaluates.** `padCols` used
  `FontMetrics.advanceWidth("M")` and kept answering for the font it had before the family
  resolved, sizing every session to 30 columns. Use a *property* -- `averageCharacterWidth`
  -- and the binding updates. The same trap as `Instantiator.objectAt()` below.
- **A Timer cannot be a direct child of the pad's root.** `KeyboardPanel`'s default
  property is a list of items, so it fails to load with "Cannot assign object of type
  QQmlTimer to list property contentItem" and the widget vanishes from the bar. Put
  non-visual children inside an Item.
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
- A session name may contain spaces, so `list` and `states` are tab-separated and every
  name reaching the shim is `Util.shellQuote`d. `grep` does not read `\t` as a tab; build
  one with `printf` (the test fake got this wrong and matched nothing).
- Anything printed into a session is something the user may be sitting in front of. Keep
  the widget's bookkeeping out of the pane.
- A new key means a new `keyMap` entry, a new row in the README's key table, and retaken
  README artwork: the list in the pad is generated from the table, so those are the same
  fact written more than once and they drift silently.
- Screenshots go in `docs/`, cropped to the pad, and are checked for paths, hostnames and
  addresses before committing.
