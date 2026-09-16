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

  // The prompt is where the keyboard belongs here, so both of these end at the
  // same place; focusControls exists because the Panel's own template calls it.
  function focusPrompt()   { prompt.focusMe() }
  function focusControls() { prompt.focusMe() }

  // Hover-only list of the bindings that have no button of their own.
  property bool showKeys: false

  function promptText() { return prompt.text }
  function setPrompt(s) { prompt.text = String(s || "") }
  function togglePicker() { if (picker.open) picker.hide(); else picker.show() }

  // The picker sees keys first while it is open, so Up, Down and Enter mean the
  // list rather than the history, and Escape closes the list rather than the
  // pad. Everything it does not claim carries on to the key table.
  function handleKey(ev) {
    if (picker.handleKey(ev)) return true
    return panel.handleKey(ev)
  }
  function submit() {
    if (panel.runCommand(prompt.text)) prompt.text = ""
  }
  // Null back from the Panel means there is nothing further in that direction,
  // so what is typed stays where it is.
  function recall(step) {
    var t = panel.recall(step)
    if (t !== null) prompt.text = t
  }

  component Key: PadKey { panel: pad.panel }

  // Zero-sized, and exists only to own the keyboard when the prompt does not. A
  // layer-shell panel still has to route keys to *something*, and right after
  // the pad opens the keys can arrive here before focus has settled on the
  // prompt, so they are forwarded rather than dropped.
  Item {
    id: keyCatcher
    width: 0
    height: 0
    Keys.forwardTo: [prompt.input]
    Keys.onPressed: function(ev) { if (pad.handleKey(ev)) ev.accepted = true }
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
        property bool followTail: true
        onMovementEnded: followTail = atYEnd
        onModelChanged: if (followTail) Qt.callLater(positionViewAtEnd)

        delegate: PadText {
          panel: pad.panel
          width: scrollback.width
          text: modelData
          // Long lines wrap rather than being cut: a path or a compiler error
          // says nothing useful once its right-hand half is an ellipsis.
          wrapMode: Text.WrapAnywhere
          // The session's own prompt is in this text, so nothing here has to
          // mark where one command ends and the next begins.
          opacity: 0.8
          font.family: panel.monoFamily
          font.pixelSize: panel.monoSize
        }

        PadText {
          panel: pad.panel
          anchors.centerIn: parent
          visible: scrollback.count === 0
          text: panel.usable ? "type a command below" : "tmux is not installed"
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

    // ---- the prompt -------------------------------------------------------
    Field {
      id: prompt
      panel: pad.panel
      width: panel.padWidth
      placeholder: "command"
      fontSize: panel.monoSize + 1
      // One hook for both routes into the field: whether the key arrived here
      // directly or was forwarded by the catcher, it is offered to the same
      // place, and anything unclaimed is typing.
      onKey: function(ev) { return pad.handleKey(ev) }
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

    // Hover-only: there is nothing to click, it is just where the bindings
    // that have no button of their own are written down.
    Action {
      panel: pad.panel
      label: pad.showKeys ? "Hide shortcuts" : "Keyboard shortcuts"
      tip: pad.showKeys ? "Hide the list" : "Show every key"
      onPress: function() { pad.showKeys = !pad.showKeys }
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
