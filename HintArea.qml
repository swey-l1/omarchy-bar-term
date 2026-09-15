import QtQuick

// A MouseArea that reports what it is over on the pad's own hint line. The
// bar's tooltip cannot draw from inside the pad (see Panel.qml), so every
// hover in the pad goes through this rather than through bar.showTooltip.
MouseArea {
  // The Panel this belongs to: the hint line lives there.
  property var panel: null
  property string hint: ""

  hoverEnabled: true
  onEntered: panel.setHint(hint)
  onExited: panel.clearHint(hint)
}
