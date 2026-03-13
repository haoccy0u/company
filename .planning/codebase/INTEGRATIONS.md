# External Integrations

**Analysis Date:** 2026-03-13

## APIs & External Services

**Network APIs:**
- None detected in current gameplay/runtime code.
- No HTTP client or webhook handling found under `src/` and `scenes/` scripts.

**Editor/Tooling Plugins:**
- `imgui-godot` plugin (`addons/imgui-godot/plugin.cfg`) - Debug UI integration inside Godot.
- `equipment-resource-creator` plugin (`addons/equipment-resource-creator/plugin.cfg`) - Editor dock for creating resources.

## Data Storage

**Runtime Save Storage:**
- Local filesystem through Godot `user://` path.
  - Save directory: `user://saves`
  - Save files: `save_slot_{id}.json`
  - Implementation: `src/save/SaveManager.gd`
  - Write strategy: atomic temp+rename with backup suffix (`.tmp`, `.bak`).

**Project Content Storage:**
- Godot resources under `res://data` and `res://scenes`.
  - Item/location/event resources in `data/devtest/`.
  - Scene files in `scenes/`.
  - Resource lookups done with `ResourceLoader.load(...)` and preloaded paths.

**Caching:**
- In-memory item cache in `src/inventory/ItemDataResolver.gd` (`static var _item_cache`).
- No external cache service (Redis/Memcached/etc.) detected.

## Authentication & Identity

**User/Auth Provider:**
- None detected (single-player/local runtime model).

**OAuth/External Identity:**
- None.

## Monitoring & Observability

**Error Tracking Service:**
- None external.

**Analytics:**
- None external.

**Logging/Diagnostics:**
- In-engine diagnostics via `push_warning(...)` and `push_error(...)` across modules.
- Debug overlay and control panels through ImGui scripts:
  - `src/expedition_system/expedition/ui_debug/ExpeditionImGuiDebugPanel.gd`
  - `src/expedition_system/expedition/ui_debug/ExpeditionSquadConfigImGuiPanel.gd`

## CI/CD & Deployment

**Hosting/Deployment:**
- No deployment pipeline files found in repo (`.github/workflows` not present).
- Project appears focused on local/editor runtime execution.

**CI Pipeline:**
- None detected.

## Environment Configuration

**Development:**
- Main settings from `project.godot`.
- Addon activation via `[editor_plugins]`.
- No required secret env vars found.

**Staging/Production:**
- Not explicitly defined in repository.

## Webhooks & Callbacks

**Incoming Webhooks:**
- None.

**Outgoing Webhooks:**
- None.

---

*Integration audit: 2026-03-13*
*Update when adding network services, cloud storage, or external APIs*
