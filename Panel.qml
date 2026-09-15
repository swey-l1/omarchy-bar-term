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

  // Service owns the sessions and every call to the shim; the Panel is the
  // model the pad reads, and forwards what the pad does to it.
  Service {
    id: svc
    bar: root.bar
    tabCount: cfg.tabs
    activeTab: root.activeTab
    workdir: cfg.workdir
    maxLines: cfg.maxLines
    open: root.opened
  }

  property int activeTab: 0
  readonly property var sessions: svc.sessions
  readonly property var session: svc.active

  readonly property bool usable: svc.haveTmux
  readonly property bool busy: session ? session.running : false
  readonly property bool anyBusy: svc.anyRunning
  readonly property bool failed: session ? session.failed : false
  readonly property var output: session ? session.lines : []
  readonly property int lastExit: session ? session.lastExit : -1

  // What the bar icon says for each state, beside nothing else that would have
  // to be kept in step with it.
  readonly property string stateMessage:
      !usable ? "Bar Terminal: tmux is not installed"
    : anyBusy ? "Bar Terminal: running"
    : failed ? "Bar Terminal: last command failed"
    : "Bar Terminal"

  // The line above the prompt. A session that has run nothing says nothing: an
  // "ok" there would read as if something had happened.
  readonly property string resultLine: !session ? ""
    : !usable ? "tmux is not installed"
    : session.running ? "running…"
    : session.lastExit < 0 ? ""
    : session.lastExit === 0 ? "ok"
    : session.lastExit === 130 ? "interrupted"
    : "exit " + session.lastExit

  // Amber for a command the user stopped, red only for one that failed on its
  // own: 130 is what a shell reports for Ctrl+C.
  readonly property color resultColour:
      !session || session.running || session.lastExit <= 0 ? textColour
    : session.lastExit === 130 ? warnColour
    : badColour

  function selectTab(i) {
    if (i < 0 || i >= sessions.length || i === activeTab) return
    if (session) session.draft = pad.promptText()
    activeTab = i
    pad.setPrompt(session ? session.draft : "")
    pad.focusPrompt()
  }
  function cycleTab() { if (sessions.length > 1) selectTab((activeTab + 1) % sessions.length) }

  function runCommand(cmd) { return svc.send(cmd) }
  function recall(step)    { return session ? session.recall(step) : null }
  function killCommand()   { svc.interrupt() }
  function clearOutput()   { svc.reset() }
  function restartSession(){ svc.restart() }
  // Attaching, not opening a new shell: the terminal comes up showing exactly
  // what the pad was showing. The pad closes on the way out because its layer
  // surface covers the screen and the new window would open behind it.
  function openInTerminal() {
    svc.attach()
    close()
  }

  // The pad owns the prompt, so the key table reaches it through here rather
  // than every binding knowing about the pad's internals.
  function submitPrompt()   { pad.submit() }
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
    onEntered: if (root.bar && root.bar.showTooltip) root.bar.showTooltip(root, root.stateMessage)
    onExited: if (root.bar && root.bar.hideTooltip) root.bar.hideTooltip(root)
    onClicked: root.toggle()
  }

  Pad { id: pad; panel: root }
}
