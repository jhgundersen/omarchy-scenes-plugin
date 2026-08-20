import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Item {
  id: root

  readonly property string backendPath: decodeURIComponent(String(Qt.resolvedUrl("scripts/omarchy-scenes")).replace(/^file:\/\//, ""))
  readonly property string sessionId: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "unknown"
  property bool restorePending: false

  function requestRestore() {
    restorePending = true
    restoreTimer.restart()
  }

  Component.onCompleted: startupProcess.running = true

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event && String(event.name || "") === "configreloaded") root.requestRestore()
    }
  }

  Timer {
    id: restoreTimer
    interval: 700
    repeat: false
    onTriggered: if (!restoreProcess.running) {
      root.restorePending = false
      restoreProcess.running = true
    }
  }

  Process {
    id: startupProcess
    command: [root.backendPath, "startup", root.sessionId]
  }

  Process {
    id: restoreProcess
    command: [root.backendPath, "restore-current"]
    onExited: function(exitCode) {
      if (exitCode === 75) {
        root.requestRestore()
      } else if (root.restorePending) {
        restoreTimer.restart()
      }
    }
  }
}
