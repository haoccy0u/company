# Coding Conventions

**Analysis Date:** 2026-03-13

## Naming Patterns

**Files:**
- GDScript files are generally `PascalCase.gd` when they define a `class_name`.
- Scene files are usually `PascalCase.tscn` or descriptive lowercase for test scenes.
- Module docs use `README.md` inside each domain folder.

**Functions:**
- `snake_case` function names (`save_slot`, `load_slot_filtered`, `find_player_actor`).
- Godot lifecycle hooks keep standard names (`_ready`, `_process`, `_physics_process`, `_gui_input`).
- Internal/private helpers commonly use `_prefix` naming.

**Variables:**
- Locals and members mostly use `snake_case`.
- Constants use `UPPER_SNAKE_CASE`.
- `StringName` constants frequently use `&"literal"` format.

**Types:**
- `class_name` types use PascalCase (`InventoryComponent`, `ExpeditionRuntime`, `PlayerActorData`).
- Widespread use of explicit type annotations for vars/params/returns.

## Code Style

**Formatting:**
- `.editorconfig` only enforces UTF-8 charset (no formatter rules defined).
- Codebase appears tab-indented in most GDScript files.
- Braces and control flow follow standard GDScript style.

**Linting:**
- No dedicated lint config (`.eslintrc`, `eslint.config`, etc.) detected.
- Style consistency is maintained by manual review + project habits.

## Import Organization

**Order pattern (observed):**
1. `extends` / `class_name`
2. `signal` declarations
3. `const` preloads and literal constants
4. `@export` and `@onready` fields
5. runtime members
6. functions

**Preload Usage:**
- Direct dependency scripts/resources are preloaded at file top:
  - `preload("res://src/save/SaveReport.gd")`
  - `preload("res://src/ui_framework/UIRegistry.gd")`

## Error Handling

**Patterns:**
- Guard clauses first, then early return.
- Recoverable issues use `push_warning(...)`.
- Invalid critical states use `push_error(...)`.
- Many operations return structured dictionaries instead of raw bool.

**Result Contracts:**
- Inventory operations return `InventoryResult` dictionaries.
- Save operations return `SaveReport` dictionaries with `status/errors/warnings/metrics`.
- Runtime contracts often check `has_method(...)`/`has_signal(...)` before call/connect.

## Logging

**Framework:**
- Godot built-in `push_warning` and `push_error`.
- Test hub and debug panels provide UI-level logging (`RichTextLabel`, ImGui views).

**Patterns:**
- Include identifiers/context in warnings and errors when available.
- Avoid noisy per-frame logs in normal flow.

## Comments

**When to Comment:**
- Most comments explain intent/contract boundaries, not line-by-line mechanics.
- README files document module-level workflows and verification checklists.
- Some bilingual comments exist (English + Chinese).

**Region Markers:**
- `#region` / `#endregion` is used in many files for sectioning public/private methods.

## Function Design

**Structure:**
- Public APIs are usually thin and delegate to private helpers.
- Complex flows are split into sub-functions (`_build_payload`, `_validate_payload_schema`, etc.).
- Guard-first flow keeps nesting depth low.

**Parameters and Returns:**
- Typed parameters and return values are common.
- Optional/default parameters are used for ergonomic runtime APIs.

## Module Design

**Exports and access:**
- Domain APIs are exposed through `class_name` scripts and autoload services.
- Cross-module access often uses explicit paths or `preload` constants.

**Integration style:**
- Signals are preferred for decoupling event flow.
- Global systems are reached via `/root/<Autoload>` access where needed.

---

*Convention analysis: 2026-03-13*
*Update when style guide, result contracts, or autoload access patterns change*
