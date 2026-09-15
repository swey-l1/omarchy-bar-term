import QtQuick
import qs.Commons

// A small filled button: SAVE, DELETE and CANCEL in the picker's forms, AUTH
// on a set's row. Sized by the caller, because how many share a form's row
// changes with the form and the row badge is smaller again.
Rectangle {
  // The Panel this belongs to: themed from panel.bar, hover reported through
  // panel.setHint.
  property var panel: null
  id: fb
  property string label: ""
  property string tip: ""
  property int fontSize: 9
  property bool active: true
  property var onPress: null

  height: panel.rowHeight
  radius: Style.cornerRadius
  opacity: fb.active ? 1.0 : 0.4
  color: fbMa.containsMouse && fb.active ? panel.surfaceButtonHover : panel.surfaceButton

  PadText {
    panel: fb.panel
    anchors.centerIn: parent
    text: fb.label
    font.pixelSize: fb.fontSize
  }

  HintArea {
    id: fbMa
    panel: fb.panel
    anchors.fill: parent
    hint: fb.tip
    onClicked: if (fb.active && fb.onPress) fb.onPress()
  }
}
