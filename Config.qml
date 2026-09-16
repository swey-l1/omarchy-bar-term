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
  // shell always can. It is where a *new* session starts; after that the
  // session's own shell owns where it is, which is the point of a session.
  readonly property string workdir: setting("workdir", "")
  // How far back into the session's scrollback the pad reads.
  readonly property int maxLines: setting("maxLines", 200)
  // Clamped, because shell.json is hand-edited and nothing enforces the
  // manifest's range: zero tabs would leave the pad with nothing to draw.
  readonly property int tabs: Math.max(1, Math.min(6, setting("tabs", 4)))

  // Which tmux session each tab shows. Empty means the tab's own, and that is
  // the default rather than writing four keys nobody asked for into shell.json.
  // A key family through one function, so the name is built in one place.
  function sessionKey(n) { return "session" + n }
  function defaultSession(n) { return "bar-term-" + n }
  function sessionFor(n) {
    var s = String(setting(sessionKey(n), "")).trim()
    return s === "" ? defaultSession(n) : s
  }
  function writeSession(n, name) {
    var s = String(name || "").trim()
    var patch = ({})
    // Its own session is stored as nothing at all, so a tab that was pointed
    // somewhere and then put back leaves no trace behind in the settings.
    patch[sessionKey(n)] = (s === "" || s === defaultSession(n)) ? "" : s
    return persist(patch)
  }

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
