# UI Framework (Phase 1)

## 0. Freeze Status
- Status: Frozen baseline (stable for current project stage).
- Frozen at: 2026-02-15.
- Rule: no behavior changes in `src/ui_framework/*` unless there is a clear bug fix or an approved new requirement.
- Rule: for feature expansion, prefer adding new entries in `UIConfigTable` and new UI panel scripts, instead of modifying `UIManager` core flow.

## 1. Goal
Build a reusable UI framework module for this project.
All future UI panels should be opened/closed through `UIManager` instead of direct scene instantiation in feature scripts.

## 2. Scope (Phase 1)
- Provide a global `UIManager` (Autoload).
- Provide a global `UIBootstrap` (Autoload) to register UI definitions.
- Support UI registration by `ui_id`.
- Support layered UI roots (`hud`, `popup`, `system`).
- Support cache policy:
  - `keep_alive`: keep instance and hide/show.
  - `destroy_on_close`: free instance on close.
- Provide unified API:
  - `register_ui`
  - `show_ui`
  - `hide_ui`
  - `toggle_ui`
  - `is_open`
  - `get_ui_node`

## 3. Contracts
UI panel scripts can optionally implement:
- `_ui_open(payload: Dictionary) -> void`
- `_ui_close(reason: StringName) -> bool`

If `_ui_close` returns `false`, `UIManager` will keep the panel open.

## 4. Module Structure
- `src/ui_framework/UIManager.gd`
- `src/ui_framework/UIBootstrap.gd`
- `src/ui_framework/UIConfigTable.gd`
- `src/ui_framework/UIRegistry.gd`
- `src/ui_framework/UIHandle.gd`
- `src/ui_framework/README.md`

## 5. Integration Rules
- Business scripts should not instantiate UI scenes directly.
- Business scripts call `UIManager.show_ui(...)`.
- Existing feature scripts may keep fallback code for compatibility in early migration.
- Prefer signal-based communication:
  - Business scripts emit intent signals (for example, `request_open_inventory`).
  - Scene coordinator or UI layer listens and calls `UIManager`.
- Legacy bridge methods (such as `HUD.open_inventory`) should be treated as deprecated.

## 6. First Integration Target
Inventory UI:
- `UIConfigTable` declares `inventory_panel`.
- `UIBootstrap` reads config table and registers entries.
- Scene coordinator opens `inventory_panel` through `UIManager`.
- `InventoryUIPanel` adapts to framework via `_ui_open/_ui_close`.

## 7. Standard Flow For New UI
1. Add panel scene and panel script.
2. Implement optional panel hooks:
   - `_ui_open(payload)`
   - `_ui_close(reason)`
3. Add one config entry in `UIConfigTable` with `ui_id`, scene, layer, and cache policy.
4. Business emits intent signal.
5. Coordinator listens signal and calls `UIManager.show_ui(ui_id, payload)`.
6. Do not instantiate panel scene directly in business scripts.

## 8. Validation Checklist
1. Chest opens inventory via `UIManager`.
2. Repeated open does not create duplicate panel in `keep_alive`.
3. Close request can be rejected when panel returns `false` in `_ui_close`.
4. Save/load test panel in HUD still works.

## 9. Usage Guide
### 9.1 Runtime flow
1. Engine loads Autoloads:
   - `UIManager`
   - `UIBootstrap`
2. `UIBootstrap` reads `UIConfigTable.entries()` and calls `UIManager.register_ui(...)`.
3. Business emits UI intent signal (for example: `request_open_inventory`).
4. Coordinator receives signal and calls `UIManager.show_ui(ui_id, payload)`.
5. Panel receives payload in `_ui_open(payload)`.

### 9.2 Open and close API
- Open:
```gdscript
var ui_manager := get_node_or_null("/root/UIManager")
ui_manager.call("show_ui", &"inventory_panel", {
	"player_inv": player_inventory,
	"chest_inv": chest_inventory
})
```
- Close:
```gdscript
var ui_manager := get_node_or_null("/root/UIManager")
ui_manager.call("hide_ui", &"inventory_panel", &"manual")
```
- State check:
```gdscript
var is_open: bool = bool(ui_manager.call("is_open", &"inventory_panel"))
```

### 9.3 Add a new UI (minimal steps)
1. Create panel scene + script.
2. Implement optional hooks:
```gdscript
func _ui_open(payload: Dictionary) -> void:
	pass

func _ui_close(reason: StringName = &"manual") -> bool:
	return true
```
3. Add config entry in `UIConfigTable.entries()`:
```gdscript
{
	KEY_UI_ID: &"settings_panel",
	KEY_SCENE: preload("res://scenes/ui/SettingsPanel.tscn"),
	KEY_LAYER: &"popup",
	KEY_CACHE_POLICY: &"keep_alive"
}
```
4. Trigger via signal -> coordinator -> `UIManager.show_ui(...)`.

## 10. Do and Do Not
- Do: keep business logic and UI lifecycle logic separated.
- Do: use `ui_id` as the only public key for opening/closing UI.
- Do not: instantiate panel scenes directly inside business scripts.
- Do not: hardcode panel node paths in gameplay scripts.
