import QtQuick
import qs.Commons

// The bar widget: the icon, and the model the pad and its components read
// through `panel`. Config holds the settings, Service the process layer,
// Bindings the key table, Pad the popup.
//
//   left  = open the pad
//
// A Theme, so the palette and metrics the components read as `panel.x` are
// inherited rather than repeated here. Glyphs are literal UTF-8, not \u
// escapes: Material icons are five hex digits and QML's \u takes four.
Theme {
  id: root

  property string moduleName: "io.github.swey-l1.mini-term"
  property var settings

  Config {
    id: cfg
    bar: root.bar
    moduleName: root.moduleName
    settings: root.settings
  }
  function setting(key, fallback) { return cfg.setting(key, fallback) }
  readonly property string workdir: cfg.workdir

  Service {
    id: svc
    workdir: cfg.workdir
    timeoutSec: cfg.timeoutSec
    maxLines: cfg.maxLines
  }
  readonly property string toolState: svc.toolState
  readonly property var stateName: svc.stateName
  readonly property bool busy: svc.running
  readonly property bool failed: toolState === stateName.failed
  readonly property bool usable: toolState !== stateName.notool
  readonly property var output: svc.output
  readonly property int lastExit: svc.lastExit
  readonly property int lastMs: svc.lastMs

  // What the line above the prompt says about the command that just finished.
  // Empty while nothing has run, because a fresh pad has nothing to report and
  // an "exit 0" there would read as if something had.
  readonly property string resultLine: svc.running ? "running…"
    : svc.lastExit < 0 ? ""
    : (svc.lastExit === 0 ? "ok" : "exit " + svc.lastExit) + "  ·  " + svc.lastMs + " ms"

  // ---- running things ------------------------------------------------------

  // Fire-and-forget: each call is a detached process, so anything ordered must
  // be one shim invocation.
  function sh(args) {
    if (!bar || typeof bar.run !== "function") return
    bar.run(svc.shimCmd(args))
  }

  // The command history, newest last, in memory only. It is not written to
  // shell.json on purpose: that file is the widget's settings and is rewritten
  // whole on every change, so putting a line of typing in it would mean a
  // settings write per command.
  property var history: []
  property int historyAt: -1   // -1 = not walking the history, typing something new

  function runCommand(cmd) {
    var c = String(cmd || "").trim()
    if (c === "" || !usable) return false
    if (!svc.runCmd(c)) return false
    if (history.length === 0 || history[history.length - 1] !== c) {
      var h = history.slice(); h.push(c)
      if (h.length > 100) h = h.slice(h.length - 100)
      history = h
    }
    historyAt = -1
    return true
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

  function killCommand()  { svc.kill() }
  function clearOutput()  { svc.clear() }
  // Fire-and-forget through sh(), not a callback handed to Service: passing
  // bar.run as a value drops what it was called on.
  function openInTerminal() {
    var c = String(pad.promptText() || "").trim()
    if (c !== "") sh("open " + Util.shellQuote(c))
  }

  // The pad owns the prompt, so the key table reaches it through here rather
  // than every binding knowing about the pad's internals.
  function submitPrompt() { pad.submit() }
  function recallInto(step) { pad.recall(step) }

  Bindings { id: bindings; panel: root }
  readonly property var keyHelp: bindings.keyHelp
  function hintFor(id)   { return bindings.hintFor(id) }
  function labelFor(id)  { return bindings.labelFor(id) }
  function runAction(id) { bindings.runAction(id) }
  function handleKey(ev) { return bindings.handleKey(ev) }

  property bool opened: false
  // The prompt takes the keyboard as soon as the pad is up: a terminal that
  // needs a click before it accepts typing is a terminal nobody would use.
  onOpenedChanged: if (opened) Qt.callLater(pad.focusPrompt)
  function open()   { opened = true }
  function close()  { opened = false }
  function toggle() { opened = !opened }

  // bar.showTooltip does nothing from inside the pad (its window is not the
  // bar's), so the pad draws hints on its own line.
  property string hoverHint: ""
  function setHint(t)   { if (t !== "") hoverHint = t }
  function clearHint(t) { if (hoverHint === t) hoverHint = "" }

  implicitWidth: bar ? (bar.vertical ? bar.barSize : 24) : 24
  implicitHeight: bar ? bar.barSize : 26

  PadText {
    panel: root
    anchors.centerIn: parent
    text: "󰆍"
    // Three things worth seeing from across the screen: something is running,
    // the last thing failed, and this machine cannot run anything at all.
    color: !root.usable ? root.badColour
         : root.busy ? root.okColour
         : root.failed ? root.badColour
         : root.textColour
    opacity: root.opened ? 1.0 : 0.85
    font.pixelSize: 14
    Behavior on opacity { NumberAnimation { duration: 120 } }

    // A command that takes a while should look like it is taking a while,
    // rather than like a widget that has stopped answering.
    SequentialAnimation on opacity {
      running: root.busy
      loops: Animation.Infinite
      NumberAnimation { to: 0.45; duration: 600; easing.type: Easing.InOutQuad }
      NumberAnimation { to: 1.0;  duration: 600; easing.type: Easing.InOutQuad }
    }
  }

  // The bar lays its own MouseArea over every module slot for drag-to-reorder,
  // so left stays a MouseArea and other buttons would use TapHandlers.
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton
    hoverEnabled: true
    onEntered: if (root.bar && root.bar.showTooltip) root.bar.showTooltip(root, svc.stateMessage[root.toolState])
    onExited: if (root.bar && root.bar.hideTooltip) root.bar.hideTooltip(root)
    onClicked: root.toggle()
  }

  Pad { id: pad; panel: root }
}
