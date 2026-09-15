import QtQuick
import qs.Commons

// The pad's palette and metrics, named once. Panel *is* a Theme, so every
// `panel.gap` and `panel.textColour` in the component files resolves here
// without Panel re-exporting two dozen names. `bar` is declared here because
// the text colour and face come from it.
Item {
  // Injected by the bar after creation.
  property var bar

  // ---- palette -------------------------------------------------------------

  // The pad's surfaces and status colours, named once. Every component file
  // draws with these, and a literal repeated across five files is one that
  // drifts the first time somebody adjusts it -- the AUTH button had already
  // ended up a shade brighter on hover than every other button.
  readonly property color surfaceIdle:        Qt.rgba(1, 1, 1, 0.04)
  readonly property color surfaceRaised:      Qt.rgba(1, 1, 1, 0.06)
  readonly property color surfaceButton:      Qt.rgba(1, 1, 1, 0.08)
  readonly property color surfaceHover:       Qt.rgba(1, 1, 1, 0.10)
  readonly property color surfaceButtonHover: Qt.rgba(1, 1, 1, 0.16)

  readonly property color okColour:   "#98c379"
  readonly property color warnColour: "#e5c07b"
  // Urgent comes from the theme; the literal is only a fallback for when the
  // bar has not handed one over yet.
  readonly property color badColour:  bar && bar.urgent ? bar.urgent : "#e06c75"

  // Text and its face come from the bar's theme; the literals are only for the
  // moment before the bar has handed itself over.
  readonly property color  textColour: bar ? bar.foreground : "white"
  readonly property string fontFamily: bar ? bar.fontFamily : "monospace"

  // The colour of anything clickable, so a row, a key and a list entry all
  // answer the pointer the same way. `rest` is what it shows when left alone;
  // the caller decides whether that is transparent, raised or marked.
  function surfaceFor(pressed, hovered, rest) {
    return pressed ? Color.popups.border
         : hovered ? surfaceHover
         : rest
  }

  // ---- metrics -------------------------------------------------------------
  //
  // Named once here rather than as Style.space(N) scattered over seven files,
  // where the same number means a key in one place and a list row in another and
  // nothing says which is which.
  readonly property int gap:        Style.space(6)    // between anything and its neighbour
  readonly property int tightGap:   Style.space(4)    // between the picker's own rows
  readonly property int inset:      Style.space(6)    // text away from an edge

  readonly property int keyWidth:   Style.space(38)   // one button of the D-pad grid
  readonly property int keyHeight:  Style.space(34)

  readonly property int rowHeight:     Style.space(24)  // a picker row, a form button
  readonly property int listRowHeight: Style.space(22)  // a row of the app list
  readonly property int helpRowHeight: Style.space(16)  // a line of the shortcut list
  readonly property int fieldHeight:   Style.space(26)  // a text field
  readonly property int hintHeight:    Style.space(26)  // the hover text along the foot, two lines

  readonly property int badgeWidth:  Style.space(30)   // the AUTH button on a row
  readonly property int badgeHeight: Style.space(18)

  // Both lists scroll; these bound the pad rather than letting it run off-screen.
  readonly property int appListHeight:  Style.space(150)
  readonly property int helpListHeight: Style.space(120)

  readonly property int padWidth: keyWidth * 3 + gap * 2
}
