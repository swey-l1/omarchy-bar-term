# Mini Terminal: developing it

Contributor notes. Not `CLAUDE.md`: the plugin marketplace refuses a tracked one inside
an installed plugin. For Claude Code, a gitignored one-line `CLAUDE.md` containing
`@DEVELOPING.md` imports this file (a symlink would fail `omarchy plugin validate`).

An Omarchy shell plugin: a bar widget that runs a command and shows what it said. Plugin
id `io.github.swey-l1.mini-term`, kind `bar-widget`. Everything that executes anything is
in the `mini-term` script; the QML only asks it for things.

- `Panel.qml`: the bar widget: the icon, the command history, and the model everything
  reads through `panel`. It *is* a `Theme.qml`, which holds palette and metrics.
- `Pad.qml`: the popup: scrollback, prompt, keys, hint line, and the key catcher.
- `Bindings.qml`: `keyMap`, the single definition of every key binding.
- `Config.qml`: the widget's `shell.json` entry, read and written (`setting`, `persist`).
- `Service.qml`: the process layer: running a command, its output, its result, its states.
- `PadKey.qml`, `Action.qml`, `Field.qml`, `FormButton.qml`, `HintArea.qml`,
  `PadText.qml`: the pieces. Each takes `panel`; theme values and metrics come from it.
- `mini-term`: a plain bash script that runs the command, bounds it and hands it off.
  `test/mini-term.sh` runs it against a fake shell and a fake terminal launcher.
- `manifest.json`: the widget and its settings schema. Values live in the user's
  `~/.config/omarchy/shell.json`, never here.

## Commands

```sh
./mini-term status                        # up | notool
WORKDIR=/tmp ./mini-term run ls           # what the widget does, from a terminal
./test/mini-term.sh                       # 15 cases, no compositor needed
/usr/lib/qt6/bin/qmllint *.qml 2>&1 | grep -E '^Error'
omarchy plugin validate .
omarchy plugin update io.github.swey-l1.mini-term --yes       # pull commits into the install
omarchy restart shell                     # the only dependable way to see an edit
omarchy-shell shell toggle io.github.swey-l1.mini-term        # open the pad without a click
wtype "uptime" && wtype -k Return         # and drive it without a mouse: it is all keyboard
```

The last one is worth knowing: this widget can be verified end to end from a script,
because everything it does is reachable from the keyboard. `wtype -M ctrl -k c -m ctrl`
sends Ctrl+C.

## Only the shim has tests; verify the rest by looking

A QML syntax error removes the widget from the bar with one log line
(`WARN qml: Plugin widget io.github.swey-l1.mini-term failed: …`) and no stack. qmllint
cannot check anything under `KeyboardPanel`, so read `Pad.qml` through by eye after
editing it. Saving into `~/.config/omarchy/plugins/` does not reliably re-render an open
pad; restart the shell.

## What this plugin learned the hard way

- **Stopping means killing a process group.** Quickshell terminates only the process it
  started, so terminating the shim used to leave the command, its shell and its children
  running with nothing able to reach them. The shim runs the command as a background job
  with job control on, which gives it a group of its own, and both the stop path and the
  timeout take that group down. `timeout(1)` cannot do this job: it puts *itself* in a new
  group and survived the kill meant for it, which is why a watchdog does the timing out.
- **The prompt holds the keyboard the whole time the pad is open.** So `keyMap` is nearly
  all modified keys: bind a bare letter and that letter becomes impossible to type into a
  command. Enter, Up, Down and Esc are the exceptions, and they are keys a one-line field
  has no use for.
- **Quoting crosses two layers.** What is typed goes through `bash -c` (Quickshell's
  Process) and then through `"$*"` in the shim to `bash -lc`. `Util.shellQuote` on the
  whole command line is what keeps pipes and quotes intact; test with
  `printf 'a\nb\n'` and a pipeline before believing a change here.
- **Output is bounded in three places** and needs to stay that way: `MAXBYTES` in the shim
  stops a runaway producer, `maxLines` in Service bounds what is held, and the scrollback
  has a fixed height so the pad cannot grow off the screen.

## Hard rules

- Every key binding lives in `keyMap` in `Bindings.qml`, and only there.
- Keys reach a field through `Field`'s `onKey`, never `Keys.on*` on the field.
- Never chain two `bar.run()` calls that depend on order; it is fire-and-forget.
- `bar.shellQuote()` does not exist; use `Util.shellQuote` from `qs.Commons`.
- `bar.showTooltip` does nothing from inside the pad; use the hint line.
- `updateEntryInline` replaces the entry; always merge current settings.
- Never write nerd-font glyphs as `\u` escapes; use the literal character.
- A new key means a new `keyMap` entry, a new row in the README's key table, and a
  retaken shortcuts screenshot: the list in the pad is generated from the table, so those
  three are the same fact written three times and they drift silently.
- Screenshots go in `docs/`, cropped to the pad, and are checked for paths, hostnames and
  addresses before committing.
