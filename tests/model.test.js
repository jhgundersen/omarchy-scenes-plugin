const assert = require("node:assert/strict");
const Model = require("../Model.js");

const displays = [
  { connector: "DP-1", description: "Desk", enabled: true, scale: 1.25 },
  { connector: "HDMI-A-1", description: "TV", enabled: false, scale: 2 }
];

let selected = Model.toggleMonitor([], displays[0]);
assert.equal(selected.length, 1);
assert.equal(selected[0].primary, true);
assert.equal(selected[0].scale, "auto");

selected = Model.toggleMonitor(selected, displays[1]);
assert.equal(selected.length, 2);
assert.equal(selected[1].direction, "right");

selected = Model.setPrimary(selected, "HDMI-A-1");
assert.equal(selected[0].primary, false);
assert.equal(selected[1].primary, true);

selected = Model.updateMonitor(selected, "DP-1", "scale", "1.25");
assert.equal(selected[0].scale, "1.25");

selected = Model.moveMonitor(selected, 1, -1);
assert.equal(selected[0].connector, "HDMI-A-1");

selected = Model.toggleMonitor(selected, displays[1]);
assert.equal(selected.length, 1);
assert.equal(selected[0].primary, true);

const scene = {
  id: "desk",
  name: "Desk",
  icon: "󰇄",
  theme: "Gruvbox",
  monitors: [{ connector: "DP-1", description: "Desk", primary: true, scale: "1.25" }],
  audio: { name: "sink.desk", label: "Desk speakers" }
};

assert.equal(Model.sceneMatches(scene, [displays[0]], "sink.desk", "Gruvbox"), true);
assert.equal(Model.sceneMatches(scene, [displays[0]], "sink.other", "Gruvbox"), false);
assert.equal(Model.sceneMatches(scene, displays, "sink.desk", "Gruvbox"), true, "disabled displays do not affect matching");
assert.equal(Model.activeSceneId([scene], [displays[0]], "sink.desk", "Gruvbox"), "desk");
assert.equal(
  Model.audioSinkMatches(
    "alsa_output.pci-0000_0b_00.1.hdmi-stereo",
    "alsa_output.pci-0000_0b_00.1.hdmi-stereo-extra1"
  ),
  true,
  "PipeWire profiles on the same hardware output match"
);
assert.equal(Model.audioSinkMatches("sink.desk", "sink.other"), false);
assert.match(Model.sceneSummary(scene), /1 display/);
assert.equal(
  Model.sceneSummary({ ...scene, monitors: { 0: scene.monitors[0], length: 1 } }, "Friendly speakers"),
  "1 display · Friendly speakers · Gruvbox",
  "summary supports QML array-like monitor lists and current audio labels"
);
assert.deepEqual(Model.availableScales(["auto", "1", "1.25", "1.6"], displays[0], "1.25"), ["auto", "1", "1.25", "1.6"]);
assert.deepEqual(Model.preferredDimensions({ width: 0, height: 0, availableModes: ["3840x2160@120Hz"] }), { width: 3840, height: 2160 });

console.log("model tests passed");
