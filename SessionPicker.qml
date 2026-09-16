import QtQuick
import qs.Commons

// Choosing which tmux session a tab shows. It covers the scrollback rather than
// opening beside it: the pad is one screen wide, and what you are choosing is
// what that screen shows, so replacing it is the honest gesture.
//
// Every session on the server is offered, not only the ones this widget made.
// Pointing a tab at a session you started in a terminal is the point of it.
Rectangle {
  id: sp

  // The Panel this belongs to: the sessions, the theme and the hint line.
  property var panel: null
  property bool open: false
  property int marked: 0

  // The rows: every session, then the tab's own if it is not already among
  // them, so there is always a way back to it.
  readonly property var rows: {
    var out = []
    var own = panel.ownSessionName(panel.activeTab)
    var list = panel.availableSessions
    for (var i = 0; i < list.length; i++) out.push({ name: list[i].name, path: list[i].path })
    for (var j = 0; j < out.length; j++) if (out[j].name === own) return out
    out.push({ name: own, path: "" })   // not made yet; choosing it will make it
    return out
  }

  radius: 4
  color: panel.surfaceIdle
  visible: open

  function show() {
    panel.refreshSessionList()
    marked = 0
    var here = panel.session ? panel.session.name : ""
    for (var i = 0; i < rows.length; i++) if (rows[i].name === here) marked = i
    open = true
  }
  function hide() { open = false }

  function choose(i) {
    if (i < 0 || i >= rows.length) return
    panel.bindSession(panel.activeTab, rows[i].name)
    hide()
  }

  // Keys are offered here before the key table, so Up, Down and Enter mean the
  // list while it is open and go back to meaning history the moment it is not.
  function handleKey(ev) {
    if (!open) return false
    if (ev.key === Qt.Key_Escape)                            { hide(); return true }
    if (ev.key === Qt.Key_Up)                                { marked = Math.max(0, marked - 1); return true }
    if (ev.key === Qt.Key_Down)                              { marked = Math.min(rows.length - 1, marked + 1); return true }
    if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) { choose(marked); return true }
    return false
  }

  Column {
    anchors.fill: parent
    anchors.margins: panel.inset
    spacing: panel.tightGap

    PadText {
      panel: sp.panel
      width: parent.width
      text: "Show in tab " + (panel.activeTab + 1) + ":"
      opacity: 0.5
      font.pixelSize: 9
    }

    Repeater {
      model: sp.rows

      Rectangle {
        required property int index
        required property var modelData
        width: sp.width - panel.inset * 2
        height: panel.rowHeight
        radius: Style.cornerRadius
        color: panel.surfaceFor(rowMa.pressed, rowMa.containsMouse,
                                index === sp.marked ? panel.surfaceButton : "transparent")

        Row {
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.left
          anchors.leftMargin: panel.inset
          anchors.right: parent.right
          anchors.rightMargin: panel.inset
          spacing: panel.gap

          PadText {
            panel: sp.panel
            text: modelData.name
            // The one being shown already, so choosing is a change and staying
            // is obvious.
            opacity: panel.session && modelData.name === panel.session.name ? 1.0 : 0.8
            font.pixelSize: 10
          }
          PadText {
            panel: sp.panel
            text: modelData.path === "" ? "not started yet" : modelData.path
            elide: Text.ElideLeft
            width: parent.width - 120
            opacity: 0.4
            font.pixelSize: 9
          }
        }

        HintArea {
          id: rowMa
          panel: sp.panel
          anchors.fill: parent
          hint: modelData.path === "" ? "Start " + modelData.name + " in this tab"
                                      : "Show " + modelData.name + " in this tab"
          onClicked: sp.choose(index)
        }
      }
    }
  }
}
