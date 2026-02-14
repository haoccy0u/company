# UI Framework (Phase 1)

## 1. Goal
Build a reusable UI framework module for this project.
All future UI panels should be opened/closed through `UIManager` instead of direct scene instantiation in feature scripts.

## 2. Scope (Phase 1)
- Provide a global `UIManager` (Autoload).
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

## 6. First Integration Target
Inventory UI:
- `HUD` registers and opens `inventory_panel` through `UIManager`.
- `InventoryUIPanel` adapts to framework via `_ui_open/_ui_close`.

## 7. Validation Checklist
1. Chest opens inventory via `UIManager`.
2. Repeated open does not create duplicate panel in `keep_alive`.
3. Close request can be rejected when panel returns `false` in `_ui_close`.
4. Save/load test panel in HUD still works.
