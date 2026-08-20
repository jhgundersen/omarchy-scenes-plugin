#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
MOCKS="$TMP/mocks"
mkdir -p "$MOCKS" "$TMP/config" "$TMP/state" "$TMP/runtime"
LOG="$TMP/commands.log"
: >"$LOG"

cat >"$TMP/monitors.json" <<'JSON'
[
  {"name":"DP-1","description":"Desk","disabled":false,"focused":true,"x":0,"y":0,"width":2560,"height":1440,"refreshRate":165,"scale":1.25,"transform":0,"availableModes":["2560x1440@165Hz"]},
  {"name":"HDMI-A-1","description":"TV","disabled":false,"focused":false,"x":2048,"y":0,"width":1920,"height":1080,"refreshRate":120,"scale":1,"transform":0,"availableModes":["1920x1080@120Hz"]}
]
JSON

cat >"$MOCKS/hyprctl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'hyprctl %s\n' "$*" >>"$MOCK_LOG"
case "$*" in
  "monitors all -j") cat "$MOCK_MONITORS" ;;
  "monitors -j") jq '[.[] | select(.disabled == false)]' "$MOCK_MONITORS" ;;
  "workspaces -j") printf '%s\n' '[{"id":1,"name":"1","monitor":"DP-1"},{"id":2,"name":"2","monitor":"HDMI-A-1"}]' ;;
  "activeworkspace -j") printf '%s\n' '{"id":1,"name":"1","monitor":"DP-1"}' ;;
esac
SH

cat >"$MOCKS/pactl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'pactl %s\n' "$*" >>"$MOCK_LOG"
if [[ $* == "-f json list sinks" ]]; then
  if [[ ${MOCK_SINKS+x} ]]; then
    printf '%s\n' "$MOCK_SINKS"
  else
    printf '%s\n' '[{"index":34,"name":"sink.desk","description":"Built-in Audio Desk speakers Output","properties":{"node.nick":"Desk speakers Output"}}]'
  fi
elif [[ $* == "get-default-sink" ]]; then
  printf '%s\n' 'sink.desk'
fi
SH

cat >"$MOCKS/omarchy" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'omarchy %s\n' "$*" >>"$MOCK_LOG"
case "$*" in
  "theme list") printf '%s\n' Gruvbox 'Tokyo Night' ;;
  "theme current") printf '%s\n' Gruvbox ;;
esac
SH

cat >"$MOCKS/audio-set" <<'SH'
#!/usr/bin/env bash
printf 'audio-set %s\n' "$*" >>"$MOCK_LOG"
SH

