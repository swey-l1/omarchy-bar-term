import QtQuick
import Quickshell.Io
import qs.Commons

// Everything that shells out, kept away from the pad, and the only file that
// knows the shim exists. It owns one Session per tab and keeps them true to
// what tmux actually has.
//
// Two pollers rather than one per tab: `states` answers for every tab in a
// single call, and only the tab being looked at needs its screen read. Four
// processes a tick to draw four dots is not a reasonable price for a widget
// that sits in a bar all day.
Item {
  id: svc

  property var bar: null
  property int tabCount: 4
  property int activeTab: 0
  property string workdir: ""
  property int maxLines: 200
  // Open means the pad is on screen. Everything here is paced by it: a pad
  // nobody is looking at does not need its screen read four times a second.
  property bool open: false

  readonly property string shim: String(Qt.resolvedUrl("bar-term")).replace(/^file:\/\//, "")

  property var sessions: []
  readonly property var active: sessions.length > activeTab ? sessions[activeTab] : null
  readonly property bool anyRunning: {
    for (var i = 0; i < sessions.length; i++) if (sessions[i].running) return true
    return false
  }
  // tmux missing is a property of the machine, not of one tab, so it is held
  // here and every session reports it.
  property bool haveTmux: true

  Instantiator {
    model: svc.tabCount
    delegate: Session { index: model.index + 1 }
    onObjectAdded: function(index, object) {
      var a = svc.sessions.slice(); a.splice(index, 0, object); svc.sessions = a
    }
    onObjectRemoved: function(index, object) {
      var a = svc.sessions.slice(); a.splice(index, 1); svc.sessions = a
    }
  }

  // The one place that knows how to invoke the shim. Settings ride along as
  // environment so the shim's own fallbacks apply when they are empty.
  function shimCmd(args) {
    return (workdir !== "" ? "WORKDIR=" + Util.shellQuote(workdir) + " " : "")
         + Util.shellQuote(shim) + " " + args
  }

  // Fire-and-forget. Everything the user does to a session is one of these:
  // the answer arrives through the next poll rather than as a return value,
  // which is also how a terminal behaves.
  function fire(args) {
    if (!bar || typeof bar.run !== "function") return
    bar.run(shimCmd(args))
  }

  function send(cmd) {
    var c = String(cmd || "").trim()
    if (c === "" || !active) return false
    active.remember(c)
    active.lastCmd = c
    // Assume it started rather than waiting up to a tick to be told: the pad
    // should look busy the instant Enter is pressed.
    active.sessionState = active.stateName.running
    active.lastExit = -1
    fire("send " + (activeTab + 1) + " " + Util.shellQuote(c))
    captureSoon.restart()
    return true
  }

  function interrupt() { if (active) { fire("interrupt " + (activeTab + 1)); captureSoon.restart() } }
  function reset()     { if (active) { fire("reset " + (activeTab + 1)); captureSoon.restart() } }
  function restart()   { if (active) { fire("restart " + (activeTab + 1)); active.lines = []; captureSoon.restart() } }
  function attach()    { if (active) fire("attach " + (activeTab + 1)) }

  // ---- reading back --------------------------------------------------------

  Process {
    id: statePoll
    command: ["bash", "-c", svc.shimCmd("states " + svc.tabCount)]
    stdout: SplitParser {
      onRead: function(line) {
        var t = String(line).trim()
        if (t === "notool") { svc.haveTmux = false; return }
        svc.haveTmux = true
        // "<n> <state> <exit>", one line per tab.
        var f = t.split(/\s+/)
        if (f.length < 3) return
        var i = parseInt(f[0], 10) - 1
        if (i < 0 || i >= svc.sessions.length) return
        var s = svc.sessions[i]
        s.sessionState = f[1]
        s.lastExit = f[2] === "-" ? -1 : parseInt(f[2], 10)
      }
    }
  }

  Process {
    id: capture
    command: ["bash", "-c", svc.shimCmd("capture " + (svc.activeTab + 1) + " " + svc.maxLines)]
    property var buf: []
    stdout: SplitParser { onRead: function(line) { capture.buf.push(String(line)) } }
    onExited: function(code, status) {
      if (svc.active) svc.active.lines = capture.buf
      capture.buf = []
    }
    onRunningChanged: if (running) buf = []
  }

  function pollStates()  { if (!statePoll.running) statePoll.running = true }
  function pollCapture() { if (!capture.running && svc.active) capture.running = true }

  // While the pad is open, often enough that typing feels like typing. While it
  // is shut, only often enough to keep the bar icon honest about a command left
  // running in a tab.
  Timer {
    interval: svc.open ? 700 : 4000
    running: true; repeat: true; triggeredOnStart: true
    onTriggered: {
      svc.pollStates()
      if (svc.open) svc.pollCapture()
    }
  }

  // Output arrives a moment after a key does, so the pad is read again shortly
  // after anything is sent rather than waiting for the next tick.
  Timer {
    id: captureSoon
    interval: 120; repeat: false
    onTriggered: { svc.pollCapture(); svc.pollStates() }
  }

  // Switching tabs shows the new one's screen straight away; the old capture
  // belongs to a tab nobody is looking at any more.
  onActiveTabChanged: captureSoon.restart()
  onOpenChanged: if (open) captureSoon.restart()
}
