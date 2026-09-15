import QtQuick
import Quickshell.Io
import qs.Commons

// Everything that shells out, kept away from the pad. The half that talks to
// the outside is worth reading without the layout around it, and it is the half
// that can be reasoned about, and tested, on its own: see test/bar-term.sh.
//
// Unlike a widget that watches something, this one has no poll: its state is
// the state of the last command it was asked to run, so it changes when the
// user does something and at no other time.
Item {
  id: svc

  // Where commands run, and the bounds on one. All three reach the shim as
  // environment rather than as arguments, so the shim keeps its own defaults
  // when it is run by hand from a terminal.
  property string workdir: ""
  property int timeoutSec: 20
  property int maxLines: 200

  readonly property string shim: String(Qt.resolvedUrl("bar-term")).replace(/^file:\/\//, "")

  // The protocol with the shim, in one place. Every comparison in the widget
  // goes through these, so a misspelling is a missing property rather than a
  // comparison that silently never matches.
  readonly property var stateName: ({
    idle:    "idle",     // nothing has run, or the last thing worked
    running: "running",  // a command is out there now
    failed:  "failed",   // the last command exited non-zero
    notool:  "notool"    // there is no shell to run commands with
  })

  // What the bar icon says for each, beside the names so a state cannot be
  // added without deciding its wording.
  readonly property var stateMessage: ({
    idle:    "Bar Terminal",
    running: "Bar Terminal: running",
    failed:  "Bar Terminal: last command failed",
    notool:  "Bar Terminal: no shell to run commands with"
  })

  readonly property var validStates: Object.keys(stateName)

  // Not `state`: Item already has one, driving QML's own state machine.
  property string toolState: stateName.idle

  // What this session remembers: its own command history, and whatever was
  // half-typed in the prompt when the tab was last left. Both are per session
  // because a tab that forgets what you typed the moment you look at another one
  // is not a tab, it is a shared prompt with extra steps.
  property var history: []
  property int historyAt: -1   // -1 = not walking the history, typing something new
  property string draft: ""

  function remember(cmd) {
    if (history.length === 0 || history[history.length - 1] !== cmd) {
      var h = history.slice(); h.push(cmd)
      if (h.length > 100) h = h.slice(h.length - 100)
      history = h
    }
    historyAt = -1
  }

  // Walks the history and hands back what the prompt should now hold. Returns
  // null when there is nothing in that direction, so the prompt leaves what is
  // there rather than blanking it.
  function recall(step) {
    if (history.length === 0) return null
    var i = historyAt < 0 ? history.length : historyAt
    i += step
    if (i < 0) i = 0
    if (i >= history.length) { historyAt = -1; return "" }
    historyAt = i
    return history[i]
  }

  // A short name for the tab strip: the command word, which is what tells one
  // session from another at a glance ("git", "journalctl", "make").
  readonly property string tabLabel: {
    var c = lastCmd.trim()
    if (c === "") return ""
    var w = c.split(/\s+/)[0]
    return w.length > 8 ? w.substring(0, 8) : w
  }

  // The last command's result, for the line above the prompt. -1 means nothing
  // has finished yet, which is a different thing from having exited 0.
  property int lastExit: -1
  property int lastMs: 0
  property string lastCmd: ""
  readonly property bool running: runner.running

  // The scrollback. Held as an array because the pad shows it in a ListView and
  // a ListModel would mean a row object per line for text that is never edited.
  property var output: []

  function clear() {
    output = []; lastExit = -1; lastMs = 0; lastCmd = ""
    // And the verdict with it. Leaving the icon urgent after a clear points the
    // user at output that is no longer there, and the only way back to normal
    // was to run something else that happened to succeed.
    //
    // Only from failed: a command still running keeps `running`, and `notool`
    // is about the machine rather than about anything that was run.
    if (toolState === stateName.failed) toolState = stateName.idle
  }

  function append(line) {
    var next = output.slice()
    next.push(line)
    // Bounded here rather than in the view: the array is what would grow
    // without limit, and dropping from the front is what a scrollback does.
    if (next.length > maxLines) next = next.slice(next.length - maxLines)
    output = next
  }

  // The one place that knows how to invoke the shim. The settings ride along as
  // environment so the shim's own fallbacks apply when they are empty.
  function shimCmd(args) {
    return (workdir !== "" ? "WORKDIR=" + Util.shellQuote(workdir) + " " : "")
         + "TIMEOUT=" + Math.max(1, timeoutSec) + " "
         + Util.shellQuote(shim) + " " + args
  }

  property double startedAt: 0

  function runCmd(cmd) {
    var c = String(cmd || "").trim()
    if (c === "" || runner.running) return false
    remember(c)
    lastCmd = c
    lastExit = -1
    append("$ " + c)
    startedAt = Date.now()
    toolState = stateName.running
    // Quoted as one argument: the shim joins "$*" and hands it to the shell, so
    // the pipes and quotes in what was typed have to survive this layer intact.
    runner.command = ["bash", "-c", shimCmd("run " + Util.shellQuote(c))]
    runner.running = true
    return true
  }

  // Setting running to false is how Quickshell asks a Process to go away; the
  // shim's own timeout is the backstop for anything that ignores that.
  function kill() { if (runner.running) runner.running = false }

  Process {
    id: runner
    stdout: SplitParser { onRead: function(line) { svc.append(String(line)) } }
    stderr: SplitParser { onRead: function(line) { svc.append(String(line)) } }
    onExited: function(exitCode, exitStatus) {
      svc.lastMs = Date.now() - svc.startedAt
      svc.lastExit = exitCode
      // Noted in the scrollback as well as on the result line, because the
      // result line is about the last command only: without this, a stopped
      // command is a prompt echo with no output and no reason given once the
      // next one has run.
      if (exitCode === 124) svc.append("bar-term: timed out after " + svc.timeoutSec + "s")
      else if (exitCode === 143) svc.append("bar-term: stopped")
      // A command the user stopped is not a failure, so the bar icon stays as it
      // was rather than going urgent over something that was asked for.
      svc.toolState = (exitCode === 0 || exitCode === 143) ? svc.stateName.idle
                    : svc.stateName.failed
    }
  }

  // Runs once, not on a timer: whether a shell exists does not change while the
  // bar is up, and the answer only decides whether the widget is usable at all.
  Process {
    id: probe
    command: ["bash", "-c", svc.shimCmd("status")]
    running: true
    stdout: SplitParser {
      onRead: function(line) {
        if (String(line).trim() === svc.stateName.notool) svc.toolState = svc.stateName.notool
      }
    }
  }
}
