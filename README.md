# Bar Terminal

A terminal session in the Omarchy bar. Click the icon, type a command, read what it said,
and carry on with whatever you were doing. Each tab is a real shell that stays where you
left it, and any of them can be opened in a terminal window without losing its place.

<p align="center">
  <img src="docs/pad.png" alt="The pad: a session's screen, its result line, and the tab strip along the foot" width="420">
</p>

It is for the commands that are not worth opening a window for: a `git log`, a `df -h`, a
`systemctl status`, the thing you want to check without losing the window you are in. The
icon tells you how the last one went from across the screen.

Behind each tab is a tmux session, so it behaves like the terminal it is: `cd` sticks, the
environment stays, and the session outlives the widget. Restart the shell, or log back in
tomorrow, and your tabs are where you left them.

## Requirements

- Omarchy with the Quickshell-based shell (`omarchy-shell`)
- `tmux`, which is what each tab actually is
- `omarchy-launch-terminal`, for opening a session in a terminal window

## Install

```bash
omarchy plugin add https://github.com/swey-l1/omarchy-bar-term --enable
omarchy restart shell
```

To remove it:

```bash
omarchy plugin remove io.github.swey-l1.bar-term
```

The plugin writes only its own entry in `shell.json`, and only when you change a setting.

## Use

Click the icon in the bar, or bind the toggle to a key:

```bash
omarchy-shell shell toggle io.github.swey-l1.bar-term
```

The prompt has the keyboard as soon as the pad opens, so you can type straight away.

| Key | What it does |
|---|---|
| `Enter` | Run the command |
| `Up` | Previous command |
| `Down` | Next command |
| `Ctrl+C` | Interrupt the session |
| `Ctrl+L` | Clear the screen |
| `Ctrl+T` | Attach it to a terminal |
| `Ctrl+K` | Restart this session |
| `Tab` | Next tab |
| `Alt+1` … `Alt+4` | Jump to a tab |
| `Esc` | Close |

Everything else you press is typing, which is why the list above is mostly modified keys.

<p align="center">
  <img src="docs/shortcuts.png" alt="The pad with every keyboard shortcut listed" width="420">
</p>

**Ctrl+T** opens a terminal window *attached to the session you are looking at*, not a new
shell: the window comes up showing exactly what the pad was showing, half-finished command
and all. The pad closes as it goes, because it covers the screen and the new window would
otherwise open behind it. Closing that window detaches; the session, and everything
running in it, carries on.

That is the way out of the pad's limits. The pad is a one-line prompt and a text view, so
a full-screen program (`vim`, `htop`, a pager) is worth attaching for; anything that needs
a password or asks a question can be answered either place.

## Tabs

The strip along the foot is one tmux session per tab, named `bar-term-1` upwards, each
with its own directory, environment, history and half-typed line. A tab is labelled with
the last command word it ran, shows a pulsing dot while something is running in it, and
turns the urgent colour if that something failed while you were looking elsewhere.

`Ctrl+K` throws a session away and starts it again, for when one has been left in a state
you would rather not untangle.

The bar icon watches all of them: it pulses while *any* tab is running, which is the one
thing the bar can tell you that the pad cannot.

## What the icon says

| Icon | Meaning |
|---|---|
| Normal | Nothing running, and the last command worked |
| Pulsing, accent colour | A command is running now |
| Urgent colour | The last command exited non-zero, or there is no shell to run commands with |

A command you stopped yourself does not count as a failure.

## Limits worth knowing

The pad reads the session's screen a few times a second and draws it as plain text, so it
is a good window onto a shell and a poor one onto a full-screen program: colours, cursor
positioning and anything that redraws itself will look flat or half-finished. Attach with
`Ctrl+T` for those.

It is also a one-line prompt. Multi-line editing, and keys that belong to the shell rather
than to the pad, happen in the attached terminal.

<p align="center">
  <img src="docs/running.png" alt="A command running in tab 3: the result line says so and the tab keeps a dot" width="420">
</p>

Neither is a limit on what you can run: the session is a real shell, and `Ctrl+T` is
always one key away.

## Settings

Set these in `~/.config/omarchy/shell.json`, under this widget's entry in the bar layout.

| Key | Default | What |
|---|---|---|
| `workdir` | your home directory | Where a new session starts; after that the session decides |
| `maxLines` | `200` | How far back into the session's scrollback the pad reads |
| `tabs` | `4` | How many sessions the strip holds (1-6) |

```json
{ "id": "io.github.swey-l1.bar-term", "workdir": "/home/you/src", "tabs": 3 }
```

## How it works

The QML never runs anything itself. `bar-term`, a plain bash script, owns every
conversation with tmux: making a session, typing into it, reading its screen back,
interrupting it, and attaching a terminal to it. The widget shells out to that script and
polls. It is also the only part with tests (`./test/bar-term.sh`, 23 cases against a fake
tmux), because it is the only part that can be tested without a compositor.

Each session runs `bash` with an rc file that sources your own `~/.bashrc` and adds one
thing: a `PROMPT_COMMAND` entry that writes the last exit status to a file. That is how
the pad knows a command failed without printing anything you would see, in the pad or in
an attached terminal.

## Developing

See [DEVELOPING.md](DEVELOPING.md).

## Licence

MIT.
