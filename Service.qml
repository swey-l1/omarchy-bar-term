import QtQuick
import Quickshell.Io
import qs.Commons

// Everything that shells out, kept away from the pad. The half that talks to
// the outside is worth reading without the layout around it, and it is the half
// that can be reasoned about, and tested, on its own: see test/mini-term.sh.
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

  readonly property string shim: String(Qt.resolvedUrl("mini-term")).replace(/^file:\/\//, "")

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
    idle:    "Mini Terminal",
    running: "Mini Terminal: running",
    failed:  "Mini Terminal: last command failed",
    notool:  "Mini Terminal: no shell to run commands with"
  })

  readonly property var validStates: Object.keys(stateName)

  // Not `state`: Item already has one, driving QML's own state machine.
  property string toolState: stateName.idle

  // The last command's result, for the line above the prompt. -1 means nothing
  // has finished yet, which is a different thing from having exited 0.
  property int lastExit: -1
  property int lastMs: 0
  property string lastCmd: ""
  readonly property bool running: runner.running

  // The scrollback. Held as an array because the pad shows it in a ListView and
  // a ListModel would mean a row object per line for text that is never edited.
  property var output: []

  function clear() { output = []; lastExit = -1; lastMs = 0; lastCmd = "" }

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
      // 124 is timeout's, and the pad would otherwise show it as an ordinary
      // non-zero exit with no hint that nothing was wrong with the command.
      if (exitCode === 124) svc.append("mini-term: stopped after " + svc.timeoutSec + "s")
      svc.toolState = exitCode === 0 ? svc.stateName.idle : svc.stateName.failed
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
