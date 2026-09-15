import QtQuick

// The widget's entry in shell.json, read and written. One reader with a
// fallback for every key, and one writer that merges. Nothing here runs a
// process; that is Service.qml.
Item {
  id: cfg

  // From the bar. `settings` is injected after creation, so every read below
  // is a binding rather than something taken once at startup.
  property var bar
  property string moduleName: ""
  property var settings

  // The manifest's defaults are not merged at runtime (the bar hands over
  // exactly what shell.json holds), so every reader carries its own fallback.
  function setting(key, fallback) {
    if (settings && settings[key] !== undefined && settings[key] !== null && settings[key] !== "")
      return settings[key]
    return fallback
  }

  // What the shim acts on. Replace with your own keys; keep one reader per key.
  readonly property string target: setting("target", "")
  readonly property int pollSec: setting("pollSec", 60)

  // updateEntryInline REPLACES the entry with { id } plus whatever it is handed,
  // so any key omitted here is silently dropped from shell.json. Always send
  // the current settings merged with the change.
  function persist(patch) {
    if (!bar || !bar.shell || typeof bar.shell.updateEntryInline !== "function") return false
    var merged = ({})
    if (settings) for (var k in settings) if (k !== "id") merged[k] = settings[k]
    for (var q in patch) merged[q] = patch[q]
    return bar.shell.updateEntryInline(moduleName, merged)
  }

  function writeTarget(t) { return persist({ target: String(t || "").trim() }) }
}
