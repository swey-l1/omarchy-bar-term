import QtQuick
import Quickshell.Io
import qs.Commons

// Everything that shells out, kept away from the pad. The half that talks to
// the outside is worth reading without the layout around it, and it is the half
// that can be reasoned about, and tested, on its own: see test/mini-term.sh.
Item {
  id: svc

  property string target: ""
  property int pollSec: 60

  // shell.json is hand-editable and nothing enforces the manifest's minimum, so
  // clamp: a zero would fire the timer on every event-loop iteration.
  readonly property int pollInterval: Math.max(10, pollSec) * 1000

  readonly property string shim: String(Qt.resolvedUrl("mini-term")).replace(/^file:\/\//, "")

  // The protocol with the shim, in one place. Every comparison in the widget
  // goes through these, so a misspelling is a missing property rather than a
  // comparison that silently never matches.
  readonly property var stateName: ({
    up:     "up",      // the tool answered
    down:   "down",    // it did not
    notool: "notool"   // omarchy-launch-terminal is not installed on this machine
  })

  // What the bar icon says for each, beside the names so a state cannot be
  // added without deciding its wording.
  readonly property var stateMessage: ({
    up:     "Mini Terminal",
    down:   "Mini Terminal: target unreachable",
    notool: "omarchy-launch-terminal not installed"
  })

  // Anything the shim reports that is not one of these is ignored rather than
  // stored, so the pad never shows a state it has no UI for.
  readonly property var validStates: Object.keys(stateName)

  // Not `state`: Item already has one, driving QML's own state machine.
  property string toolState: stateName.up

  // The one place that knows how to invoke the shim. An empty target is left
  // off rather than exported blank, so the shim's own fallback applies.
  function shimCmd(args) {
    return (target !== "" ? "TARGET=" + Util.shellQuote(target) + " " : "")
         + Util.shellQuote(shim) + " " + args
  }

  Process {
    id: probe
    command: ["bash", "-c", svc.shimCmd("status")]
    stdout: SplitParser {
      onRead: function(line) {
        var v = String(line).trim()
        if (svc.validStates.indexOf(v) !== -1) svc.toolState = v
      }
    }
  }

  Timer {
    interval: svc.pollInterval
    running: true; repeat: true; triggeredOnStart: true
    onTriggered: svc.reprobe()
  }

  function reprobe() { if (!probe.running) probe.running = true }

  // Settings arrive after the first probe has already run, so that one goes out
  // with an empty target. Without this the verdict would stand until the next
  // poll.
  onTargetChanged: Qt.callLater(svc.reprobe)
}
