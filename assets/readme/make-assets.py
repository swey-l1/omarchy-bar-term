#!/usr/bin/env python3
"""Draw the README's SVGs.

The page is a designed one: every heading is a banner, every table and code block
has a picture above it. Keeping that in a script rather than in twenty hand-edited
files means a wording change is a line here, and the palette is stated once.

    python3 assets/readme/make-assets.py

The palette is the plugin's own: these are the colours its screenshots are full
of, read from the theme they were taken under (Tokyo Night). Nothing here invents
a colour. Change the six values and the whole page follows; the screenshots have
to be retaken to match, or the chrome and the proof disagree.
"""
from pathlib import Path

BG     = "#1A1B26"   # the pad's ground
KEY    = "#24283B"   # a key, a field, any raised surface
ACCENT = "#7AA2F7"   # the pad's border, and the blue the theme is known for
TEXT   = "#A9B1D6"   # body text, as the pad draws it
MUTED  = "#565F89"   # hints, captions, anything secondary
TITLE  = "#C0CAF5"   # headings

MONO = "ui-monospace, SFMono-Regular, Menlo, monospace"
SANS = "-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif"

OUT = Path(__file__).parent


def svg(name, w, h, body, title, desc=None):
    labels = 'aria-labelledby="title desc"' if desc else 'aria-labelledby="title"'
    d = f'\n  <desc id="desc">{desc}</desc>' if desc else ""
    (OUT / name).write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
        f'viewBox="0 0 {w} {h}" role="img" {labels}>\n'
        f'  <title id="title">{title}</title>{d}\n{body}\n</svg>\n'
    )
    return name


def text(x, y, s, size=20, fill=TEXT, font=SANS, weight=None, anchor=None,
         spacing=None, preserve=False):
    a = f' font-family="{font}" font-size="{size}" fill="{fill}"'
    if weight:   a += f' font-weight="{weight}"'
    if anchor:   a += f' text-anchor="{anchor}"'
    if spacing:  a += f' letter-spacing="{spacing}"'
    if preserve: a += ' xml:space="preserve"'
    return f'  <text x="{x}" y="{y}"{a}>{s}</text>'


def rect(x, y, w, h, fill, r=0, stroke=None, sw=None):
    s = f' stroke="{stroke}" stroke-width="{sw or 1.5}"' if stroke else ""
    return f'  <rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}"{s}/>'


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


# ---- the drawn pad, used in the hero -------------------------------------

def mini_pad(x, y, scale=1.0):
    """The widget as it really draws: output, a prompt, a key row, a tab strip."""
    g = [f'  <g transform="translate({x} {y}) scale({scale})">']
    g.append(rect(0, 0, 300, 300, BG, r=12, stroke=ACCENT, sw=2))
    g.append(rect(12, 12, 276, 150, KEY, r=8))
    for i, line in enumerate(["$ git log --oneline -2", "c380bcf the session list", "2150760 a picture of it"]):
        g.append(text(24, 36 + i * 22, esc(line), size=13, fill=TEXT if i == 0 else MUTED, font=MONO))
    g.append(text(24, 154, "ok", size=12, fill=ACCENT, font=MONO))
    g.append(rect(12, 168, 276, 30, KEY, r=6, stroke=ACCENT, sw=1))
    g.append(text(24, 188, "command", size=13, fill=MUTED, font=MONO))
    for i in range(6):
        g.append(rect(12 + i * 47, 208, 41, 34, KEY, r=6))
    g.append(text(23, 230, "RUN", size=11, fill=TEXT, font=MONO))
    for i, lbl in enumerate(["1 ~/src", "2 etc", "3 ~", "4"]):
        fill = KEY if i == 0 else BG
        g.append(rect(12 + i * 70, 252, 64, 26, fill, r=6))
        g.append(text(44 + i * 70, 269, lbl, size=11, fill=TEXT if i == 0 else MUTED,
                      font=MONO, anchor="middle"))
    g.append("  </g>")
    return "\n".join(g)


