# AGENTS.md

## Project

Omarchy Scenes is a third-party Omarchy bar plugin for saving and applying named display, audio, and theme combinations.

The source repository is `/home/jonh/jonh.no/omarchy-scenes-plugin`. Treat it as authoritative. Do not edit the installed checkout under `~/.config/omarchy/plugins/jhgundersen.scenes` directly; publish source changes and install them with `omarchy plugin update jhgundersen.scenes --yes`.

## Architecture

- `manifest.json` declares the `jhgundersen.scenes` bar widget. Keep the third-party namespace; `omarchy.*` is reserved.
- `Panel.qml` owns the native Omarchy panel, editor, keyboard behavior, process orchestration, and IPC target.
- `Model.js` contains side-effect-free UI and active-scene logic. Keep functions compatible with both QML JavaScript and Node tests.
- `scripts/omarchy-scenes` owns persistence, hardware discovery, validation, scene application, rollback, notifications, and locking.
- User scenes live in `~/.config/omarchy/scenes.json`; runtime cycle state lives under `$XDG_STATE_HOME/omarchy-scenes/`. Never store user state in the plugin checkout.

## Omarchy and QML Conventions

- Follow current components and interaction patterns in `/usr/share/omarchy/shell/Ui` and `/usr/share/omarchy/shell/plugins/panels` without modifying packaged files.
- A `PanelKeyCatcher` containing interactive controls must remain enabled. Set its `blocked` property while an editor or dropdown owns input; disabling it disables its entire child tree.
- Preserve mouse and keyboard access. New controls must be focusable and usable with normal Tab, Enter, Space, and Escape behavior.
- Use `Process.command` arrays rather than shell command strings when passing user-controlled values.
- Keep the IPC target `jhgundersen.scenes` compatible with `open`, `close`, `toggle`, `next`, and `apply(sceneId)`.
- Keep display modes at `preferred` unless a feature explicitly adds mode selection. Supported scene scales are `auto`, `1`, `1.25`, `1.6`, `2`, `3`, and `4`.

## Safety Invariants

- Preflight every required display and optional theme before changing live state.
- Apply a changed theme before the final monitor layout because Omarchy theme changes reload Hyprland.
- Enable and verify all selected displays before disabling any unselected display.
- Preserve workspaces already on selected displays and move only workspaces from displays being disabled to the scene primary.
- On display failure, make a best-effort restoration of the previous layout.
- If audio is unavailable after a display change, retain the display/theme result, leave the current audio sink unchanged, and report a partial failure.
- Serialize mutations with the existing non-blocking lock and write config/state files atomically.
- Do not modify `~/.config/hypr`, delete the legacy toggle script, or replace user keybindings as a side effect of plugin installation or tests.

## Validation

Run all of these before committing:

```bash
bash -n scripts/omarchy-scenes tests/backend.test.sh
node tests/model.test.js
tests/backend.test.sh
qmllint -I /usr/share/omarchy/shell Panel.qml
omarchy plugin validate .
git diff --check
```

Backend tests must use the provided environment-variable command overrides and temporary XDG directories. Never let tests call the real `hyprctl keyword`, `omarchy theme set`, or audio mutation commands.

When changing behavior, add or update a regression test. For focus and QML interaction bugs that cannot be exercised headlessly, keep the structural cause explicit in `Panel.qml` and manually verify the installed panel after updating it.

## Release Workflow

1. Make and validate changes in the source repository.
2. Commit to `main` with a focused message.
3. Push `origin/main`.
4. Run `omarchy plugin update jhgundersen.scenes --yes`.
5. Verify the installed checkout is clean and its IPC target loads.

Do not rewrite published history or commit user scene data.
