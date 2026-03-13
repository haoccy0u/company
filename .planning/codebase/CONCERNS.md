# Codebase Concerns

**Analysis Date:** 2026-03-13

## Tech Debt

**Hard-coded coupling to node paths/groups:**
- Issue: Runtime systems rely on string paths and fixed group names.
- Files:
  - `src/save/SaveManager.gd` (`saveable` group scans)
  - `src/player_progress/PlayerProgressRoot.gd` (`/root/SaveManager`, child NodePaths)
  - `scenes/invtest/HUD.gd` and `scenes/invtest/inventorytest.gd` (`/root/UIManager`, `/root/SaveManager`)
- Impact: Scene refactors can silently break integrations.
- Fix approach: Centralize path/group constants and add startup contract checks.

**Dynamic Dictionary-heavy contracts across modules:**
- Issue: Several key APIs return untyped dictionaries with convention-based keys.
- Files:
  - `src/save/SaveReport.gd` (report fields)
  - `src/inventory/InventoryResult.gd` and `src/inventory/InventoryComponent.gd`
  - `src/expedition_system/expedition/runtime/ExpeditionRuntime.gd` payload dictionaries
- Impact: Typos and schema drift can cause runtime-only failures.
- Fix approach: Introduce lightweight typed wrappers for critical payload shapes.

## Known Bugs / Operational Risks

**Text encoding inconsistency in some docs/comments:**
- Symptoms: Chinese text appears garbled in terminal output during file reads.
- Files: observed in `src/attribute_framework/README.md` and `data/README.md`.
- Trigger: Encoding/display mismatch across tools.
- Workaround: Prefer UTF-8 aware editor views for these files.
- Impact: Documentation can become hard to maintain and review.

**Inventory item resolve path can be expensive on large content trees:**
- Symptoms: Recursive directory scans per uncached lookup.
- Files: `src/inventory/ItemDataResolver.gd` (`_find_item_in_dir_by_id`).
- Trigger: Cache miss with broad search roots.
- Impact: Potential frame hitch or load latency with larger data set.
- Fix approach: Build and persist item-id index at startup instead of recursive search per lookup.

## Security Considerations

**Save files are plain JSON and user-editable:**
- Risk: Local tampering can inject invalid or abusive values.
- Files: `src/save/SaveManager.gd`, save format in `src/save/README.md`.
- Current mitigation: Schema/version checks and contract validation before apply.
- Recommendations: Add optional signature/checksum and stricter value validation per domain.

**Native addon binaries are committed in repo:**
- Risk: Binary provenance and update discipline matter for trust and portability.
- Files: `addons/imgui-godot/bin/*`.
- Current mitigation: Source addon folder is versioned in repo.
- Recommendations: Track binary source/version policy in docs and verify checksums on upgrades.

## Performance Bottlenecks

**Recursive resource scanning for item lookup:**
- Problem: Directory traversal for each unresolved item id.
- File: `src/inventory/ItemDataResolver.gd`.
- Cause: Runtime lookup by recursive `DirAccess` without a prebuilt global index.
- Improvement path: Precompute `item_id -> ItemData` map during bootstrap.

**Potential growth cost in saveable group scans:**
- Problem: Full scene scan over `saveable` group on save/load operations.
- File: `src/save/SaveManager.gd`.
- Cause: All saveables are discovered dynamically each operation.
- Improvement path: Optional registry cache with invalidation hooks for frequent save operations.

## Fragile Areas

**Expedition event scene contract boundary:**
- Why fragile: Runtime expects every event scene to expose `start(...)` and `completed` signal.
- File: `src/expedition_system/expedition/runtime/ExpeditionRuntime.gd` (contract check near event instantiation).
- Common failures: Scene script mismatch causes run blocking.
- Safe modification: Keep a shared base (`ExpeditionEventBase`) and validate scene templates before integration.
- Test coverage: Manual debug flow only.

**UI registration and panel lifecycle boundary:**
- Why fragile: Missing/invalid registry entries fail at runtime.
- Files:
  - `src/ui_framework/UIConfigTable.gd`
  - `src/ui_framework/UIBootstrap.gd`
  - `src/ui_framework/UIManager.gd`
- Common failures: Empty `ui_id`, null scene, incorrect layer/cache policy assumptions.
- Safe modification: Add startup assertion pass listing final registry state.
- Test coverage: Manual checks via `scenes/invtest` and `scenes/devtest`.

## Scaling Limits

**Current verification model does not scale with feature count:**
- Current capacity: Works for current module scope with manual checklists.
- Limit: Regression risk rises as domains and interactions increase.
- Symptoms at limit: Late discovery of integration breakage after scene/path changes.
- Scaling path: Add automated smoke tests for save/inventory/expedition core contracts.

## Dependencies at Risk

**Godot version and plugin compatibility drift:**
- Risk: Upgrading engine may break addon APIs or binary compatibility.
- Files:
  - `project.godot` (engine features)
  - `addons/imgui-godot/` and `addons/equipment-resource-creator/`
- Migration plan: Pin tested engine/addon matrix and run manual compatibility checklist before upgrades.

## Missing Critical Features

**No dedicated save-edit tooling yet:**
- Problem: Save diagnosis/editing depends on manual file edits and runtime panels.
- Current workaround: Edit JSON directly in `user://saves` + reload via in-game flow.
- Blocks: Efficient QA and migration support for save schema changes.
- Implementation complexity: Medium (editor tool + schema validation + safe write workflow).

## Test Coverage Gaps

**No automated regression for core save and inventory contracts:**
- What's not tested: Repeatable machine-run checks for schema/version and inventory operation invariants.
- Risk: Behavior regressions can slip into branches undetected.
- Priority: High.
- Difficulty to test: Medium (requires Godot test harness strategy or minimal runtime test scenes with scripted assertions).

**No automated phase/state-machine validation for expedition runtime:**
- What's not tested: Full run transitions (`idle -> active_event -> waiting_decision -> ended`) in CI.
- Risk: Transition regressions discovered only during manual playtesting.
- Priority: Medium.
- Difficulty to test: Medium to high depending on Godot test environment setup.

---

*Concerns audit: 2026-03-13*
*Update as issues are fixed or newly discovered*
