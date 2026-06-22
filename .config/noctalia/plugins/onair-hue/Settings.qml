import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property string lightId: cfg.lightId ?? defaults.lightId ?? ""
  property real colorX: cfg.colorX ?? defaults.colorX ?? 0.54
  property real colorY: cfg.colorY ?? defaults.colorY ?? 0.32
  property int brightness: cfg.brightness ?? defaults.brightness ?? 100
  property bool triggerOnCamera: cfg.triggerOnCamera ?? defaults.triggerOnCamera ?? true
  property bool triggerOnMic: cfg.triggerOnMic ?? defaults.triggerOnMic ?? false
  property bool toggleDND: cfg.toggleDND ?? defaults.toggleDND ?? true

  spacing: Style.marginL

  ColumnLayout {
    spacing: Style.marginM
    Layout.fillWidth: true

    NTextInput {
      Layout.fillWidth: true
      label: "Hue light ID"
      description: "UUID of the light to flip red while on-air (from `openhue get lights`)."
      placeholderText: "00000000-0000-0000-0000-000000000000"
      text: root.lightId
      onTextChanged: root.lightId = text
    }

    NToggle {
      label: "Trigger on camera"
      description: "Go on-air when a camera is in use."
      checked: root.triggerOnCamera
      onToggled: checked => root.triggerOnCamera = checked
    }

    NToggle {
      label: "Trigger on microphone"
      description: "Also go on-air when the microphone is in use."
      checked: root.triggerOnMic
      onToggled: checked => root.triggerOnMic = checked
    }

    NToggle {
      label: "Toggle Do Not Disturb"
      description: "Silence notifications while on-air."
      checked: root.toggleDND
      onToggled: checked => root.toggleDND = checked
    }

    NTextInput {
      Layout.fillWidth: true
      label: "On-air color X"
      description: "CIE xy X coordinate (0.54 ≈ red)."
      text: String(root.colorX)
      onTextChanged: root.colorX = text
    }

    NTextInput {
      Layout.fillWidth: true
      label: "On-air color Y"
      description: "CIE xy Y coordinate (0.32 ≈ red)."
      text: String(root.colorY)
      onTextChanged: root.colorY = text
    }

    NTextInput {
      Layout.fillWidth: true
      label: "On-air brightness"
      description: "Brightness 0–100 while on-air."
      text: String(root.brightness)
      onTextChanged: root.brightness = text
    }
  }

  function saveSettings() {
    if (!pluginApi) {
      Logger.e("OnAirHue", "Cannot save settings: pluginApi is null");
      return;
    }
    pluginApi.pluginSettings.lightId = root.lightId;
    pluginApi.pluginSettings.triggerOnCamera = root.triggerOnCamera;
    pluginApi.pluginSettings.triggerOnMic = root.triggerOnMic;
    pluginApi.pluginSettings.toggleDND = root.toggleDND;
    pluginApi.pluginSettings.colorX = parseFloat(root.colorX) || 0.54;
    pluginApi.pluginSettings.colorY = parseFloat(root.colorY) || 0.32;
    pluginApi.pluginSettings.brightness = parseInt(root.brightness) || 100;
    pluginApi.saveSettings();
    Logger.i("OnAirHue", "Settings saved");
  }
}
