# Omarchy Scenes

Scenes is an [Omarchy](https://omarchy.org/) bar plugin for switching a group of desktop settings together. A scene can select one or more displays, choose the scale and position of each display, move displaced workspaces to a primary display, select an audio output, and optionally apply an Omarchy theme.

## Install

Once this repository is published:

```bash
omarchy plugin add https://github.com/jhgundersen/omarchy-scenes-plugin.git --enable
```

During local development, clone or copy the repository to `~/.config/omarchy/plugins/jhgundersen.scenes`, then run:

```bash
omarchy plugin validate ~/.config/omarchy/plugins/jhgundersen.scenes
omarchy-shell shell rescanPlugins
omarchy plugin enable jhgundersen.scenes --section right
```

Omarchy plugins execute as your user. Review third-party plugin code before enabling it.

## Shortcut

The plugin does not edit Hyprland configuration automatically. Check that the suggested shortcut is free:

```bash
omarchy menu keybindings --print
```

Then add this to `~/.config/hypr/bindings.lua`:

```lua
o.bind(
  "SUPER + CTRL + ALT + S",
  "Next scene",
  "omarchy-shell jhgundersen.scenes next"
)
```

After changing a Hyprland Lua file, validate it with:

```bash
hyprctl reload
hyprctl configerrors
```

The IPC target also provides `open`, `close`, `toggle`, `next`, and `apply <scene-id>`:

```bash
omarchy-shell jhgundersen.scenes toggle
omarchy-shell jhgundersen.scenes next
```

## Using scenes

Click the display icon in the bar and choose **Add scene**. A scene requires:

- A unique name.
- One or more connected displays.
- Exactly one primary display.
- A scale for every display.
- A direction for each secondary display.
- An audio output.
- Optionally, an installed Omarchy theme.

The primary display is placed at `0x0`. Secondary displays use Hyprland's automatic left, right, above, or below placement in the order shown in the editor. Displays outside the scene are disabled.

Before applying anything, Scenes verifies that all saved displays and the optional theme are available. It applies a changed theme before the monitor layout because Omarchy's theme command reloads Hyprland. Workspaces already on selected displays remain there; workspaces on displays being disabled move to the primary display.

Some HDMI audio outputs only appear after their display is enabled. Scenes waits briefly for the saved output. If it remains unavailable, the display and theme changes stay applied, the previous audio output remains selected, and a notification explains the partial result.

## Configuration

Scenes writes user configuration atomically to:

```text
~/.config/omarchy/scenes.json
```

Runtime cycling state is kept in:

```text
${XDG_STATE_HOME:-~/.local/state}/omarchy-scenes/state.json
```

The plugin repository itself remains clean, so `omarchy plugin update` can fast-forward it normally.

## Development

Requirements are already part of a normal Omarchy installation: Bash, jq, Hyprland, PipeWire/PulseAudio compatibility tools, Quickshell, and the Omarchy CLI.

```bash
omarchy plugin validate .
qmllint -I /usr/share/omarchy/shell Panel.qml
node tests/model.test.js
tests/backend.test.sh
```

V1 intentionally keeps each monitor at its preferred mode. Exact resolution and refresh-rate selection, rotation, mirroring, and automatic login application are not included yet.
