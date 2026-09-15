# Mini Terminal

Run a command from the bar and read its output without leaving what you are doing.

An Omarchy bar widget. Click the icon for the pad; with the pad open, `R` refreshes,
`Enter` runs, `Esc` closes.

## Requirements

- Omarchy with the Quickshell-based shell (`omarchy-shell`)
- `omarchy-launch-terminal`

## Install

```bash
omarchy plugin add <git url of this repo> --enable
```

To remove it:

```bash
omarchy plugin remove io.github.swey-l1.mini-term
```

The plugin writes only its own entry in `shell.json`, and only when you act in the pad.

## Settings

| Key | Default | What |
|---|---|---|
| `target` | — | What `omarchy-launch-terminal` is pointed at |
| `pollSec` | `60` | Seconds between reachability checks |

## Licence

MIT. See [LICENSE](LICENSE).
