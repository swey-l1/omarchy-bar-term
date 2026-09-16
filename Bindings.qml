import QtQuick

// Every key binding, once. What a key does, the hint on the button that does the
// same thing, and the line in the shortcut list are all read from `keyMap`.
//
// The division of the keyboard is the whole design of this widget: **Alt is the
// pad's, everything else is the shell's.** Keys that are not claimed here are
// typed into the tmux session, which is what makes tab completion, readline and
// the shell's own history work rather than being imitated badly.
//
// Entries marked `shell: true` are actions with a button but no binding of their
// own: the key they name belongs to the shell and reaches it untouched. They are
// in the table so the button has a label and the list stays honest about what
// pressing that key does.
Item {
  property var panel: null

  readonly property var keyMap: [
    { id: "run",      keys: [], hint: "Enter",  shell: true, label: "Run what you typed",    act: function() { panel.sendKey("Enter") } },
    { id: "kill",     keys: [], hint: "Ctrl+C", shell: true, label: "Interrupt",             act: function() { panel.sendKey("C-c") } },
    // The key and the button differ on purpose. Ctrl+L reaches the shell and
    // clears its screen, which leaves the pad still showing the scrollback it
    // reads back; the button drops the scrollback as well, which is what someone
    // pressing a broom in a widget means by it.
    { id: "clear",    keys: [], hint: "Ctrl+L", shell: true, label: "Clear the screen, and the scrollback with it", act: function() { panel.clearOutput() } },
    { id: "complete", keys: [], hint: "Tab",    shell: true, label: "Complete (the shell's)", act: function() { panel.sendKey("Tab") } },
    { id: "history",  keys: [], hint: "Up",     shell: true, label: "Previous command (the shell's)", act: function() { panel.sendKey("Up") } },

    { id: "terminal", keys: [Qt.Key_T], mods: Qt.AltModifier, hint: "Alt+T", label: "Attach it to a terminal",   act: function() { panel.openInTerminal() } },
    { id: "pick",     keys: [Qt.Key_S], mods: Qt.AltModifier, hint: "Alt+S", label: "Show another session here", act: function() { panel.pickSession() } },
    { id: "restart",  keys: [Qt.Key_K], mods: Qt.AltModifier, hint: "Alt+K", label: "Restart this session",      act: function() { panel.restartSession() } },
    { id: "nextTab",  keys: [Qt.Key_Right], mods: Qt.AltModifier, hint: "Alt+Right", label: "Next tab",     act: function() { panel.cycleTab(1) } },
    { id: "prevTab",  keys: [Qt.Key_Left],  mods: Qt.AltModifier, hint: "Alt+Left",  label: "Previous tab", act: function() { panel.cycleTab(-1) } },
    { id: "tab1",     keys: [Qt.Key_1], mods: Qt.AltModifier, hint: "Alt+1", label: "Tab 1", act: function() { panel.selectTab(0) } },
    { id: "tab2",     keys: [Qt.Key_2], mods: Qt.AltModifier, hint: "Alt+2", label: "Tab 2", act: function() { panel.selectTab(1) } },
    { id: "tab3",     keys: [Qt.Key_3], mods: Qt.AltModifier, hint: "Alt+3", label: "Tab 3", act: function() { panel.selectTab(2) } },
    { id: "tab4",     keys: [Qt.Key_4], mods: Qt.AltModifier, hint: "Alt+4", label: "Tab 4", act: function() { panel.selectTab(3) } },
    { id: "close",    keys: [Qt.Key_Escape], hint: "Esc", label: "Close the pad", act: function() { panel.close() } }
  ]

  function entryFor(id) {
    for (var i = 0; i < keyMap.length; i++) if (keyMap[i].id === id) return keyMap[i]
    return null
  }
  function hintFor(id)   { var e = entryFor(id); return e ? e.hint  : "" }
  function labelFor(id)  { var e = entryFor(id); return e ? e.label : "" }
  function runAction(id) { var e = entryFor(id); if (e) e.act() }

  // The shortcut list, written once by the same table, saying plainly which half
  // of the keyboard each line belongs to.
  readonly property var keyHelp: keyMap.map(function (e) {
    return e.hint + "  " + e.label + (e.shell ? "  ·  to the shell" : "")
  })

  // Returns true when the key was the pad's. Everything else falls through to
  // the session, including every key named above with `shell: true`.
  function handleKey(ev) {
    var mods = ev.modifiers & (Qt.ShiftModifier | Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)
    for (var i = 0; i < keyMap.length; i++) {
      var e = keyMap[i]
      if (e.shell || e.keys.length === 0) continue
      if (mods !== (e.mods || 0)) continue
      if (e.keys.indexOf(ev.key) === -1) continue
      e.act()
      return true
    }
    return false
  }
}
