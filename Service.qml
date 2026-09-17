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
  // Told by the Panel, which reads them from Config: one session name per tab.
  property var names: []
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
    delegate: Session {
      index: model.index + 1
      name: svc.names.length > model.index && svc.names[model.index] !== ""
          ? svc.names[model.index] : "bar-term-" + (model.index + 1)
    }
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

  // Every verb names the session rather than the tab, so a tab pointed at
  // somebody else's session drives that one and nothing has to translate.
  function verb(name, args) { fire(name + " " + Util.shellQuote(args) ) }

  // ---- typing straight into the session ------------------------------------
  //
  // Keystrokes are queued and sent by one Process at a time, never through
  // fire-and-forget: two detached calls can land in either order, and a shell
  // that receives "l" then "s" when you typed "ls" is worse than a slow one.
  // Consecutive characters are coalesced into a single `type`, so a fast typist
  // costs fewer invocations rather than more.
  property var pending: []

  function enqueue(item) {
    var q = pending.slice(); q.push(item); pending = q
    hot.restart()          // read the screen back quickly while typing
    drain()
  }

  function typeText(s) { if (active && s !== "") enqueue({ kind: "text", value: s }) }
  function sendKey(name) { if (active) enqueue({ kind: "key", value: name }) }

  function drain() {
    if (sender.running || pending.length === 0 || !active) return
    var q = pending.slice()
    var first = q.shift()
    var args
    if (first.kind === "text") {
      var text = first.value
      while (q.length > 0 && q[0].kind === "text") text += q.shift().value
      args = "type " + Util.shellQuote(active.name) + " " + Util.shellQuote(text)
    } else {
      var keys = [first.value]
      while (q.length > 0 && q[0].kind === "key") keys.push(q.shift().value)
      args = "key " + Util.shellQuote(active.name) + " " + keys.join(" ")
    }
    pending = q
    sender.command = ["bash", "-c", shimCmd(args)]
    sender.running = true
  }

  Process {
    id: sender
    onExited: function(code, status) { svc.drain(); svc.pollCapture() }
  }

  // What the pad does with a key it does not want for itself. Returns true when
  // the session took it, which is nearly always: the point of this widget is
  // that the shell gets the keyboard.
  function forwardKey(ev) {
    if (!active) return false
    var named = ({})
    named[Qt.Key_Return] = "Enter";     named[Qt.Key_Enter] = "Enter"
    named[Qt.Key_Tab] = "Tab";          named[Qt.Key_Backtab] = "BTab"
    named[Qt.Key_Backspace] = "BSpace"; named[Qt.Key_Delete] = "DC"
    named[Qt.Key_Up] = "Up";            named[Qt.Key_Down] = "Down"
    named[Qt.Key_Left] = "Left";        named[Qt.Key_Right] = "Right"
    named[Qt.Key_Home] = "Home";        named[Qt.Key_End] = "End"
    named[Qt.Key_PageUp] = "PPage";     named[Qt.Key_PageDown] = "NPage"

    // Ctrl and a letter is a control key by name, not by the control character
    // Qt puts in ev.text: tmux wants "C-c", and \u0003 would arrive as nothing.
    if ((ev.modifiers & Qt.ControlModifier) && ev.key >= Qt.Key_A && ev.key <= Qt.Key_Z) {
      sendKey("C-" + String.fromCharCode(ev.key).toLowerCase())
      return true
    }
    if (named[ev.key] !== undefined) { sendKey(named[ev.key]); return true }
    // Anything printable is itself. Control characters are not: they arrive here
    // only when something above has already declined them.
    if (ev.text && ev.text.length > 0 && ev.text.charCodeAt(0) >= 0x20) {
      typeText(ev.text)
      return true
    }
    return false
  }

  function interrupt() { if (active) { verb("interrupt", active.name); captureSoon.restart() } }
  function reset()     { if (active) { verb("reset", active.name); captureSoon.restart() } }
  function restart()   { if (active) { verb("restart", active.name); active.lines = []; captureSoon.restart() } }
  function attach()    { if (active) verb("attach", active.name) }

  // Sent when the pad opens and when it looks at a different session, which is
  // every moment the size could be wrong. Attaching a terminal hands sizing
  // back to that terminal; this pulls it to the pad's width again afterwards.
  property int cols: 74
  property int rows: 30
  function resize() {
    if (active && cols > 0 && rows > 0)
      fire("size " + Util.shellQuote(active.name) + " " + cols + " " + rows)
  }

  // ---- reading back --------------------------------------------------------

  // Quoted one by one: a session the user made can be called anything.
  readonly property string stateArgs: {
    var a = []
    for (var i = 0; i < sessions.length; i++) a.push(Util.shellQuote(sessions[i].name))
    return a.join(" ")
  }

  Process {
    id: statePoll
    command: ["bash", "-c", svc.shimCmd("states " + svc.stateArgs)]
    // Nothing to ask about before the sessions exist, and `states` with no
    // names is a usage error.
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        var t = String(line).trim()
        if (t === "notool") { svc.haveTmux = false; return }
        svc.haveTmux = true
        // "<n> <state> <exit> <cwd>", one line per tab. The path is whatever
        // is left after the first three fields, so one with spaces survives.
        var f = t.split(/\s+/)
        if (f.length < 3) return
        var i = parseInt(f[0], 10) - 1
        if (i < 0 || i >= svc.sessions.length) return
        var s = svc.sessions[i]
        s.sessionState = f[1]
        s.lastExit = f[2] === "-" ? -1 : parseInt(f[2], 10)
        s.cwd = f.length > 3 ? f.slice(3).join(" ") : ""
      }
    }
  }

  Process {
    id: capture
    command: ["bash", "-c", svc.shimCmd("capture "
              + (svc.active ? Util.shellQuote(svc.active.name) : "''") + " " + svc.maxLines)]
    property var buf: []
    stdout: SplitParser { onRead: function(line) { capture.buf.push(String(line)) } }
    onExited: function(code, status) {
      if (svc.active) svc.active.lines = capture.buf
      capture.buf = []
    }
    onRunningChanged: if (running) buf = []
  }

  function pollStates()  { if (!statePoll.running && sessions.length > 0) statePoll.running = true }
  function pollCapture() { if (!capture.running && svc.active) capture.running = true }

  // Every session on the server, for choosing one. Read on demand rather than
  // polled: it is only looked at while the picker is open.
  property var available: []
  Process {
    id: lister
    command: ["bash", "-c", svc.shimCmd("list")]
    property var buf: []
    onRunningChanged: if (running) buf = []
    stdout: SplitParser {
      onRead: function(line) {
        // "<name>\t<cwd>": tab-separated because a session name may have spaces.
        var parts = String(line).split("\t")
        if (parts[0] !== "") lister.buf.push({ name: parts[0], path: parts.length > 1 ? parts[1] : "" })
      }
    }
    onExited: function(code, status) { svc.available = lister.buf; lister.buf = [] }
  }
  function refreshList() { if (!lister.running) lister.running = true }

  // After a tab is pointed at a different session, so the strip and the screen
  // catch up at once instead of on the next tick.
  function pollStatesSoon() { captureSoon.restart() }

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

  // While someone is typing, the screen is read back fast enough that the echo
  // keeps up with the keyboard: a capture costs about ten milliseconds, so this
  // is affordable for the second or so a burst of typing lasts, and stops on its
  // own afterwards.
  property bool typing: false
  Timer {
    id: hot
    interval: 900; repeat: false
    onTriggered: svc.typing = false
    onRunningChanged: if (running) svc.typing = true
  }
  Timer {
    interval: 60
    running: svc.typing && svc.open
    repeat: true
    onTriggered: svc.pollCapture()
  }

  // Switching tabs shows the new one's screen straight away; the old capture
  // belongs to a tab nobody is looking at any more.
  onActiveTabChanged: { resize(); captureSoon.restart() }
  onOpenChanged: if (open) { resize(); captureSoon.restart() }
}
