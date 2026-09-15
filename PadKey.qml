import QtQuick
import qs.Commons

// One button of the pad's grid. Naming an action is enough: the description,
// the shortcut shown on hover and what pressing it does all come from keyMap
// in the Panel. Shows a glyph if it has one, otherwise its label.
Rectangle {
  // The Panel this belongs to: the key table, the metrics, the theme and the
  // hint line all live there.
  property var panel: null
  id: k
  property string glyph: ""
  property string label: ""
  property string action: ""
  property string tip: action !== "" ? panel.labelFor(action) : ""
  property string keyHint: action !== "" ? panel.hintFor(action) : ""
  property var onPress: null
  // Outlined while the key does something other than what its face says --
  // the shortcut buttons configure rather than launch in edit mode, and
  // nothing else on them would show that.
  property bool marked: false
  // Nothing configured behind it. Still pressable, so the hint can say why.
  property bool unset: false
  readonly property string hintText: tip === "" ? ""
    : (keyHint === "" ? tip : tip + "  [" + keyHint + "]")

  implicitWidth: panel.keyWidth
  implicitHeight: panel.keyHeight
  radius: Style.cornerRadius
  border.width: k.marked ? 1 : 0
  border.color: panel.textColour
  opacity: k.unset ? 0.45 : 1.0
  color: panel.surfaceFor(ma.pressed, ma.containsMouse,
                          k.marked ? panel.surfaceHover : panel.surfaceIdle)
  Behavior on color { ColorAnimation { duration: 90 } }

  PadText {
    panel: k.panel
    anchors.centerIn: parent
    text: k.glyph !== "" ? k.glyph : k.label
    font.pixelSize: k.glyph !== "" ? 15 : 10
  }

  HintArea {
    id: ma
    panel: k.panel
    anchors.fill: parent
    hint: k.hintText
    onClicked: { if (k.onPress) k.onPress(); else if (k.action !== "") panel.runAction(k.action) }
  }
}
