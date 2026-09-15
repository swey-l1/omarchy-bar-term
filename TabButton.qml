import QtQuick
import qs.Commons

// One tab in the strip along the foot of the pad. It has to answer three
// questions at a glance: which session am I looking at, is anything running in
// the others, and did one of them fail while I was elsewhere.
Rectangle {
  // The Panel this belongs to: the sessions, the theme and the hint line.
  property var panel: null
  id: tb
  property int index: 0
  readonly property var session: panel.sessions.length > index ? panel.sessions[index] : null
  readonly property bool active: panel.activeTab === index
  readonly property bool running: session ? session.running : false
  readonly property bool failed: session ? session.failed : false
  // The command word, or the number on its own for a tab nothing has run in.
  readonly property string caption: session && session.tabLabel !== ""
                                  ? (index + 1) + " " + session.tabLabel
                                  : String(index + 1)

  height: panel.rowHeight
  radius: Style.cornerRadius
  // The active tab is a raised surface rather than an outline: an outline reads
  // as "needs attention", which is what the failed colour is for.
  color: panel.surfaceFor(ma.pressed, ma.containsMouse,
                          tb.active ? panel.surfaceButton : panel.surfaceIdle)
  Behavior on color { ColorAnimation { duration: 90 } }

  Row {
    anchors.centerIn: parent
    spacing: panel.tightGap

    // Only while something is running, and only on the tabs that are not being
    // watched: the result line already says it for the one that is.
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: 5; height: 5; radius: 2.5
      visible: tb.running
      color: panel.okColour
      SequentialAnimation on opacity {
        running: tb.running
        loops: Animation.Infinite
        NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutQuad }
        NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
      }
    }

    PadText {
      panel: tb.panel
      anchors.verticalCenter: parent.verticalCenter
      text: tb.caption
      color: tb.failed ? panel.badColour : panel.textColour
      opacity: tb.active ? 1.0 : 0.55
      font.pixelSize: 9
    }
  }

  HintArea {
    id: ma
    panel: tb.panel
    anchors.fill: parent
    hint: "Tab " + (tb.index + 1)
        + (tb.running ? ": running" : tb.failed ? ": last command failed" : "")
        + "  [Alt+" + (tb.index + 1) + "]"
    onClicked: panel.selectTab(tb.index)
  }
}
