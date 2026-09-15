import QtQuick
import qs.Commons

// A full-width, left-aligned line in the picker: reads as a menu entry
// rather than a key, which is what separates "+ Add TV" from the D-pad.
Rectangle {
  // The Panel this belongs to: everything it draws is themed from
  // panel.bar, and hovering reports through panel.setHint.
  property var panel: null
  id: ac
  property string label: ""
  property string tip: ""
  property var onPress: null

  width: panel.padWidth
  height: panel.rowHeight
  radius: Style.cornerRadius
  color: panel.surfaceFor(acMa.pressed, acMa.containsMouse, "transparent")
  Behavior on color { ColorAnimation { duration: 90 } }

  PadText {
    panel: ac.panel
    anchors.left: parent.left
    anchors.leftMargin: panel.inset
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width - panel.inset * 2
    elide: Text.ElideRight
    text: ac.label
    opacity: 0.72
    font.pixelSize: 10
  }

  HintArea {
    id: acMa
    panel: ac.panel
    anchors.fill: parent
    hint: ac.tip
    onClicked: if (ac.onPress) ac.onPress()
  }
}