def hero():
    b = [rect(0, 0, 1200, 360, BG, r=26)]
    b.append(text(64, 76, "OMARCHY BAR WIDGET · TMUX", size=18, fill=ACCENT, font=MONO, spacing=2))
    b.append(text(62, 146, "Bar Terminal", size=64, fill=TITLE, weight=700))
    for i, line in enumerate([
        "A terminal session in the bar. Type a command,",
        "read what it said, and carry on with what you",
        "were doing. Each tab is a real shell that stays put.",
    ]):
        b.append(text(64, 196 + i * 32, line, size=24, fill=TEXT))
    b.append(text(64, 312, "QML + bash  ·  tmux sessions  ·  four tabs  ·  attach any of them  ·  MIT",
                  size=18, fill=MUTED, font=MONO))
    b.append(mini_pad(840, 30))
    svg("hero.svg", 1200, 360, "\n".join(b),
        "Bar Terminal, an Omarchy bar widget",
        "A terminal session in the Omarchy bar: tabs backed by tmux sessions, a prompt, "
        "the session's screen, and a key to attach any tab to a terminal window. The right "
        "side shows the pad as it draws: output, prompt, key row and tab strip.")


def how_it_works():
    b = [rect(0, 0, 1200, 200, BG, r=22)]
    b.append(text(30, 36, "HOW A COMMAND REACHES YOUR SHELL", size=18, fill=ACCENT, font=MONO, spacing=2.4))
    boxes = [
        ("the prompt", "you type"),
        ("bar-term send", "one shim call"),
        ("tmux session", "bar-term-1"),
        ("your bash", "runs it"),
        ("the pad", "reads the screen"),
    ]
    x = 30
    for i, (top, bottom) in enumerate(boxes):
        b.append(rect(x, 60, 196, 84, KEY, r=10))
        b.append(text(x + 98, 96, top, size=22, fill=TITLE, weight=700, anchor="middle"))
        b.append(text(x + 98, 124, bottom, size=17, fill=MUTED, anchor="middle", font=MONO))
        if i < len(boxes) - 1:
            ax = x + 202
            b.append(f'  <path d="M{ax} 102 h22 M{ax + 14} 96 l6 6 l-6 6" fill="none" '
                     f'stroke="{ACCENT}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>')
        x += 232
    b.append(text(30, 178, "The session outlives all of it: restart the shell, or attach the same session in a "
                           "terminal, and nothing is lost.", size=17, fill=MUTED))
    svg("how-it-works.svg", 1200, 200, "\n".join(b),
        "How a command reaches your shell",
        "Typing in the pad's prompt makes one bar-term call, which types the command into a tmux "
        "session where your own bash runs it; the pad reads that session's screen back.")


def section(name, number, label, heading, motif_lines):
    b = [rect(0, 0, 1200, 150, BG, r=22)]
    b.append(text(56, 40, f"{number} · {label}", size=18, fill=ACCENT, font=MONO, spacing=2.4))
    b.append(rect(56, 54, 44, 4, ACCENT, r=2))
    b.append(text(56, 110, heading, size=44, fill=TITLE, weight=700))
    # Right-aligned against a 1144 margin rather than left-placed at a guessed x:
    # a motif one word longer than expected used to run off the canvas.
    y = 66
    for line, fill in motif_lines:
        b.append(text(1144, y, esc(line), size=18, fill=fill, font=MONO, anchor="end"))
        y += 32
    svg(f"section-{name}.svg", 1200, 150, "\n".join(b), f"{number} {heading}")


def sub(name, number, heading):
    b = [rect(0, 0, 1200, 84, BG, r=16)]
    b.append(rect(40, 24, 4, 36, ACCENT, r=2))
    b.append(text(60, 34, number, size=16, fill=MUTED, font=MONO, spacing=2))
    b.append(text(60, 66, heading, size=32, fill=TITLE, weight=700))
    svg(f"sub-{name}.svg", 1200, 84, "\n".join(b), f"{number} {heading}")


