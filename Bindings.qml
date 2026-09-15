import QtQuick

// Every key binding, once. What a key does, the hint on the button that does
// the same thing, and the line in the shortcut list are all read from `keyMap`,
// so a key cannot end up doing one thing and being advertised as another.
//
// The actions call back into the Panel, which owns the shim and the pad.
// `mods` is matched exactly, so Shift+R and R are separate entries.
Item {
  property var panel: null

  readonly property var keyMap: [
    { id: "refresh", keys: [Qt.Key_R],                  hint: "R",        label: "Refresh",   act: function() { panel.reprobe() } },
    { id: "run",     keys: [Qt.Key_Return, Qt.Key_Enter], hint: "Enter",  label: "Run",       act: function() { panel.sh("run") } },
    { id: "close",   keys: [Qt.Key_Escape, Qt.Key_Q],   hint: "Esc or Q", label: "Close",     act: function() { panel.close() } }
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
  // unclaimed falls through rather than being swallowed.
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
