import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "Model.js" as Model

Panel {
  id: root
  moduleName: "jhgundersen.scenes"
  ipcTarget: "jhgundersen.scenes"
  manageIpc: false

  readonly property string backendPath: decodeURIComponent(String(Qt.resolvedUrl("scripts/omarchy-scenes")).replace(/^file:\/\//, ""))
  readonly property var scaleOptions: ["auto", "1", "1.25", "1.6", "2", "3", "4"]
  readonly property var directionOptions: [
    { value: "left", label: "Left" },
    { value: "right", label: "Right" },
    { value: "up", label: "Above" },
    { value: "down", label: "Below" }
  ]

  property var scenes: []
  property var monitors: []
  property var sinks: []
  property var themes: []
  property string currentTheme: ""
  property string currentSink: ""
  property string lastSceneId: ""
  property string activeSceneId: ""
  property bool busy: false
  property string errorText: ""
  property int selectedSceneIndex: 0
  property bool cursorActive: false

  property bool editing: false
  property string draftId: ""
  property string draftName: ""
  property string draftTheme: ""
  property var draftMonitors: []
  property string draftAudioName: ""
  property string pendingDeleteId: ""

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function applyStatus(raw) {
    try {
      var value = JSON.parse(String(raw || "{}"))
      scenes = Array.isArray(value.scenes) ? value.scenes : []
      monitors = Array.isArray(value.monitors) ? value.monitors : []
      sinks = Array.isArray(value.sinks) ? value.sinks : []
      themes = Array.isArray(value.themes) ? value.themes : []
      currentTheme = String(value.currentTheme || "")
      currentSink = String(value.currentSink || "")
      lastSceneId = String(value.lastSceneId || "")
      activeSceneId = Model.activeSceneId(scenes, monitors, currentSink, currentTheme)
      if (selectedSceneIndex >= scenes.length) selectedSceneIndex = Math.max(0, scenes.length - 1)
      errorText = ""
    } catch (e) {
      errorText = "Could not read scene state"
    }
  }

  function sceneById(id) {
    for (var i = 0; i < scenes.length; i++) if (String(scenes[i].id) === String(id)) return scenes[i]
    return null
  }

  function activeSceneName() {
    var scene = sceneById(activeSceneId)
    return scene ? String(scene.name || "") : ""
  }

  function monitorByConnector(connector) {
    return Model.monitorFor(monitors, connector)
  }

  function sinkLabel(name) {
    for (var i = 0; i < sinks.length; i++) if (String(sinks[i].name) === String(name)) return String(sinks[i].label)
    return name
  }

  function themeOptions() {
    var values = [{ value: "", label: "Keep current theme" }]
    for (var i = 0; i < themes.length; i++) values.push({ value: String(themes[i]), label: String(themes[i]) })
    return values
  }

  function audioOptions() {
    var values = []
    for (var i = 0; i < sinks.length; i++) values.push({ value: String(sinks[i].name), label: String(sinks[i].label) })
    if (draftAudioName !== "" && sinkLabel(draftAudioName) === draftAudioName)
      values.unshift({ value: draftAudioName, label: draftAudioName + " (unavailable)" })
    return values
  }

  function startCreate() {
    editing = true
    draftId = ""
    draftName = ""
    draftTheme = ""
    draftMonitors = []
    draftAudioName = currentSink || (sinks.length > 0 ? String(sinks[0].name) : "")
    pendingDeleteId = ""
  }

  function startEdit(scene) {
    if (!scene) return
    editing = true
    draftId = String(scene.id || "")
    draftName = String(scene.name || "")
    draftTheme = String(scene.theme || "")
    draftMonitors = JSON.parse(JSON.stringify(scene.monitors || []))
    draftAudioName = String(scene.audio && scene.audio.name || "")
    pendingDeleteId = ""
  }

  function cancelEdit() {
    editing = false
    pendingDeleteId = ""
    errorText = ""
  }

  function toggleDraftMonitor(device) {
    draftMonitors = Model.toggleMonitor(draftMonitors, device)
  }

  function draftMonitor(connector) {
    return Model.monitorFor(draftMonitors, connector)
  }

  function setDraftPrimary(connector) {
    draftMonitors = Model.setPrimary(draftMonitors, connector)
  }

  function setDraftMonitorValue(connector, key, value) {
    draftMonitors = Model.updateMonitor(draftMonitors, connector, key, value)
  }

  function scaleOptionsFor(connector, current) {
    return Model.availableScales(scaleOptions, monitorByConnector(connector), current)
  }

  function moveDraftMonitor(index, delta) {
    draftMonitors = Model.moveMonitor(draftMonitors, index, delta)
  }

  function saveDraft() {
    var name = draftName.trim()
    if (name === "") { errorText = "Give the scene a name"; return }
    if (draftMonitors.length === 0) { errorText = "Select at least one display"; return }
    if (draftAudioName === "") { errorText = "Select an audio output"; return }

    var primaryCount = 0
    for (var i = 0; i < draftMonitors.length; i++) if (draftMonitors[i].primary === true) primaryCount++
    if (primaryCount !== 1) { errorText = "Choose one primary display"; return }

    var payload = {
      id: draftId,
      name: name,
      theme: draftTheme === "" ? null : draftTheme,
      monitors: draftMonitors,
      audio: { name: draftAudioName, label: sinkLabel(draftAudioName) }
    }
    mutationProc.command = [backendPath, "save", JSON.stringify(payload)]
    busy = true
    errorText = ""
    mutationProc.running = true
  }

  function applyScene(id) {
    if (busy || !id) return
    actionProc.command = [backendPath, "apply", String(id)]
    busy = true
    errorText = ""
    actionProc.running = true
  }

  function applyNext() {
    if (busy) return
    actionProc.command = [backendPath, "next"]
    busy = true
    errorText = ""
    actionProc.running = true
  }

  function deleteScene(id) {
    if (pendingDeleteId !== id) { pendingDeleteId = id; return }
    mutationProc.command = [backendPath, "delete", String(id)]
    busy = true
    mutationProc.running = true
  }

  function moveSceneCursor(delta) {
    if (scenes.length === 0) return
    selectedSceneIndex = (selectedSceneIndex + delta + scenes.length) % scenes.length
  }

  IpcHandler {
    target: "jhgundersen.scenes"
    function open() { root.open() }
    function close() { root.close() }
    function toggle() { root.toggle() }
    function next(): string { root.applyNext(); return "ok" }
    function apply(sceneId: string): string { root.applyScene(sceneId); return "ok" }
  }

  Component.onCompleted: refresh()
  onOpenedChanged: if (opened) refresh()

  Timer {
    interval: 5000
    running: root.opened && !root.editing
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProc
    command: [root.backendPath, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyStatus(text)
    }
  }

  Process {
    id: mutationProc
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (String(text || "").trim() !== "") root.errorText = String(text).trim()
    }
    onExited: function(exitCode) {
      root.busy = false
      if (exitCode === 0) root.editing = false
      root.pendingDeleteId = ""
      root.refresh()
    }
  }

  Process {
    id: actionProc
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (String(text || "").trim() !== "") root.errorText = String(text).trim()
    }
    onExited: function(exitCode) {
      root.busy = false
      root.refresh()
    }
  }

  implicitWidth: barButton.implicitWidth
  implicitHeight: barButton.implicitHeight

  BarIconButton {
    id: barButton
    anchors.fill: parent
    bar: root.bar
    text: root.busy ? "󰦖" : "󰍹"
    tooltipText: root.activeSceneId ? "Scene: " + root.activeSceneName() : "Scenes"
    onPressed: function(button) { root.toggle() }
    onWheelMoved: function(delta) { if (delta !== 0) root.applyNext() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: barButton
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight, Style.space(650))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      enabled: !root.editing
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dy !== 0) root.moveSceneCursor(dy)
      }
      onActivateRequested: {
        if (root.cursorActive && root.selectedSceneIndex < root.scenes.length)
          root.applyScene(root.scenes[root.selectedSceneIndex].id)
      }
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: contentColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

        Column {
          id: contentColumn
          width: scrollArea.availableWidth
          spacing: Style.space(14)

          PanelHero {
            title: root.editing ? (root.draftId ? "Edit scene" : "New scene") : "Scenes"
            meta: root.editing ? "DISPLAY · AUDIO · THEME" : (root.activeSceneId ? "ACTIVE · " + root.activeSceneName() : "NO MATCHING SCENE")
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            iconComponent: Component {
              Text {
                text: "󰍹"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.display
              }
            }
          }

          Text {
            visible: root.errorText !== ""
            width: parent.width
            wrapMode: Text.Wrap
            text: root.errorText
            color: Color.urgent
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          Column {
            visible: !root.editing
            width: parent.width
            spacing: Style.space(8)

            Repeater {
              model: root.scenes
              delegate: Row {
                required property var modelData
                required property int index
                width: contentColumn.width
                spacing: Style.space(6)

                Button {
                  width: Math.max(0, parent.width - editButton.width - deleteButton.width - parent.spacing * 2)
                  text: String(modelData.name)
                  iconText: root.activeSceneId === String(modelData.id) ? "●" : "○"
                  leftAlign: true
                  bordered: true
                  active: root.activeSceneId === String(modelData.id)
                  hasCursor: root.cursorActive && root.selectedSceneIndex === index
                  focusable: true
                  foreground: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                  tooltipText: Model.sceneSummary(modelData)
                  onClicked: root.applyScene(modelData.id)
                  onHovered: function(value) { if (value) { root.cursorActive = true; root.selectedSceneIndex = index } }
                }

                Button {
                  id: editButton
                  text: "Edit"
                  bordered: true
                  focusable: true
                  foreground: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                  onClicked: root.startEdit(modelData)
                }

                Button {
                  id: deleteButton
                  text: root.pendingDeleteId === String(modelData.id) ? "Confirm" : "Delete"
                  bordered: true
                  focusable: true
                  foreground: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                  onClicked: root.deleteScene(String(modelData.id))
                }
              }
            }

            Text {
              visible: root.scenes.length === 0
              width: parent.width
              text: "No scenes yet. Create one from the displays and outputs available now."
              wrapMode: Text.Wrap
              color: Qt.darker(root.bar.foreground, 1.35)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.body
            }

            Button {
              width: parent.width
              text: "Add scene"
              iconText: "+"
              bordered: true
              focusable: true
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              onClicked: root.startCreate()
            }
          }

          Column {
            visible: root.editing
            width: parent.width
            spacing: Style.space(12)

            PanelSectionHeader { text: "NAME"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily }
            TextField {
              width: parent.width
              text: root.draftName
              placeholderText: "Desk, Couch, Presentation…"
              foreground: root.bar.foreground
              font.family: root.bar.fontFamily
              onTextChanged: root.draftName = text
            }

            PanelSeparator { foreground: root.bar.foreground }
            PanelSectionHeader { text: "THEME"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily }
            Dropdown {
              width: parent.width
              showLabel: false
              value: root.draftTheme
              options: root.themeOptions()
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              onChanged: function(value) { root.draftTheme = value }
            }

            PanelSeparator { foreground: root.bar.foreground }
            PanelSectionHeader { text: "DISPLAYS"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily }

            Repeater {
              model: root.monitors
              delegate: Button {
                required property var modelData
                width: contentColumn.width
                text: String(modelData.description || modelData.connector)
                iconText: Model.selectedMonitor(root.draftMonitors, modelData.connector) ? "✓" : "+"
                leftAlign: true
                bordered: true
                selected: Model.selectedMonitor(root.draftMonitors, modelData.connector)
                focusable: true
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                tooltipText: String(modelData.connector)
                onClicked: root.toggleDraftMonitor(modelData)
              }
            }

            Repeater {
              model: root.draftMonitors
              delegate: Column {
                required property var modelData
                required property int index
                width: contentColumn.width
                spacing: Style.space(6)

                Row {
                  width: parent.width
                  spacing: Style.space(6)
                  Text {
                    width: Math.max(0, parent.width - primaryButton.width - upButton.width - downButton.width - parent.spacing * 3)
                    text: String(modelData.description || modelData.connector)
                    elide: Text.ElideRight
                    color: root.bar.foreground
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.body
                    anchors.verticalCenter: parent.verticalCenter
                  }
                  Button {
                    id: primaryButton
                    text: "Primary"
                    selected: modelData.primary === true
                    bordered: true
                    focusable: true
                    foreground: root.bar.foreground
                    fontFamily: root.bar.fontFamily
                    onClicked: root.setDraftPrimary(modelData.connector)
                  }
                  Button {
                    id: upButton
                    text: "↑"
                    bordered: true
                    focusable: true
                    foreground: root.bar.foreground
                    fontFamily: root.bar.fontFamily
                    onClicked: root.moveDraftMonitor(index, -1)
                  }
                  Button {
                    id: downButton
                    text: "↓"
                    bordered: true
                    focusable: true
                    foreground: root.bar.foreground
                    fontFamily: root.bar.fontFamily
                    onClicked: root.moveDraftMonitor(index, 1)
                  }
                }

                Row {
                  width: parent.width
                  spacing: Style.space(8)
                  Dropdown {
                    width: (parent.width - parent.spacing) / 2
                    label: "Scale"
                    value: String(modelData.scale || "auto")
                    options: root.scaleOptionsFor(modelData.connector, modelData.scale)
                    foreground: root.bar.foreground
                    fontFamily: root.bar.fontFamily
                    onChanged: function(value) { root.setDraftMonitorValue(modelData.connector, "scale", value) }
                  }
                  Dropdown {
                    width: (parent.width - parent.spacing) / 2
                    label: "Position"
                    visible: modelData.primary !== true
                    value: String(modelData.direction || "right")
                    options: root.directionOptions
                    foreground: root.bar.foreground
                    fontFamily: root.bar.fontFamily
                    onChanged: function(value) { root.setDraftMonitorValue(modelData.connector, "direction", value) }
                  }
                }
              }
            }

            PanelSeparator { foreground: root.bar.foreground }
            PanelSectionHeader { text: "AUDIO OUTPUT"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily }
            Dropdown {
              width: parent.width
              showLabel: false
              value: root.draftAudioName
              options: root.audioOptions()
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              onChanged: function(value) { root.draftAudioName = value }
            }

            Row {
              width: parent.width
              spacing: Style.space(8)
              Button {
                width: (parent.width - parent.spacing) / 2
                text: "Cancel"
                bordered: true
                focusable: true
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                onClicked: root.cancelEdit()
              }
              Button {
                width: (parent.width - parent.spacing) / 2
                text: root.busy ? "Saving…" : "Save scene"
                bordered: true
                active: true
                focusable: true
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                onClicked: if (!root.busy) root.saveDraft()
              }
            }
          }
        }
      }
    }
  }
}
