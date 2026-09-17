import QtQuick

// One tab: what its session is doing and what the pad should show for it. No
// process work happens here -- Service owns every call to the shim and feeds
// these -- so this file is only the answer to "what is tab 3 like right now".
Item {
  id: s

  // 1-based tab number.
  property int index: 1

  // The tmux session this tab is showing, and whether that is the one the tab
  // would make for itself. A borrowed session is the user's own -- made in a
  // terminal, maybe long before this widget existed -- so the pad says so, and
  // nothing destructive should be reachable without noticing which it is.
  property string name: "bar-term-" + index
  readonly property bool owned: name === "bar-term-" + index

  // The session's screen, as lines. Replaced wholesale on each capture rather
  // than appended to: the shell owns the scrollback now, and a redrawn screen
  // (clear, a full-screen program, a resize) is not an append to the old one.
  property var lines: []

  readonly property var stateName: ({
    idle:    "idle",      // the session exists and nothing is running in it
    running: "running",   // something is
    gone:    "gone",      // no session yet; the next command makes one
    notool:  "notool"     // no tmux on this machine, so no sessions at all
  })
  property string sessionState: stateName.gone

  // Whether whatever is running in there asked for a mouse. A full-screen
  // program draws on the alternate screen, which tmux keeps no history for, so
  // the pad has one screenful and nothing to scroll: the wheel belongs to the
  // program instead.
  property bool mouseMode: false

  // The last command's exit status, read from the session's own shell through
  // the rc file. -1 means nothing has finished in it yet.
  property int lastExit: -1

  readonly property bool running: sessionState === stateName.running
  readonly property bool failed:  sessionState === stateName.idle && lastExit > 0

  // Where the session is, which is what tells one from another at a glance and
  // is the thing a session is actually *for*: tab 2 is the one in /etc.
  //
  // Taken from tmux rather than from the last command typed, because the
  // sessions outlive the widget: after a shell restart the tabs are still
  // there, and a label built from what this process happened to see would come
  // back blank.
  property string cwd: ""
  readonly property string tabLabel: {
    // A borrowed session is known by its name: that is what the user called it
    // and how they will look for it. Ours are known by where they are, since
    // "bar-term-2" says nothing.
    if (!owned) return name.length > 10 ? name.substring(0, 10) : name
    var c = String(cwd || "")
    if (c === "" || c === "-") return ""
    if (c === "/") return "/"
    var base = c.replace(/\/+$/, "").split("/").pop()
    if (base === "" ) return ""
    // $HOME is where a fresh session starts, and "david" would say nothing.
    if (c.indexOf("/home/") === 0 && c.split("/").length === 3) return "~"
    // Trimmed from the front: the end of a directory name is the part that
    // tells it apart ("…bar-term" beats "omarchy-b").
    return base.length > 10 ? "…" + base.substring(base.length - 9) : base
  }
}
