import QtQuick

// Every key binding, once. What a key does, the hint on the button that does
// the same thing, and the line in the shortcut list are all read from `keyMap`,
// so a key cannot end up doing one thing and being advertised as another.
//
// The actions call back into the Panel, which owns the shim and the pad.
// `mods` is matched exactly, so Ctrl+C and C are separate entries.
//
// This table is deliberately short and nearly all modified keys. The prompt
// holds the keyboard whenever the pad is open, and every key it does not claim
// is a character somebody is trying to type: bind a bare letter here and it
// becomes impossible to type that letter into a command.
Item {
  property var panel: null

  readonly property var keyMap: [
    { id: "run",      keys: [Qt.Key_Return, Qt.Key_Enter], hint: "Enter",  label: "Run the command",   act: function() { panel.submitPrompt() } },
    { id: "histPrev", keys: [Qt.Key_Up],                   hint: "Up",     label: "Previous command",  act: function() { panel.recallInto(-1) } },
    { id: "histNext", keys: [Qt.Key_Down],                 hint: "Down",   label: "Next command",      act: function() { panel.recallInto(1) } },
    { id: "kill",     keys: [Qt.Key_C], mods: Qt.ControlModifier, hint: "Ctrl+C", label: "Interrupt the session", act: function() { panel.killCommand() } },
    { id: "clear",    keys: [Qt.Key_L], mods: Qt.ControlModifier, hint: "Ctrl+L", label: "Clear the screen",      act: function() { panel.clearOutput() } },
    { id: "terminal", keys: [Qt.Key_T], mods: Qt.ControlModifier, hint: "Ctrl+T", label: "Attach it to a terminal", act: function() { panel.openInTerminal() } },
    { id: "restart",  keys: [Qt.Key_K], mods: Qt.ControlModifier, hint: "Ctrl+K", label: "Restart this session",  act: function() { panel.restartSession() } },
    { id: "pick",     keys: [Qt.Key_P], mods: Qt.ControlModifier, hint: "Ctrl+P", label: "Show another session here", act: function() { panel.pickSession() } },
    { id: "nextTab",  keys: [Qt.Key_Tab],                  hint: "Tab",    label: "Next tab",          act: function() { panel.cycleTab() } },
    { id: "tab1",     keys: [Qt.Key_1], mods: Qt.AltModifier, hint: "Alt+1", label: "Tab 1",             act: function() { panel.selectTab(0) } },
    { id: "tab2",     keys: [Qt.Key_2], mods: Qt.AltModifier, hint: "Alt+2", label: "Tab 2",             act: function() { panel.selectTab(1) } },
    { id: "tab3",     keys: [Qt.Key_3], mods: Qt.AltModifier, hint: "Alt+3", label: "Tab 3",             act: function() { panel.selectTab(2) } },
    { id: "tab4",     keys: [Qt.Key_4], mods: Qt.AltModifier, hint: "Alt+4", label: "Tab 4",             act: function() { panel.selectTab(3) } },
    { id: "close",    keys: [Qt.Key_Escape],               hint: "Esc",    label: "Close",             act: function() { panel.close() } }
  ]

  function entryFor(id) {
    for (var i = 0; i < keyMap.length; i++) if (keyMap[i].id === id) return keyMap[i]
    return null
  }
  function hintFor(id)   { var e = entryFor(id); return e ? e.hint  : "" }
  function labelFor(id)  { var e = entryFor(id); return e ? e.label : "" }
  function runAction(id) { var e = entryFor(id); if (e) e.act() }

  // The shortcut list, written once by the same table.
  readonly property var keyHelp: keyMap.map(function (e) { return e.hint + "  " + e.label })

  // Returns true when the key was ours, so the caller can accept it; anything
  // unclaimed falls through rather than being swallowed -- which here means it
  // reaches the prompt as a character.
  function handleKey(ev) {
    var mods = ev.modifiers & (Qt.ShiftModifier | Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)
    for (var i = 0; i < keyMap.length; i++) {
      var e = keyMap[i]
      if (mods !== (e.mods || 0)) continue
      if (e.keys.indexOf(ev.key) === -1) continue
      e.act()
      return true
    }
    return false
  }
}
