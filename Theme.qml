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
  // drifts the first time somebody adjusts it.
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

  // The colour of anything clickable, so a key, a row and a list entry all
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
  readonly property int tightGap:   Style.space(4)    // between the pad's own rows
  readonly property int inset:      Style.space(6)    // text away from an edge

  // A pad as wide as a key grid would wrap `ls` into nonsense, so the width is
  // set by what output has to be readable in and the keys are divided out of it
  // rather than the other way round.
  readonly property int padWidth:   Style.space(420)
  readonly property int keysPerRow: 6
  readonly property int keyWidth:   Math.floor((padWidth - gap * (keysPerRow - 1)) / keysPerRow)
  readonly property int keyHeight:  Style.space(30)

  readonly property int rowHeight:     Style.space(24)  // a full-width line, a form button
  readonly property int helpRowHeight: Style.space(16)  // a line of the shortcut list
  readonly property int fieldHeight:   Style.space(28)  // the prompt
  readonly property int hintHeight:    Style.space(15)  // the hover text along the foot, one line

  // The scrollback. Bounded so a long-running command cannot grow the pad off
  // the screen; it scrolls inside this instead.
  readonly property int outputHeight:  Style.space(230)
  // A whole number of rows, so when there are more bindings than fit, the list
  // scrolls from a clean edge instead of cutting one in half and looking broken.
  readonly property int helpListRows:   18
  readonly property int helpListHeight: helpRowHeight * helpListRows

  // Output is read as columns as often as prose (ls, ps, a stack trace), so it
  // is the one place on the pad with a fixed-pitch face.
  readonly property string monoFamily: "monospace"
  readonly property int monoSize: 9

  // How much of a terminal actually fits, measured rather than guessed. The
  // session is sized to this: a session wider than the pad wraps every
  // full-width line into a ragged remnant underneath it, which is what a TUI's
  // boxes turn into and what made running one in here unreadable.
  FontMetrics {
    id: monoMetrics
    font.family: monoFamily
    font.pixelSize: monoSize
  }
  // averageCharacterWidth, not advanceWidth("M"): the second is a *method*, and a
  // binding that calls one does not re-evaluate when the object changes, so it
  // answered for the default font it had before the family resolved and sized
  // every session to 30 columns. For a fixed-pitch face the average is the cell.
  readonly property int padCols: Math.max(20, Math.floor((padWidth - inset * 2)
                                                         / Math.max(1, monoMetrics.averageCharacterWidth)))
  readonly property int padRows: Math.max(8, Math.floor((outputHeight - inset * 2)
                                                        / Math.max(1, monoMetrics.height)))
}