def code(name, caption, lines, note=None):
    """A terminal card: a title bar, one or more $ lines, an optional note."""
    h = 76 + 32 * len(lines) + (30 if note else 0)
    b = [rect(0, 0, 1200, h, BG, r=18),
         rect(0, 0, 1200, 46, KEY, r=18),
         rect(0, 28, 1200, 18, KEY),
         text(40, 30, f"bash · {caption}", size=16, fill=MUTED, font=MONO)]
    y = 74
    for line in lines:
        b.append(text(40, y, "$", size=18, fill=ACCENT, font=MONO))
        b.append(text(62, y, esc(line), size=18, fill=TITLE, font=MONO, preserve=True))
        y += 32
    if note:
        b.append(text(40, y + 4, note, size=17, fill=MUTED))
    svg(f"code-{name}.svg", 1200, h, "\n".join(b), caption)


# ---- boards: the pictures that sit above a table -------------------------

def keyboard_board():
    """The bound keys on keycaps. The pad's prompt holds the keyboard, so nearly
    every binding is a modified key; the board is the clearest way to say that."""
    rows = [
        [("Esc", 1), ("", 0.4), ("Tab", 1.4), ("", 6.2), ("Alt+1", 1.4), ("Alt+2", 1.4), ("Alt+3", 1.4), ("Alt+4", 1.4)],
        [("Ctrl+C", 1.6), ("Ctrl+K", 1.6), ("Ctrl+L", 1.6), ("Ctrl+P", 1.6), ("Ctrl+T", 1.6)],
        [("Up", 1), ("Down", 1), ("", 0.6), ("Enter", 2)],
    ]
    meaning = {
        "Esc": "close", "Tab": "next tab", "Alt+1": "tab 1", "Alt+2": "tab 2",
        "Alt+3": "tab 3", "Alt+4": "tab 4", "Ctrl+C": "interrupt", "Ctrl+K": "restart",
        "Ctrl+L": "clear", "Ctrl+P": "sessions", "Ctrl+T": "attach",
        "Up": "previous", "Down": "next", "Enter": "run",
    }
    unit, gap, kh = 74, 10, 66
    b = [rect(0, 0, 1200, 330, BG, r=22)]
    b.append(text(40, 44, "THE KEYS THE PAD CLAIMS", size=18, fill=ACCENT, font=MONO, spacing=2.4))
    b.append(text(40, 72, "Everything else you press is typing, which is why almost all of them are modified.",
                  size=17, fill=MUTED))
    y = 100
    for row in rows:
        x = 40
        for label, w in row:
            width = int(unit * w)
            if label:
                b.append(rect(x, y, width, kh, KEY, r=8, stroke=ACCENT, sw=1.2))
                b.append(text(x + width / 2, y + 28, label, size=18, fill=TITLE, font=MONO, anchor="middle"))
                b.append(text(x + width / 2, y + 50, meaning[label], size=14, fill=MUTED, anchor="middle"))
            x += width + gap
        y += kh + gap
    svg("keyboard.svg", 1200, 330, "\n".join(b),
        "The keys the pad claims",
        "Enter runs the command, Up and Down walk the history, Ctrl+C interrupts, Ctrl+L clears, "
        "Ctrl+T attaches the session to a terminal, Ctrl+K restarts it, Ctrl+P lists sessions, "
        "Tab and Alt+1 to Alt+4 move between tabs, Escape closes the pad.")


