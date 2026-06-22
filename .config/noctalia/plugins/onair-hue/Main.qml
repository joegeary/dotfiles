import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Commons

// Background automation: when the camera (and/or mic) goes live, set a Hue
// light red and silence notifications; restore the light + notifications when
// the call ends. This is the plugin port of the old `monitor-onair` service.
Item {
  id: root
  property var pluginApi: null

  // --- Settings ---
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  property string lightId: cfg.lightId ?? defaults.lightId ?? ""
  property real colorX: cfg.colorX ?? defaults.colorX ?? 0.54
  property real colorY: cfg.colorY ?? defaults.colorY ?? 0.32
  property int brightness: cfg.brightness ?? defaults.brightness ?? 100
  property bool triggerOnCamera: cfg.triggerOnCamera ?? defaults.triggerOnCamera ?? true
  property bool triggerOnMic: cfg.triggerOnMic ?? defaults.triggerOnMic ?? false
  property bool toggleDND: cfg.toggleDND ?? defaults.toggleDND ?? true

  // --- Live detection state ---
  property bool camActive: false
  property bool micActive: false
  readonly property bool onAir: (triggerOnCamera && camActive) || (triggerOnMic && micActive)
  property bool _wasOnAir: false

  // Saved Hue state (raw JSON from `openhue get`) captured before going red,
  // persisted so a shell restart mid-call can still restore on call-end.
  property string savedState: ""

  // ---------------------------------------------------------------------------
  // Camera detection: which processes hold an open fd on a /dev/video* capture
  // device (same approach as the privacy-indicator plugin).
  // ---------------------------------------------------------------------------
  Process {
    id: cameraDetectionProcess
    running: false
    command: ["sh", "-c", "for dev in /sys/class/video4linux/video*; do [ -e \"$dev/name\" ] && grep -qv 'Metadata' \"$dev/name\" && dev_name=$(basename \"$dev\") && find /proc/[0-9]*/fd -lname \"/dev/$dev_name\" 2>/dev/null; done | cut -d/ -f3 | xargs -r ps -o comm= -p | sort -u | tr '\\n' ',' | sed 's/,$//'"]
    stdout: StdioCollector {
      onStreamFinished: {
        var s = this.text.trim();
        root.camActive = s.length > 0;
      }
    }
  }

  PwObjectTracker {
    objects: Pipewire.ready ? Pipewire.nodes.values : []
  }

  function hasNodeLinks(node, links) {
    for (var i = 0; i < links.length; i++) {
      var link = links[i];
      if (link && (link.source === node || link.target === node))
        return true;
    }
    return false;
  }

  function updateMicState() {
    if (!Pipewire.ready) {
      root.micActive = false;
      return;
    }
    var nodes = Pipewire.nodes.values || [];
    var links = Pipewire.links.values || [];
    for (var i = 0; i < nodes.length; i++) {
      var node = nodes[i];
      if (!node || !node.isStream || !node.audio || node.isSink || !node.properties)
        continue;
      if (!hasNodeLinks(node, links))
        continue;
      if ((node.properties["media.class"] || "") === "Stream/Input/Audio") {
        if (node.properties["stream.capture.sink"] === "true")
          continue;
        root.micActive = true;
        return;
      }
    }
    root.micActive = false;
  }

  Timer {
    interval: 2000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: {
      cameraDetectionProcess.running = true; // refreshes camActive async
      updateMicState();
    }
  }

  // ---------------------------------------------------------------------------
  // On-air transitions
  // ---------------------------------------------------------------------------
  onOnAirChanged: {
    if (onAir && !_wasOnAir) {
      _wasOnAir = true;
      beginOnAir();
    } else if (!onAir && _wasOnAir) {
      _wasOnAir = false;
      endOnAir();
    }
  }

  function beginOnAir() {
    if (!lightId) {
      Logger.w("OnAirHue", "No lightId configured; skipping");
      return;
    }
    Logger.i("OnAirHue", "On-air: capturing light state then going red");
    setDND(true);
    captureStateProcess.running = true; // on finish -> save + go red
  }

  function endOnAir() {
    Logger.i("OnAirHue", "Off-air: restoring previous light state");
    setDND(false);
    restoreLight();
  }

  // Capture current state, persist it, then turn the light red.
  Process {
    id: captureStateProcess
    running: false
    command: ["openhue", "get", "light", root.lightId, "--json"]
    stdout: StdioCollector {
      onStreamFinished: {
        var txt = this.text.trim();
        if (txt.length > 0) {
          root.savedState = txt;
          persist();
        } else {
          Logger.w("OnAirHue", "Empty state from openhue; will fall back to off on restore");
        }
        goRed();
      }
    }
  }

  function goRed() {
    Quickshell.execDetached(["openhue", "set", "light", root.lightId, "--on", "-x", String(root.colorX), "-y", String(root.colorY), "--brightness", String(root.brightness)]);
  }

  function restoreLight() {
    var hd = null;
    try {
      var parsed = JSON.parse(root.savedState);
      if (Array.isArray(parsed))
        parsed = parsed[0];
      hd = parsed ? (parsed.HueData || parsed) : null;
    } catch (e) {
      Logger.w("OnAirHue", "Could not parse saved state; turning light off as fallback");
    }

    if (!hd) {
      Quickshell.execDetached(["openhue", "set", "light", root.lightId, "--off"]);
      return;
    }

    var wasOn = hd.on && hd.on.on === true;
    if (!wasOn) {
      Quickshell.execDetached(["openhue", "set", "light", root.lightId, "--off"]);
      return;
    }

    var args = ["openhue", "set", "light", root.lightId, "--on"];
    var bri = hd.dimming ? hd.dimming.brightness : undefined;
    if (bri !== undefined && bri !== null)
      args.push("--brightness", String(Math.round(bri)));
    var xy = hd.color ? hd.color.xy : undefined;
    if (xy && xy.x !== undefined && xy.y !== undefined) {
      args.push("-x", String(xy.x), "-y", String(xy.y));
    }
    Quickshell.execDetached(args);
  }

  function setDND(on) {
    if (!toggleDND)
      return;
    // enableDND silences notifications; disableDND restores them.
    Quickshell.execDetached(["qs", "-c", "noctalia-shell", "ipc", "call", "notifications", on ? "enableDND" : "disableDND"]);
  }

  // ---------------------------------------------------------------------------
  // Persist saved Hue state across shell restarts
  // ---------------------------------------------------------------------------
  property bool _ready: false

  Component.onCompleted: Qt.callLater(function () {
    if (typeof Settings !== 'undefined' && Settings.cacheDir) {
      stateFileView.path = Settings.cacheDir + "onair-hue-state.json";
    }
  })

  FileView {
    id: stateFileView
    printErrors: false
    watchChanges: false
    adapter: JsonAdapter {
      id: stateAdapter
      property string saved: ""
    }
    onLoaded: {
      root._ready = true;
      if (stateAdapter.saved)
        root.savedState = stateAdapter.saved;
    }
    onLoadFailed: error => { root._ready = true; }
  }

  function persist() {
    if (!stateFileView.path)
      return;
    stateAdapter.saved = root.savedState;
    try {
      Quickshell.execDetached(["mkdir", "-p", Settings.cacheDir]);
      Qt.callLater(function () {
        try {
          stateFileView.writeAdapter();
        } catch (e) {}
      });
    } catch (e) {}
  }
}
