# Architecture

**Analysis Date:** 2026-03-13

## Pattern Overview

**Overall:** Domain-oriented Godot monolith with autoload service layer and scene-driven feature modules.

**Key Characteristics:**
- Core features are split by domain directories under `src/` (save, inventory, expedition, player progress, UI).
- Runtime orchestration relies on autoload singletons in `project.godot`.
- Heavy use of signals and explicit contracts (`start(...)`, `completed(...)`, `capture_state/apply_state`).
- Mix of `Node` runtime objects and `Resource` data objects.

## Layers

**Bootstrap/Global Services:**
- Purpose: Initialize cross-scene services and shared managers.
- Contains: `SaveManager`, `PlayerProgressRoot`, `UIManager`, `UIBootstrap`, `ImGuiRoot` autoloads.
- Depends on: Godot scene tree root and domain modules.
- Used by: Feature coordinators and scene scripts.

**Domain Runtime Layer:**
- Purpose: Feature behavior and game state transitions.
- Contains:
  - Save system: `src/save/*.gd`
  - Inventory: `src/inventory/*.gd`
  - Expedition: `src/expedition_system/expedition/**/*.gd`
  - Squad runtime: `src/expedition_system/squad/*.gd`
  - Player progress: `src/player_progress/*.gd`
- Depends on: Data resources, scene nodes, autoload services.
- Used by: Scene coordinators and UI/debug panels.

**UI Orchestration Layer:**
- Purpose: Register/open/close panels by `ui_id` and manage panel lifecycle.
- Contains: `src/ui_framework/*.gd`, plus panel implementations in `scenes/`.
- Depends on: Domain runtime layer and scene assets.
- Used by: Gameplay coordinators and dev test scenes.

**Content/Data Layer:**
- Purpose: Static definitions and editable resources.
- Contains: `data/**/*.tres`, `scenes/**/*.tscn`, actor/item/location/event definitions.
- Depends on: Godot resource loader and typed resource scripts.
- Used by: Runtime systems at load/instantiate time.

## Data Flow

**Save/Load Flow:**
1. Runtime calls `SaveManager.save_slot(...)` or `load_slot(...)` (`src/save/SaveManager.gd`).
2. Save manager enumerates `saveable` group and validates contract methods.
3. Data is encoded as JSON payload (`meta/domains/scene_nodes`), written atomically to `user://saves`.
4. Load path validates schema/version and applies state back to scene nodes.
5. Report dictionary (`SaveReport`) returns status/errors/warnings/metrics.

**Inventory Interaction Flow:**
1. UI slot captures input (`src/inventory/ui/BaseInventorySlot.gd`).
2. Interaction is routed through `InventorySession`.
3. Session calls `InventoryComponent` actions (`take/place/swap/insert`).
4. Component emits `changed` as single source of truth.
5. UI panel listens and refreshes visual state.

**Expedition Run Flow:**
1. `ExpeditionRuntime.start_new_run(...)` validates request and builds sequence.
2. Runtime instantiates squad and event scenes.
3. Event scenes report completion via `completed(payload)` signal.
4. Runtime records step results, moves to decision phase, continue/retreat.
5. Run end generates `ExpeditionResult` snapshot.

## Key Abstractions

**Saveable Contract:**
- Purpose: Uniform save/load interface for scene nodes.
- Files: `src/save/Saveable.gd`, `src/save/SaveManager.gd`.
- Pattern: Group membership + reflective calls (`get_save_id`, `capture_state`, `apply_state`).

**UI Registry + Handle:**
- Purpose: `ui_id` based panel lifecycle and decoupled panel access.
- Files: `src/ui_framework/UIManager.gd`, `UIRegistry.gd`, `UIHandle.gd`.
- Pattern: Registry dictionary + lazy instantiate + optional keep-alive cache.

**Expedition Runtime State Machine:**
- Purpose: Controlled run lifecycle (`idle -> active_event -> waiting_decision -> ended`).
- Files: `src/expedition_system/expedition/runtime/ExpeditionRuntime.gd`.
- Pattern: Explicit phase checks, signal-driven transitions, typed `RefCounted` model objects.

## Entry Points

**Main Scene Entry:**
- Location: `project.godot` -> `run/main_scene="res://scenes/expedition/ExpeditionSceneV2.tscn"`.
- Responsibilities: Boot main gameplay scene tree.

**Autoload Entry Points:**
- Location: `project.godot` `[autoload]`.
- Responsibilities: Provide globally reachable services for save, progress, UI, and debug root.

**Development Test Entry:**
- Location: `scenes/devtest/TestHub.tscn` + `scenes/devtest/TestHub.gd`.
- Responsibilities: Manual panel-based feature checks.

## Error Handling

**Strategy:** Guard-clause validation with explicit warnings/errors and early returns.

**Patterns:**
- `push_warning(...)` for recoverable issues and missing optional links.
- `push_error(...)` for invalid states and contract violations.
- Dictionary-based result objects for action status (`InventoryResult`, `SaveReport`).

## Cross-Cutting Concerns

**Validation:**
- Contract checks before action (`has_method`, `has_signal`, typed cast checks).
- Save schema/version validation before state apply.

**State Consistency:**
- Atomic save write and rollback behavior in `SaveManager`.
- Runtime state machine gates in expedition runtime.

**Debuggability:**
- Rich manual debugging via ImGui panels and devtest scenes.
- Warning/error messaging includes IDs/paths in many critical branches.

---

*Architecture analysis: 2026-03-13*
*Update when autoload list, runtime contracts, or domain boundaries change*
