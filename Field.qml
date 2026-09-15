import QtQuick
import qs.Commons

// A text field on the pad: the type-at-the-TV entry and the three form fields.
//
// A FocusScope, not a plain Rectangle: focus given to the component has to reach
// the input inside it. With a Rectangle root, `focus: true` and
// `forceActiveFocus()` both land on the rectangle and stop there, so the field
// draws as if it were ready and every keystroke goes somewhere else.
FocusScope {
  id: f

  // The Panel this belongs to: everything it draws is themed from panel.bar.
  property var panel: null
  property string placeholder: ""
  property int fontSize: 10
  property alias text: fi.text
  // Sees every key before the input does and returns true to claim it. Keys
  // arrive here whether the field holds focus or the pad forwards them, so
  // this is the one place a form's Return and Escape are handled.
  property var onKey: null
  // So the pad can hand keys straight to the input when focus is not where it
  // should be; layer-shell only grants the surface focus on interaction.
  property alias input: fi

  readonly property bool focused: fi.activeFocus
  function focusMe() { fi.forceActiveFocus() }

  implicitWidth: panel.padWidth
  implicitHeight: panel.fieldHeight
  width: implicitWidth
  height: implicitHeight

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: panel.surfaceRaised
    border.width: fi.activeFocus ? 1 : 0
    border.color: panel.textColour

    TextInput {
      id: fi
      // Within the scope, so focus handed to the Field arrives here.
      focus: true
      Keys.onPressed: function(ev) { if (f.onKey && f.onKey(ev)) ev.accepted = true }
      anchors.fill: parent
      anchors.leftMargin: panel.inset
      anchors.rightMargin: panel.inset
      verticalAlignment: TextInput.AlignVCenter
      clip: true
      color: panel.textColour
      font.family: panel.fontFamily
      font.pixelSize: f.fontSize
      selectByMouse: true

      PadText {
        panel: f.panel
        anchors.verticalCenter: parent.verticalCenter
        visible: fi.text.length === 0 && !fi.activeFocus
        text: f.placeholder
        opacity: 0.35
        font.pixelSize: fi.font.pixelSize
      }
    }
  }
}
