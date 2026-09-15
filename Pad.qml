import QtQuick
import qs.Ui

// The popup: a key grid and a hint line, in a window that can hold the
// keyboard. Add rows of Key, forms and fields here; the Panel stays the model.
//
// KeyboardPanel, not PopupCard: PopupCard is an xdg-popup and only receives
// keys after a click routes focus through its parent surface.
KeyboardPanel {
  id: pad
  // The Panel this belongs to: the key table, the shim and the theme live there.
  property var panel: null
  anchorItem: panel
  bar: panel.bar
  owner: panel
  open: panel.opened
  // Layer-shell hands the surface keyboard focus, but Qt still needs an item to
  // make active, and it will not pick one on its own.
  focusTarget: keyCatcher
  contentWidth: pane.implicitWidth + padding * 2
  contentHeight: pane.implicitHeight + padding * 2

  function focusControls() { keyCatcher.forceActiveFocus() }

  component Key: PadKey { panel: pad.panel }

  // Zero-sized, and exists only to own the keyboard while the pad is open. A
  // layer-shell panel still has to route keys to *something*. When you add a
  // form, forward unclaimed keys to its input here (Keys.forwardTo) and let the
  // form's handleKey run first.
  Item {
    id: keyCatcher
    width: 0
    height: 0
    Keys.onPressed: function(ev) { if (panel.handleKey(ev)) ev.accepted = true }
  }

  Column {
    id: pane
    spacing: panel.gap

    Row {
      spacing: panel.gap
      Key { label: "RUN"; action: "run" }
      Key { glyph: "󰑐"; action: "refresh" }
      Key { glyph: "󰅖"; action: "close" }
    }

    // Whatever the pointer is on, and the key that does the same thing.
    // Fixed height, so hovering never makes the pad jump about.
    PadText {
      panel: pad.panel
      width: panel.padWidth
      height: panel.hintHeight
      verticalAlignment: Text.AlignVCenter
      wrapMode: Text.WrapAtWordBoundaryOrAnywhere
      maximumLineCount: 2
      elide: Text.ElideRight
      text: panel.hoverHint
      opacity: 0.55
      font.pixelSize: 9
    }
  }
}
