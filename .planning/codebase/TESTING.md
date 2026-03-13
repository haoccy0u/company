# Testing Patterns

**Analysis Date:** 2026-03-13

## Test Framework

**Runner:**
- No automated unit/integration test framework config detected in repository.
- Verification is currently scene-driven and manual inside Godot editor/runtime.

**Assertion Model:**
- Runtime checks rely on:
  - guard clauses + `push_error`/`push_warning`
  - structured result dictionaries (`SaveReport`, `InventoryResult`)
  - visible behavior in debug/test scenes

**Run Commands (manual):**
```bash
# Open project in Godot editor
godot4 --path .

# Run main scene (from editor play button or CLI)
godot4 --path . --main-pack .
```

## Test File Organization

**Location:**
- Inventory manual tests: `scenes/invtest/`
- Generic dev test workspace: `scenes/devtest/` + `src/devtest/`
- Expedition runtime debug validation: `src/expedition_system/expedition/ui_debug/`

**Naming:**
- Test-oriented scenes/scripts use `invtest` or `devtest` naming.
- No `*.test.gd` style convention is currently in use.

**Structure Example:**
```text
scenes/
  invtest/
    inventorytest.tscn
    inventorytest.gd
  devtest/
    TestHub.tscn
    TestHub.gd
    panels/DevInventorySlot.tscn
src/
  devtest/
    TestRegistry.gd
    TestPanelBase.gd
```

## Test Structure

**Manual flow pattern:**
1. Open dedicated test scene/panel.
2. Trigger operation through UI or debug controls.
3. Check result via visible state + report dictionaries/log lines.
4. Repeat key edge cases listed in module README checklists.

**Examples in docs:**
- Save system manual validation checklist: `src/save/README.md`.
- Inventory regression checklist: `src/inventory/README.md`.
- Expedition debug flow: `src/expedition_system/expedition/README.md`.

## Mocking

**Framework:**
- No mocking framework detected.

**Current pattern:**
- Use deterministic dev resources (`data/devtest/**/*.tres`) and dedicated scenes instead of mocks.
- Use debug panels to drive runtime state transitions.

## Fixtures and Factories

**Test Data:**
- Data fixtures are primarily `.tres` resources under `data/devtest/`.
- Scene fixtures for behavior validation under `scenes/invtest/` and `scenes/expedition/events/devtest/`.

**Location:**
- Inventory fixture resources: `data/devtest/inventory/`
- Expedition fixture resources: `data/devtest/expedition_v2/`

## Coverage

**Requirements:**
- No automated coverage target or reporting pipeline detected.

**Enforcement:**
- Coverage is currently procedural/manual via developer checklists and smoke tests.

## Test Types

**Unit Tests:**
- Not present as standalone automated suites.

**Integration/Behavior Tests:**
- Primary approach via test scenes and runtime interaction:
  - Inventory open/move/swap/save/load
  - Expedition start/continue/retreat flow
  - Player progress bootstrap/load fallback behavior

**E2E Tests:**
- Not present as automated scripts.

## Common Validation Patterns

**Save-related validation:**
- Validate `status/success/errors/warnings/metrics` fields from save/load report dictionaries.

**UI/runtime validation:**
- Verify signal wiring and panel lifecycle through `UIManager` and dev hub.

**Regression process:**
- Re-run module-specific manual checklist after changes in related domain.

---

*Testing analysis: 2026-03-13*
*Update when automated tests or CI checks are introduced*
