# AGENTS.md

This is a simple 2D platform game being developed in Godot 4.

## Requirements

- Godot 4.7 using GDScript and following Godot's own code style guidelines.

## Testing

All **gameplay** testing is manual by the human after every iteration: do not run the main game scene.
The testing device is:

1. Samsung Odyssey laptop running Omarchy Quattro in 1920 x 1080 @ 60 Hz.

## Agent Workflow Notes

- While the agent writes files, keep those files **closed** in the Godot script editor: an open buffer can silently revert external writes on focus/undo/save.
- After every script write, **read the file back from disk** — never trust the write receipt alone.
- `node_set_property` cannot coerce strings to bool/int — set non-string properties in GDScript instead.
- `input_map` calls must be **sequential** (parallel bursts wedge the backend lock); `project_manage settings_set` accepts invalid keys without complaint (verify setting names against engine docs).
- Godot 4 API differs from Godot 3 memory (e.g. `ScrollContainer.horizontal_scroll_mode`). When unsure about a property or method, check the Godot 4.7 docs instead of guessing.
- Editor-log ghosts: the log buffer re-emits stale diagnostics on scans — confirm errors against current file contents (grep) before treating them as live.
- Never reference `EditorInterface` directly from a script that is shipped in a game: editor classes are stripped from export templates and the script then fails to load. Access it only under `Engine.is_editor_hint()` through `Engine.get_singleton(&"EditorInterface")`.
- Godot generates `.gd.uid` sidecars; keep them tracked so scenes and references stay stable.
- Avoid local variables or parameters that shadow existing member variables (GDScript warns on shadowing). If a local/parameter name would collide with a member (e.g. a method parameter named `acceleration` when the class has `@export var acceleration`), rename the local/parameter with a `_` prefix (e.g. `_acceleration`).

## Commit Convention

When there are changes to commit, AI agents should suggest an one-line commit message at the end of their response following conventional commit format: `type(scope): description`. Use types like `feat`, `fix`, `refactor`, `docs`, `chore` and keep descriptions concise but descriptive — focus on the "why" rather than the "what". This message must be in own line to facilitate copying.
