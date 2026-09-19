import QtQuick

// A Text in the pad's colour and face. Everything readable on the pad is one
// of these, so a bare Text is a Text that forgot the theme. Size and opacity
// stay with the caller; they are what make one line differ from the next.
Text {
  // The Panel this belongs to, for theming.
  property var panel: null

  // Everything this widget draws is text somebody else produced: the output of
  // a command, a path, a session name. Qt's default is AutoText, which detects
  // markup and renders it, so a line containing <b> came out bold with the tags
  // eaten, and a line containing <img src> would have been fetched. Plain means
  // what it says.
  textFormat: Text.PlainText

  color: panel.textColour
  font.family: panel.fontFamily
}
