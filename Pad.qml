import QtQuick
import qs.Ui

// The popup: a scrollback, a prompt and the keys that act on them, in a window
// that can hold the keyboard. The Panel stays the model; this is the view.
//
// KeyboardPanel, not PopupCard: PopupCard is an xdg-popup and only receives
// keys after a click routes focus through its parent surface, so a text field
// inside one never sees typing.
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

  // There is no field to focus: the keys go to the session, so the pad only has
  // to hold the keyboard itself.
  function focusControls() { keyCatcher.forceActiveFocus() }
  function focusPrompt()   { keyCatcher.forceActiveFocus() }

  // Hover-only list of the bindings that have no button of their own.
  property bool showKeys: false

  // capture-pane returns text, not a cursor, so the pad draws its own: a block
  // on the end of the last line, which is where the shell's is when it is
  // waiting for you. Hidden while something is running, because then the cursor
  // belongs to that program and could be anywhere.
  property bool caretOn: true
  readonly property bool caretShown: panel.opened && !panel.busy && panel.usable

  function togglePicker() { if (picker.open) picker.hide(); else picker.show() }

  // The pad's own scrollback, by keyboard. PageUp and PageDown themselves go to
  // the session like every other unclaimed key -- whatever is running in there
  // has its own idea of what they mean -- so reading back through what the pad
  // holds is an Alt key like the rest of the pad's own.
  function scrollPage(dir) {
    var step = scrollback.height * 0.9 * dir
    scrollback.contentY = Math.max(0, Math.min(scrollback.contentY + step,
                                               Math.max(0, scrollback.contentHeight - scrollback.height)))
    scrollback.followTail = scrollback.atYEnd
  }

  // The picker sees keys first while it is open, so Up, Down and Enter mean the
  // list rather than the history, and Escape closes the list rather than the
  // pad. Everything it does not claim carries on to the key table.
  function handleKey(ev) {
    if (picker.handleKey(ev)) return true
    return panel.handleKey(ev)
  }
  component Key: PadKey { panel: pad.panel }

  // Zero-sized, and the only thing here that holds the keyboard. Every key it
  // receives is offered to the picker, then to the pad's own table, and anything
  // left is typed into the session.
  Item {
    id: keyCatcher
    width: 0
    height: 0
    focus: true
    Keys.onPressed: function(ev) { if (pad.handleKey(ev)) ev.accepted = true }

    // In here rather than at the pad's root: KeyboardPanel's default property is
    // a list of items, so a Timer declared directly under it is a load error --
    // "Cannot assign object of type QQmlTimer to list property contentItem" --
    // and the whole widget disappears from the bar. Nothing checks this.
    Timer {
      interval: 550; repeat: true; running: pad.caretShown
      onTriggered: pad.caretOn = !pad.caretOn
    }
  }

  Column {
    id: pane
    spacing: panel.gap

    // ---- the session's screen, or the list of sessions --------------------
    Rectangle {
      width: panel.padWidth
      height: panel.outputHeight
      radius: 4
      color: panel.surfaceIdle

      SessionPicker {
        id: picker
        panel: pad.panel
        anchors.fill: parent
      }

      ListView {
        visible: !picker.open
        id: scrollback
        anchors.fill: parent
        anchors.margins: panel.inset
        clip: true
        model: panel.output
        boundsBehavior: Flickable.StopAtBounds
        // The whole screen is replaced on every capture, not appended to, so
        // following the new output means reacting to the model itself changing;
        // a count that happens to stay the same is still new text.
        //
        // Unless it is being read further up: scrolling back and being yanked
        // to the bottom twice a second would make the scrollback useless.
        // Follow the newest output, unless the scrollback is being read further
        // up. That has to be decided on every movement, not just at the end of
        // one: the screen is replaced several times a second, and each
        // replacement re-runs the scroll, so a wheel that moved the view
        // without ending a flick was undone before it was seen.
        property bool followTail: true
        onContentYChanged: followTail = atYEnd
        onMovementEnded: followTail = atYEnd
        onModelChanged: if (followTail) Qt.callLater(positionViewAtEnd)
        // The lines wrap, so a delegate's height is not known when the model
        // changes: position again once the content has actually been laid out,
        // or the newest line is left half-drawn under the bottom edge.
        onContentHeightChanged: if (followTail) Qt.callLater(positionViewAtEnd)

        delegate: PadText {
          panel: pad.panel
          width: scrollback.width
          // The caret rides on the end of the last line rather than being its
          // own item: the lines wrap, and a separate caret would sit at the
          // right-hand edge of the box instead of after the last character.
          text: modelData + (index === scrollback.count - 1 && pad.caretShown
                             ? (pad.caretOn ? "█" : " ") : "")
          // Long lines wrap rather than being cut: a path or a compiler error
          // says nothing useful once its right-hand half is an ellipsis.
          wrapMode: Text.WrapAnywhere
          // The session's own prompt is in this text, so nothing here has to
          // mark where one command ends and the next begins.
          opacity: 0.8
          font.family: panel.monoFamily
          font.pixelSize: panel.monoSize
        }

        // Above the view rather than inside it: a Flickable eats the wheel, and
        // this has to decide first whether the wheel is the pad's or the
        // program's. NoButton so clicks and drags still reach the view.
        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.NoButton
          onWheel: function(w) {
            var dir = w.angleDelta.y > 0 ? "up" : "down"
            // A program on the alternate screen leaves the pad nothing to
            // scroll, so the wheel goes to it instead.
            w.accepted = panel.wheel(dir)
          }
        }

        PadText {
          panel: pad.panel
          anchors.centerIn: parent
          visible: scrollback.count === 0
          text: panel.usable ? "type; it goes straight to the shell" : "tmux is not installed"
          opacity: 0.35
          font.pixelSize: 9
        }
      }
    }

    // ---- how it went, and where it ran ------------------------------------
    Item {
      width: panel.padWidth
      height: panel.helpRowHeight

      PadText {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        panel: pad.panel
        text: panel.resultLine
        color: panel.resultColour
        opacity: 0.7
        font.pixelSize: 9
      }

      // Where the session is, and its name when the tab is showing one it does
      // not own: a borrowed session should never be mistaken for this tab's.
      PadText {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        panel: pad.panel
        width: parent.width * 0.7
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideLeft
        text: !panel.session ? ""
            : panel.session.owned ? panel.session.cwd
            : panel.session.name + "  ·  " + panel.session.cwd
        opacity: panel.session && !panel.session.owned ? 0.6 : 0.4
        font.pixelSize: 9
      }
    }

    Row {
      spacing: panel.gap
      Key { label: "RUN";  action: "run" }
      Key { glyph: "󰓛"; action: "kill";     unset: !panel.busy }
      Key { glyph: "󰃢"; action: "clear" }
      Key { glyph: "󰆍"; action: "terminal" }
      // Outlined while the list is up, so the button reads as the thing holding
      // the pad in that state rather than as one more action.
      Key { glyph: "󰉹"; action: "pick"; marked: picker.open }
      Key { glyph: "󰅖"; action: "close" }
    }

    // ---- the tabs ---------------------------------------------------------
    // Along the foot rather than above the scrollback: what is being read is the
    // output, and a strip at the top would push it down the pad every time.
    Row {
      spacing: panel.tightGap
      visible: panel.sessions.length > 1

      Repeater {
        model: panel.sessions.length
        TabButton {
          panel: pad.panel
          index: modelData
          width: Math.floor((panel.padWidth - panel.tightGap * (panel.sessions.length - 1))
                            / panel.sessions.length)
        }
      }
    }

    // The foot: one row holding the shortcut toggle and the hover line, and the
    // list the toggle opens. They share a row because they are never both
    // interesting at once, and a row of furniture is a row the terminal above
    // does not get.
    Column {
      spacing: panel.tightGap

      Item {
        width: panel.padWidth
        height: panel.helpRowHeight + panel.tightGap

        // Hover-only: there is nothing to click, it is just where the bindings
        // that have no button of their own are written down.
        Action {
          panel: pad.panel
          width: 150
          height: parent.height
          label: pad.showKeys ? "Hide shortcuts" : "Keyboard shortcuts"
          tip: pad.showKeys ? "Hide the list" : "Show every key"
          onPress: function() { pad.showKeys = !pad.showKeys }
        }

        // Whatever the pointer is on, and the key that does the same thing.
        // Right-aligned and elided: it is the only thing here that changes, and
        // it must not move anything when it does.
        PadText {
          panel: pad.panel
          anchors.right: parent.right
          anchors.rightMargin: panel.inset
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - 160
          horizontalAlignment: Text.AlignRight
          elide: Text.ElideRight
          text: panel.hoverHint
          opacity: 0.55
          font.pixelSize: 9
        }
      }

      ListView {
        visible: pad.showKeys
        width: panel.padWidth
        height: Math.min(panel.helpListHeight, panel.keyHelp.length * panel.helpRowHeight)
        clip: true
        model: panel.keyHelp
        boundsBehavior: Flickable.StopAtBounds
        onVisibleChanged: if (visible) positionViewAtBeginning()

        delegate: PadText {
          panel: pad.panel
          width: panel.padWidth
          height: panel.helpRowHeight
          verticalAlignment: Text.AlignVCenter
          leftPadding: panel.inset
          elide: Text.ElideRight
          text: modelData
          opacity: 0.72
          font.pixelSize: 9
        }
      }
    }
  }
}
