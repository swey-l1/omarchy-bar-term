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

  property string moduleName: "io.github.swey-l1.bar-term"
  property var settings

  Config {
    id: cfg
    bar: root.bar
    moduleName: root.moduleName
    settings: root.settings
  }
  function setting(key, fallback) { return cfg.setting(key, fallback) }
  readonly property string workdir: cfg.workdir

  // One Service per tab: a session is a scrollback, a history, a half-typed line
  // and a process, and all four have to be per tab or the tabs are decoration.
  //
  // The list is kept alongside the Instantiator rather than read back out of it
  // with objectAt(), which is a plain function and so would not re-evaluate
  // anything when the active tab changes.
  property var sessions: []
  readonly property int tabCount: cfg.tabs
  property int activeTab: 0

  Instantiator {
    model: root.tabCount
    delegate: Service {
      workdir: cfg.workdir
      timeoutSec: cfg.timeoutSec
      maxLines: cfg.maxLines
    }
    onObjectAdded: function(index, object) {
      var a = root.sessions.slice(); a.splice(index, 0, object); root.sessions = a
    }
    onObjectRemoved: function(index, object) {
      var a = root.sessions.slice(); a.splice(index, 1); root.sessions = a
      // Lowering the tab count in shell.json can leave the active tab past the
      // end, which would blank the pad until something else moved it.
      if (root.activeTab >= a.length) root.activeTab = Math.max(0, a.length - 1)
    }
  }

  // Null for the moment between the widget existing and its sessions being
  // built, so everything reading through it carries a fallback.
  readonly property var svc: sessions.length > activeTab ? sessions[activeTab] : null

  readonly property string toolState: svc ? svc.toolState : "idle"
  readonly property var stateName: ({ idle: "idle", running: "running", failed: "failed", notool: "notool" })
  readonly property bool failed: toolState === stateName.failed
  readonly property bool usable: toolState !== stateName.notool
  readonly property var output: svc ? svc.output : []
  readonly property int lastExit: svc ? svc.lastExit : -1
  readonly property int lastMs: svc ? svc.lastMs : 0

  // The active tab's, for the result line. The icon uses anyBusy instead: a
  // command left running in another tab is exactly what the bar is for saying.
  readonly property bool busy: svc ? svc.running : false
  readonly property bool anyBusy: {
    for (var i = 0; i < sessions.length; i++) if (sessions[i].running) return true
    return false
  }

  function selectTab(i) {
    if (i < 0 || i >= sessions.length || i === activeTab) return
    if (svc) svc.draft = pad.promptText()
    activeTab = i
    pad.setPrompt(svc ? svc.draft : "")
    pad.focusPrompt()
  }
  function cycleTab() { if (sessions.length > 1) selectTab((activeTab + 1) % sessions.length) }

  // What the line above the prompt says about the command that just finished.
  // Empty while nothing has run, because a fresh pad has nothing to report and
  // an "exit 0" there would read as if something had.
  //
  // 143 and 124 are the shim's own doing rather than the command's verdict, and
  // reporting them as an exit status asks the reader to know what a SIGTERM is
  // numbered.
  readonly property string resultLine: !svc ? ""
    : svc.running ? "running…"
    : svc.lastExit < 0 ? ""
    : (svc.lastExit === 0 ? "ok"
     : svc.lastExit === 143 ? "stopped"
     : svc.lastExit === 124 ? "timed out after " + cfg.timeoutSec + "s"
     : "exit " + svc.lastExit) + "  ·  " + svc.lastMs + " ms"

  // Amber for the two the widget did itself, red only for a command that
  // actually failed: a stop the user asked for is not bad news.
  readonly property color resultColour:
      !svc || svc.running || svc.lastExit <= 0 ? textColour
    : svc.lastExit === 143 || svc.lastExit === 124 ? warnColour
    : badColour

  // ---- running things ------------------------------------------------------

  // Fire-and-forget: each call is a detached process, so anything ordered must
  // be one shim invocation.
  function sh(args) {
    if (!bar || typeof bar.run !== "function") return
    bar.run(svc.shimCmd(args))
  }

  // Command history lives in the session, not here, and in memory only: this
  // widget's settings are rewritten whole on every change, so keeping typing in
  // shell.json would mean a settings write per command.
  function runCommand(cmd) {
    var c = String(cmd || "").trim()
    if (c === "" || !usable || !svc) return false
    return svc.runCmd(c)
  }
  function recall(step) { return svc ? svc.recall(step) : null }

  function killCommand()  { if (svc) svc.kill() }
  function clearOutput()  { if (svc) svc.clear() }

  // Fire-and-forget through sh(), not a callback handed to Service: passing
  // bar.run as a value drops what it was called on.
  //
  // The pad closes on the way out. Its layer surface covers the screen, so the
  // terminal opens *behind* it and handing off looks like nothing happening --
  // which is exactly how this read the first time it was tried.
  function openInTerminal() {
    var c = String(pad.promptText() || "").trim()
    // No command means "a terminal here", which the shim understands.
    sh("open" + (c === "" ? "" : " " + Util.shellQuote(c)))
    if (c !== "" && svc) svc.remember(c)
    pad.setPrompt("")
    close()
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
         : root.anyBusy ? root.okColour
         : root.failed ? root.badColour
         : root.textColour
    opacity: root.opened ? 1.0 : 0.85
    font.pixelSize: 14
    Behavior on opacity { NumberAnimation { duration: 120 } }

    // A command that takes a while should look like it is taking a while,
    // rather than like a widget that has stopped answering.
    SequentialAnimation on opacity {
      running: root.anyBusy
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
    onEntered: if (root.bar && root.bar.showTooltip && root.svc) root.bar.showTooltip(root, root.svc.stateMessage[root.toolState])
    onExited: if (root.bar && root.bar.hideTooltip) root.bar.hideTooltip(root)
    onClicked: root.toggle()
  }

  Pad { id: pad; panel: root }
}
