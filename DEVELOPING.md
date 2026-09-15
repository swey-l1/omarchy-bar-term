# Mini Terminal: developing it

Contributor notes. Not `CLAUDE.md`: the plugin marketplace refuses a tracked one inside
an installed plugin. For Claude Code, a gitignored one-line `CLAUDE.md` containing `@DEVELOPING.md` imports this
file (a symlink would fail `omarchy plugin validate`).

An Omarchy shell plugin: a bar widget that shells out to `omarchy-launch-terminal` through the
`mini-term` script. Plugin id `io.github.swey-l1.mini-term`, kind `bar-widget`.

- `Panel.qml`: the bar widget: the icon, and the model everything reads through
  `panel`. It *is* a `Theme.qml`, which holds palette and metrics.
- `Pad.qml`: the popup: key grid, hint line, and the key catcher that owns focus.
- `Bindings.qml`: `keyMap`, the single definition of every key binding.
- `Config.qml`: the widget's `shell.json` entry, read and written (`setting`, `persist`).
- `Service.qml`: everything that runs `mini-term`: the probe, its states and wording.
- `PadKey.qml`, `Action.qml`, `Field.qml`, `FormButton.qml`, `HintArea.qml`,
  `PadText.qml`: the pieces. Each takes `panel`; theme values and metrics come from it.
- `mini-term`: a plain bash script that owns every `omarchy-launch-terminal` call. `test/mini-term.sh`
  runs it against `test/fake-omarchy-launch-terminal/omarchy-launch-terminal`.
- `manifest.json`: the widget and its settings schema. Values live in the user's
  `~/.config/omarchy/shell.json`, never here.

## Commands

```sh
TARGET=<something> ./mini-term status     # up | down | notool
./test/mini-term.sh                       # the shim against a fake omarchy-launch-terminal
/usr/lib/qt6/bin/qmllint *.qml 2>&1 | grep -E '^Error'
omarchy plugin validate .
omarchy plugin update io.github.swey-l1.mini-term --yes       # pull commits into the installed checkout
omarchy restart shell                    # the only dependable way to see an edit
omarchy-shell shell toggle io.github.swey-l1.mini-term        # open the pad without a click
```

## Only the shim has tests; verify the rest by looking

A QML syntax error removes the widget from the bar with one log line
(`WARN qml: Plugin widget io.github.swey-l1.mini-term failed: …`) and no stack. qmllint cannot check
anything under `KeyboardPanel`, so read `Pad.qml` through by eye after editing it.
Saving into `~/.config/omarchy/plugins/` does not reliably re-render an open pad.

## Hard rules

- Every key binding lives in `keyMap` in `Bindings.qml`, and only there.
- Keys reach a field through `Field`'s `onKey`, never `Keys.on*` on the field.
- Never chain two `bar.run()` calls that depend on order; it is fire-and-forget.
- `bar.shellQuote()` does not exist; use `Util.shellQuote` from `qs.Commons`.
- `bar.showTooltip` does nothing from inside the pad; use the hint line.
- `updateEntryInline` replaces the entry; always merge current settings.
- Never write nerd-font glyphs as `\u` escapes; use the literal character.
- Never put a real address or hostname in `manifest.json` or any tracked file.