def tabs_board():
    """The tab strip, with every state a tab can be in labelled."""
    b = [rect(0, 0, 1200, 250, BG, r=22)]
    b.append(text(40, 44, "A TAB IS A SESSION", size=18, fill=ACCENT, font=MONO, spacing=2.4))
    tabs = [
        ("1 ~/src", "the one you are looking at", KEY, TITLE, False, False),
        ("2 etc", "somewhere else, still running", BG, MUTED, False, False),
        ("3 ~", "something is running in it", BG, MUTED, True, False),
        ("4 notes", "a session you made yourself", BG, TEXT, False, True),
    ]
    x = 40
    for label, caption, fill, ink, dot, borrowed in tabs:
        b.append(rect(x, 80, 260, 54, fill, r=8, stroke=ACCENT if fill == KEY else None, sw=1.2))
        if dot:
            b.append(f'  <circle cx="{x + 24}" cy="107" r="6" fill="{ACCENT}"/>')
        b.append(text(x + (44 if dot else 24), 114, label, size=20, fill=ink, font=MONO))
        b.append(text(x + 4, 162, caption, size=16, fill=MUTED))
        if borrowed:
            b.append(text(x + 4, 186, "named, not placed: it is not this tab's own", size=15, fill=ACCENT))
        x += 282
    b.append(text(40, 224, "Each has its own directory, environment, history and half-typed line. "
                           "The bar icon pulses while any of them is running.", size=17, fill=MUTED))
    svg("tabs.svg", 1200, 250, "\n".join(b),
        "A tab is a session",
        "Four tabs: the active one raised, one idle elsewhere, one with a pulsing dot because "
        "something is running in it, and one showing a session the user made in a terminal, "
        "which is labelled by name rather than by directory.")


def settings_specimen():
    """The widget's shell.json entry, with a note against each key."""
    entries = [
        ('"id": "io.github.swey-l1.bar-term",', "which widget this is"),
        ('"workdir": "/home/you/src",', "where a new session starts"),
        ('"tabs": 4,', "how many the strip holds, 1 to 6"),
        ('"maxLines": 200,', "how far back the pad reads"),
        ('"session2": "notes"', "tab 2 shows a session you made"),
    ]
    h = 150 + 34 * len(entries)
    b = [rect(0, 0, 1200, h, BG, r=22),
         text(40, 44, "~/.config/omarchy/shell.json", size=18, fill=ACCENT, font=MONO, spacing=1.6),
         text(40, 72, "Under bar.layout. Every key is optional; what is missing takes its default.",
              size=17, fill=MUTED)]
    b.append(rect(28, 92, 1144, 42 + 34 * len(entries), KEY, r=12))
    b.append(text(52, 120, "{", size=18, fill=TEXT, font=MONO))
    y = 154
    for line, note in entries:
        b.append(text(72, y, esc(line), size=18, fill=TITLE, font=MONO, preserve=True))
        b.append(text(700, y, "← " + note, size=17, fill=MUTED, font=SANS))
        y += 34
    b.append(text(52, y - 8, "}", size=18, fill=TEXT, font=MONO))
    svg("settings.svg", 1200, h, "\n".join(b),
        "The widget's entry in shell.json",
        "An example entry: id, workdir for where a new session starts, tabs, maxLines, "
        "and session2 pointing tab 2 at a session called notes.")


def made_with():
    b = [rect(0, 0, 420, 64, BG, r=14),
         rect(12, 12, 40, 40, KEY, r=8, stroke=ACCENT, sw=1.5),
         f'  <path d="M26 32 h12 M32 26 l6 6 l-6 6" fill="none" stroke="{TITLE}" '
         f'stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>',
         text(66, 27, "README MADE WITH", size=11, fill=MUTED, font=MONO, spacing=2),
         text(66, 49, "beautify-github-readme", size=18, fill=TITLE, weight=700),
         f'  <path d="M384 26 h12 v12 M396 26 l-14 14" fill="none" stroke="{ACCENT}" '
         f'stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>']
    svg("made-with-beautify.svg", 420, 64, "\n".join(b),
        "README made with beautify-github-readme",
        "A small signature in the pad's own style: a keycap, the words README MADE WITH, "
        "and the skill's name with an outbound arrow.")