cat >"$MOCKS/notify" <<'SH'
#!/usr/bin/env bash
printf 'notify %s\n' "$*" >>"$MOCK_LOG"
SH
chmod +x "$MOCKS"/*

export XDG_CONFIG_HOME="$TMP/config"
export XDG_STATE_HOME="$TMP/state"
export XDG_RUNTIME_DIR="$TMP/runtime"
export OMARCHY_SCENES_HYPRCTL="$MOCKS/hyprctl"
export OMARCHY_SCENES_PACTL="$MOCKS/pactl"
export OMARCHY_SCENES_OMARCHY="$MOCKS/omarchy"
export OMARCHY_SCENES_AUDIO_SET="$MOCKS/audio-set"
export OMARCHY_SCENES_NOTIFY="$MOCKS/notify"
export MOCK_LOG="$LOG"
export MOCK_MONITORS="$TMP/monitors.json"

SCENES="$ROOT/scripts/omarchy-scenes"

$SCENES status | jq -e '.sinks[0].label == "Desk speakers"' >/dev/null

scene='{"id":"","name":"Desk","theme":"Gruvbox","monitors":[{"connector":"DP-1","description":"Desk","primary":true,"scale":"1.25"}],"audio":{"name":"sink.desk","label":"Desk speakers"}}'
id=$($SCENES save "$scene")
[[ -n $id ]]
jq -e --arg id "$id" '.scenes[0].id == $id and .scenes[0].name == "Desk"' "$XDG_CONFIG_HOME/omarchy/scenes.json" >/dev/null
jq -e '.scenes[0].icon == "󰍹"' "$XDG_CONFIG_HOME/omarchy/scenes.json" >/dev/null

if $SCENES save "$scene" >/dev/null 2>&1; then
  echo "duplicate scene name was accepted" >&2
  exit 1
fi

$SCENES apply "$id"
grep -F 'hyprctl eval hl.monitor({ output = "DP-1", mode = "preferred", position = "auto-right", scale = 1.25, disabled = false })' "$LOG" >/dev/null
grep -F 'hyprctl eval hl.monitor({ output = "DP-1", mode = "preferred", position = "0x0", scale = 1.25, disabled = false })' "$LOG" >/dev/null
grep -F 'hyprctl eval hl.dispatch(hl.dsp.focus({ workspace = "1" }))' "$LOG" >/dev/null
grep -F 'hyprctl eval hl.monitor({ output = "HDMI-A-1", disabled = true })' "$LOG" >/dev/null
grep -F 'audio-set 34 sink.desk' "$LOG" >/dev/null
jq -e --arg id "$id" '.lastSceneId == $id' "$XDG_STATE_HOME/omarchy-scenes/state.json" >/dev/null

multi='{"id":"multi","name":"Studio","icon":"󰎆","theme":"Tokyo Night","monitors":[{"connector":"DP-1","description":"Desk","primary":true,"scale":"1.25"},{"connector":"HDMI-A-1","description":"TV","primary":false,"direction":"right","scale":"1"}],"audio":{"name":"sink.desk","label":"Desk speakers"}}'
$SCENES save "$multi" >/dev/null
jq -e '.scenes[] | select(.id == "multi") | .icon == "󰎆"' "$XDG_CONFIG_HOME/omarchy/scenes.json" >/dev/null
: >"$LOG"
$SCENES apply multi
grep -F 'omarchy theme set Tokyo Night' "$LOG" >/dev/null
grep -F 'hyprctl eval hl.monitor({ output = "DP-1", mode = "preferred", position = "0x0", scale = 1.25, disabled = false })' "$LOG" >/dev/null
grep -F 'hyprctl eval hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "auto-right", scale = 1, disabled = false })' "$LOG" >/dev/null
theme_line=$(grep -nF 'omarchy theme set Tokyo Night' "$LOG" | cut -d: -f1)
monitor_line=$(grep -nF 'hyprctl eval hl.monitor({ output = "DP-1", mode = "preferred", position = "0x0", scale = 1.25, disabled = false })' "$LOG" | cut -d: -f1)
(( theme_line < monitor_line ))

missing='{"id":"missing","name":"Missing","theme":null,"monitors":[{"connector":"DP-9","description":"Gone","primary":true,"scale":"auto"}],"audio":{"name":"sink.desk","label":"Desk speakers"}}'
$SCENES save "$missing" >/dev/null
: >"$LOG"
if $SCENES apply missing >/dev/null 2>&1; then
  echo "missing display scene applied" >&2
  exit 1
fi
if grep -F 'hl.monitor' "$LOG" >/dev/null; then
  echo "display changed after failed preflight" >&2
  exit 1
fi

partial='{"id":"partial","name":"Partial","theme":null,"monitors":[{"connector":"DP-1","description":"Desk","primary":true,"scale":"auto"}],"audio":{"name":"sink.missing","label":"Missing"}}'
$SCENES save "$partial" >/dev/null
set +e
OMARCHY_SCENES_PACTL="$MOCKS/pactl" MOCK_SINKS='[]' $SCENES apply partial >/dev/null 2>&1
partial_status=$?
set -e
[[ $partial_status -eq 3 ]]
jq -e '.lastSceneId == "partial"' "$XDG_STATE_HOME/omarchy-scenes/state.json" >/dev/null

alias_scene='{"id":"alias","name":"Alias","theme":null,"monitors":[{"connector":"DP-1","description":"Desk","primary":true,"scale":"auto"}],"audio":{"name":"alsa_output.pci-0000_0b_00.1.hdmi-stereo","label":"Display audio"}}'
$SCENES save "$alias_scene" >/dev/null
: >"$LOG"
MOCK_SINKS='[{"index":98,"name":"alsa_output.pci-0000_0b_00.1.hdmi-stereo-extra1","description":"HDMI 2"}]' $SCENES apply alias
grep -F 'audio-set 98 alsa_output.pci-0000_0b_00.1.hdmi-stereo-extra1' "$LOG" >/dev/null

$SCENES delete "$id"
jq -e --arg id "$id" 'all(.scenes[]; .id != $id)' "$XDG_CONFIG_HOME/omarchy/scenes.json" >/dev/null

echo "backend tests passed"
