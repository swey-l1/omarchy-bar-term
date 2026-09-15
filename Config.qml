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

  // What the shim acts on. One reader per key, each with the fallback the
  // manifest advertises, because the manifest's defaults are not merged at
  // runtime.
  //
  // An empty workdir is left empty rather than filled in with a guess: the shim
  // answers that with $HOME, which is the one place QML cannot name and the
  // shell always can.
  readonly property string workdir: setting("workdir", "")
  readonly property int timeoutSec: setting("timeoutSec", 20)
  readonly property int maxLines: setting("maxLines", 200)
  // Clamped, because shell.json is hand-edited and nothing enforces the
  // manifest's range: zero tabs would leave the pad with nothing to draw.
  readonly property int tabs: Math.max(1, Math.min(6, setting("tabs", 4)))

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

  function writeWorkdir(d) { return persist({ workdir: String(d || "").trim() }) }
}
