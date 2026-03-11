# imgui-godot Usage (Project Notes)

This file is a project-local usage note for `addons/imgui-godot`.
It focuses on the GDScript workflow used in this project.

## 1. Enable Plugin

1. Copy plugin files under `addons/imgui-godot/`.
2. Enable plugin in Godot: `Project -> Project Settings -> Plugins`.
3. Confirm autoload exists: `ImGuiRoot`.

In this project, `project.godot` already includes:
- `autoload/ImGuiRoot`
- `editor_plugins/enabled` contains `res://addons/imgui-godot/plugin.cfg`

## 2. Safe Call Timing

ImGui API should be called only in:
- `_process`
- `imgui_layout` callback is available in plugin docs, but this project currently uses `_process` as the stable path.

Recommended pattern:

```gdscript
extends Node

var _imgui: Object

func _ready() -> void:
    if Engine.has_singleton("ImGuiAPI"):
        _imgui = Engine.get_singleton("ImGuiAPI")

func _process(_delta: float) -> void:
    if _imgui == null:
        return
    if _imgui.Begin("Debug"):
        _imgui.Text("hello")
    _imgui.End()
```

## 3. GDScript Param Convention

For widgets that modify values by reference, use one-element arrays.

```gdscript
var int_value := [1]
var text_value := ["hello"]
var _imgui: Object

func _ready() -> void:
    if Engine.has_singleton("ImGuiAPI"):
        _imgui = Engine.get_singleton("ImGuiAPI")

func _process(_delta: float) -> void:
    if _imgui == null:
        return
    _imgui.DragInt("difficulty", int_value)
    _imgui.InputText("location_path", text_value, 256)
```

Do not pass temporary literals like `[some_var]`; keep a persistent array field.

## 4. Scene-Owned Debug Panel Pattern

Current project debug panels are scene-owned and do not use a global manager.

Key points:
- Runtime reference by exported `NodePath`.
- Check runtime validity with `is_instance_valid`.
- If runtime is `queue_free()` (for example after retreat), panel should degrade gracefully.
- Keep panel debug-only (`OS.is_debug_build()` gate).
- Optional self-check: enable `show_demo_window` to call `_imgui.ShowDemoWindow()`.

## 5. Export Behavior (Debug / Release)

The plugin export options are:
- `imgui/debug`
- `imgui/release`

Default behavior from plugin exporter:
- Debug export: enabled on desktop platforms.
- Release export: disabled by default.

When disabled for an export preset, the plugin removes ImGui runtime pieces for that export.

## 5.1 Global UI Scale (Font + Widget Size)

This project uses a global ImGui config resource:
- `res://addons/imgui-godot/data/ProjectImGuiConfig.tres`

Project setting:
- `addons/imgui/config = "res://addons/imgui-godot/data/ProjectImGuiConfig.tres"`

To make ImGui larger/smaller for the whole project, edit:
- `Scale` in that resource (for example `1.8`)

## 6. Minimal Troubleshooting

- No window shown:
  - Check plugin is enabled.
  - Check `Engine.has_singleton("ImGuiAPI")` returns true at runtime.
  - Check your drawing call runs in `_process`.
- Input widgets do not update:
  - Verify one-element array pattern is used.
- Build/export mismatch:
  - Check export preset values for `imgui/debug` and `imgui/release`.
