function copy(value) {
  return JSON.parse(JSON.stringify(value))
}

function monitorFor(monitors, connector) {
  var values = Array.isArray(monitors) ? monitors : []
  for (var i = 0; i < values.length; i++) {
    if (String(values[i].connector) === String(connector)) return values[i]
  }
  return null
}

function selectedMonitor(monitors, connector) {
  return monitorFor(monitors, connector) !== null
}

function toggleMonitor(monitors, device) {
  var next = copy(Array.isArray(monitors) ? monitors : [])
  var found = -1
  for (var i = 0; i < next.length; i++) {
    if (String(next[i].connector) === String(device.connector)) { found = i; break }
  }
  if (found >= 0) {
    var removedPrimary = next[found].primary === true
    next.splice(found, 1)
    if (removedPrimary && next.length > 0) next[0].primary = true
    return next
  }
  next.push({
    connector: String(device.connector || ""),
    description: String(device.description || device.connector || ""),
    primary: next.length === 0,
    direction: "right",
    scale: "auto"
  })
  return next
}

function updateMonitor(monitors, connector, key, value) {
  var next = copy(Array.isArray(monitors) ? monitors : [])
  for (var i = 0; i < next.length; i++) {
    if (String(next[i].connector) === String(connector)) next[i][key] = value
  }
  return next
}

function setPrimary(monitors, connector) {
  var next = copy(Array.isArray(monitors) ? monitors : [])
  for (var i = 0; i < next.length; i++) next[i].primary = String(next[i].connector) === String(connector)
  return next
}

function moveMonitor(monitors, index, delta) {
  var next = copy(Array.isArray(monitors) ? monitors : [])
  var target = index + delta
  if (index < 0 || index >= next.length || target < 0 || target >= next.length) return next
  var item = next[index]
  next.splice(index, 1)
  next.splice(target, 0, item)
  return next
}

function preferredDimensions(device) {
  if (!device) return { width: 0, height: 0 }
  if (Number(device.width) > 0 && Number(device.height) > 0)
    return { width: Number(device.width), height: Number(device.height) }
  var modes = Array.isArray(device.availableModes) ? device.availableModes : []
  var match = modes.length > 0 ? String(modes[0]).match(/^(\d+)x(\d+)/) : null
  return match ? { width: Number(match[1]), height: Number(match[2]) } : { width: 0, height: 0 }
}

function availableScales(scales, device, current) {
  var values = Array.isArray(scales) ? scales : []
  var dimensions = preferredDimensions(device)
  var result = []
  for (var i = 0; i < values.length; i++) {
    var value = String(values[i])
    if (value === "auto") { result.push(value); continue }
    var scale = Number(value)
    if (dimensions.width <= 0 || dimensions.height <= 0
        || (Number.isInteger(dimensions.width / scale) && Number.isInteger(dimensions.height / scale)))
      result.push(value)
  }
  if (current && result.indexOf(String(current)) < 0) result.push(String(current))
  return result
}

function sceneSummary(scene) {
  if (!scene) return ""
  var monitors = Array.isArray(scene.monitors) ? scene.monitors : []
  var display = monitors.length === 1 ? "1 display" : monitors.length + " displays"
  var audio = scene.audio && scene.audio.label ? String(scene.audio.label) : "No audio"
  var theme = scene.theme ? String(scene.theme) : "current theme"
  return display + " · " + audio + " · " + theme
}

function sceneMatches(scene, liveMonitors, currentSink, currentTheme) {
  if (!scene) return false
  var saved = Array.isArray(scene.monitors) ? scene.monitors : []
  var live = (Array.isArray(liveMonitors) ? liveMonitors : []).filter(function(m) { return m.enabled === true })
  if (saved.length !== live.length) return false
  for (var i = 0; i < saved.length; i++) {
    var match = monitorFor(live, saved[i].connector)
    if (!match && saved[i].description) {
      var matches = live.filter(function(m) { return String(m.description) === String(saved[i].description) })
      match = matches.length === 1 ? matches[0] : null
    }
    if (!match) return false
    if (String(saved[i].scale) !== "auto" && Math.abs(Number(saved[i].scale) - Number(match.scale)) > 0.01) return false
  }
  if (!scene.audio || String(scene.audio.name) !== String(currentSink || "")) return false
  if (scene.theme && String(scene.theme).toLowerCase() !== String(currentTheme || "").toLowerCase()) return false
  return true
}

function activeSceneId(scenes, liveMonitors, currentSink, currentTheme) {
  var values = Array.isArray(scenes) ? scenes : []
  for (var i = 0; i < values.length; i++) {
    if (sceneMatches(values[i], liveMonitors, currentSink, currentTheme)) return String(values[i].id)
  }
  return ""
}

if (typeof module !== "undefined") {
  module.exports = {
    monitorFor: monitorFor,
    selectedMonitor: selectedMonitor,
    toggleMonitor: toggleMonitor,
    updateMonitor: updateMonitor,
    setPrimary: setPrimary,
    moveMonitor: moveMonitor,
    preferredDimensions: preferredDimensions,
    availableScales: availableScales,
    sceneSummary: sceneSummary,
    sceneMatches: sceneMatches,
    activeSceneId: activeSceneId
  }
}