def card():
    """preview.png, for the marketplace listing.

    The card on plugins.omarchy.org is a 384x175 box with object-fit: cover, so a
    wide image loses its sides -- which is how a hero 1200x360 ends up with half
    its title cut off. This is drawn at the card's own ratio, and everything that
    has to be read is inside the middle, where a few pixels of crop cannot reach.

    It is also read at a third of this size, so nothing here is smaller than 30
    units: at card scale that is a 10px word, and anything less is a smudge.
    """
    b = [rect(0, 0, 1200, 548, BG, r=0)]
    b.append(text(72, 112, "OMARCHY BAR WIDGET", size=30, fill=ACCENT, font=MONO, spacing=4))
    b.append(text(70, 214, "Bar Terminal", size=92, fill=TITLE, weight=700))
    b.append(text(72, 282, "A terminal session in the bar.", size=38, fill=TEXT))
    b.append(text(72, 338, "Tabs are tmux sessions: they stay", size=38, fill=TEXT))
    b.append(text(72, 394, "where you left them.", size=38, fill=TEXT))
    b.append(rect(72, 440, 96, 5, ACCENT, r=3))
    b.append(text(72, 492, "QML + bash  ·  MIT", size=30, fill=MUTED, font=MONO))
    b.append(mini_pad(700, 64, scale=1.4))
    svg("card.svg", 1200, 548, "\n".join(b),
        "Bar Terminal: a terminal session in the Omarchy bar",
        "The marketplace card: the plugin's name, one line about what it is, and the pad "
        "drawn as it really looks, with output, a prompt, a key row and a tab strip.")


def main():
    hero()
    how_it_works()

    section("install", "01", "INSTALL", "Get it into the bar",
            [("omarchy plugin add …", MUTED), ("bar-term-1  idle", TEXT)])
    sub("requirements", "01.1", "Requirements")
    sub("one-command", "01.2", "One command")

    section("use", "02", "USE", "Run things from the bar",
            [("$ git log --oneline", TEXT), ("ok", ACCENT)])
    sub("keyboard", "02.1", "Keyboard")
    sub("tabs", "02.2", "Tabs")
    sub("sessions", "02.3", "Resuming a session you already have")
    sub("attaching", "02.4", "Attaching a session to a terminal")
    sub("hotkey", "02.5", "Optional hotkey")

    section("settings", "03", "SETTINGS", "What shell.json holds",
            [('"tabs": 4', TEXT), ('"session2": "notes"', MUTED)])
    sub("limits", "03.1", "Limits worth knowing")
    sub("shim", "03.2", "Using the shim directly")

    section("development", "04", "DEVELOPMENT", "How it is built",
            [("25 shim tests", MUTED), ("edit · update · look", TEXT)])

    card()
    keyboard_board()
    tabs_board()
    settings_specimen()
    made_with()

    code("tmux", "tmux is what a tab actually is",
         ["omarchy-pkg-add tmux"],
         "Omarchy's own installer, so there is no root command to copy from a web page.")
    code("install", "any terminal on the omarchy machine",
         ["omarchy plugin add https://github.com/swey-l1/omarchy-bar-term --enable"],
         "--enable is what puts the widget into the bar; without it the plugin installs and nothing appears.")
    code("hotkey", "~/.config/hypr/bindings.lua",
         ['o.bind("SUPER SHIFT", "T", "Bar terminal", "omarchy-shell shell toggle io.github.swey-l1.bar-term")'])
    code("attach", "reaching a session without the pad",
         ["tmux attach -t bar-term-1", "tmux switch-client -t bar-term-1"],
         "The second one is for when you are already inside tmux: attaching would refuse to nest.")
    code("shim", "what the widget runs, by hand",
         ["bar-term list", "bar-term send bar-term-1 'ls -la'", "bar-term capture bar-term-1 40",
          "bar-term states bar-term-1 notes"])
    code("dev", "the loop",
         ["/usr/lib/qt6/bin/qmllint *.qml", "./test/bar-term.sh",
          "omarchy plugin update io.github.swey-l1.bar-term --yes", "omarchy restart shell"])
    print("wrote", len(list(OUT.glob("*.svg"))), "svgs")


if __name__ == "__main__":
    main()
