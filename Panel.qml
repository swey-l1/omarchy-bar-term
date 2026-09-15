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
  readonly property string target: cfg.target
  function setting(key, fallback) { return cfg.setting(key, fallback) }
  function writeTarget(t)         { return cfg.writeTarget(t) }

  Service {
    id: svc
    target: root.target
    pollSec: cfg.pollSec
  }
  readonly property string toolState: svc.toolState
  readonly property var stateName: svc.stateName
  readonly property bool online: toolState === stateName.up
  function reprobe() { svc.reprobe() }

  // Fire-and-forget: each call is a detached process, so anything ordered
  // must be one shim invocation.
  function sh(args) {
    if (!bar || typeof bar.run !== "function") return
    bar.run(svc.shimCmd(args))
  }

  Bindings { id: bindings; panel: root }
  readonly property var keyHelp: bindings.keyHelp
  function hintFor(id)   { return bindings.hintFor(id) }
  function labelFor(id)  { return bindings.labelFor(id) }
  function runAction(id) { bindings.runAction(id) }
  function handleKey(ev) { return bindings.handleKey(ev) }

  property bool opened: false
  onOpenedChanged: if (opened) Qt.callLater(pad.focusControls)
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
    color: root.online ? root.textColour : root.badColour
    opacity: root.online ? (root.opened ? 1.0 : 0.85) : 0.9
    font.pixelSize: 14
    Behavior on opacity { NumberAnimation { duration: 120 } }
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
