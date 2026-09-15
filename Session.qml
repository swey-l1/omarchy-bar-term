import QtQuick

// One tab: what its session is doing and what the pad should show for it. No
// process work happens here -- Service owns every call to the shim and feeds
// these -- so this file is only the answer to "what is tab 3 like right now".
Item {
  id: s

  // 1-based, and the same number the shim uses to name the tmux session, so a
  // tab and `bar-term capture 3` are talking about the same thing.
  property int index: 1

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

  // The last command's exit status, read from the session's own shell through
  // the rc file. -1 means nothing has finished in it yet.
  property int lastExit: -1

  readonly property bool running: sessionState === stateName.running
  readonly property bool failed:  sessionState === stateName.idle && lastExit > 0

  // Its own command history and its own half-typed line, because a tab that
  // forgets what you typed the moment you look at another one is not a tab.
  property var history: []
  property int historyAt: -1
  property string draft: ""

  function remember(cmd) {
    if (history.length === 0 || history[history.length - 1] !== cmd) {
      var h = history.slice(); h.push(cmd)
      if (h.length > 100) h = h.slice(h.length - 100)
      history = h
    }
    historyAt = -1
  }

  // Null when there is nothing further in that direction, so the prompt keeps
  // what is in it rather than blanking.
  function recall(step) {
    if (history.length === 0) return null
    var i = historyAt < 0 ? history.length : historyAt
    i += step
    if (i < 0) i = 0
    if (i >= history.length) { historyAt = -1; return "" }
    historyAt = i
    return history[i]
  }

  // A short name for the tab strip: the command word tells one session from
  // another at a glance ("git", "journalctl", "make").
  property string lastCmd: ""
  readonly property string tabLabel: {
    var c = lastCmd.trim()
    if (c === "") return ""
    var w = c.split(/\s+/)[0]
    return w.length > 8 ? w.substring(0, 8) : w
  }
}
