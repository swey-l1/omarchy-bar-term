import QtQuick

// A Text in the pad's colour and face. Everything readable on the pad is one
// of these, so a bare Text is a Text that forgot the theme. Size and opacity
// stay with the caller; they are what make one line differ from the next.
Text {
  // The Panel this belongs to, for theming.
  property var panel: null

  color: panel.textColour
  font.family: panel.fontFamily
}
