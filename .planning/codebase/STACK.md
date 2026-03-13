# Technology Stack

**Analysis Date:** 2026-03-13

## Languages

**Primary:**
- GDScript (Godot 4.x syntax) - Core gameplay and systems in `src/**/*.gd` and `scenes/**/*.gd`.

**Secondary:**
- C# - ImGui bridge implementation in `addons/imgui-godot/ImGuiGodot/**/*.cs`.
- JSON (runtime save payload) - Save slot files written by `src/save/SaveManager.gd`.
- Godot resource formats (`.tscn`, `.tres`, `.res`) - Scene and content assets in `scenes/` and `data/`.

## Runtime

**Environment:**
- Godot Engine 4.6 (`project.godot`, `config/features=PackedStringArray("4.6", "Forward Plus")`).
- Desktop renderer configured for Forward Plus.
- Physics engine configured to Jolt (`project.godot`, `[physics] 3d/physics_engine="Jolt Physics"`).

**Package Manager:**
- No Node/Python/Rust package manager in this repository.
- Dependency management is Godot project + addon folders (`addons/`).

## Frameworks

**Core:**
- Godot Node/Scene architecture as the main runtime model.
- Autoload singletons for global services (`project.godot`): `SaveManager`, `PlayerProgressRoot`, `UIManager`, `UIBootstrap`, `ImGuiRoot`.

**Testing:**
- No automated unit-test framework detected.
- Manual test scenes and debug panels are used (`scenes/invtest/`, `scenes/devtest/`, `src/expedition_system/expedition/ui_debug/`).

**Build/Dev:**
- Godot editor import/build pipeline (`.godot/` cache directory).
- Native GDExtension binaries for imgui addon:
  - `addons/imgui-godot/bin/libimgui-godot-native.windows.*.dll`
  - `addons/imgui-godot/bin/libimgui-godot-native.linux.*.so`
  - `addons/imgui-godot/bin/libimgui-godot-native.macos.*`

## Key Dependencies

**Critical:**
- `imgui-godot` plugin (`addons/imgui-godot/plugin.cfg`, version 6.3.2) - Runtime debug UI tooling.
- `equipment-resource-creator` plugin (`addons/equipment-resource-creator/plugin.cfg`, version 1.0) - Editor-side resource creation workflow.
- Save codec layer (`src/save/codecs/*.gd`) - Stable save/load schema implementation.
- Inventory framework (`src/inventory/*.gd`) - Core item/container/session behavior.
- Expedition runtime framework (`src/expedition_system/expedition/**/*.gd`) - Run lifecycle and event orchestration.

## Configuration

**Environment:**
- No `.env` style environment variables used by gameplay code.
- Runtime persistence uses `user://saves` (see `src/save/SaveManager.gd`).

**Build:**
- Main project config in `project.godot`.
- Minimal repository-level editor config in `.editorconfig` (UTF-8 charset).
- Git ignores only Godot generated/project-local folders (`.godot/`, `/android/`).

## Platform Requirements

**Development:**
- Godot 4.6 editor/runtime required.
- Plugin editing workflows expect Godot editor plugin support (`project.godot` -> `[editor_plugins]`).

**Production/Runtime:**
- Main scene starts at `res://scenes/expedition/ExpeditionSceneV2.tscn`.
- Save files rely on local writable filesystem via `user://` path mapping.

---

*Stack analysis: 2026-03-13*
*Update after engine, addon, or runtime dependency changes*
