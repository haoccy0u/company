# Expedition Module (V2)

## Purpose

`src/expedition_system/expedition` provides a framework-first expedition runtime.

Current scope:
- start a new expedition run from player input
- generate a finite event sequence once at run start
- play event sequence by instancing event scenes directly
- event scene completes itself and reports payload back to runtime
- choose continue or retreat between events
- end run and produce a typed result record
- use `Squad` scene runtime as run input (`PackedScene.instantiate` + roster build)

Deferred:
- battle event integration
- concrete reward formulas

## Main Flow

`ExpeditionRuntime` state machine:

`idle -> active_event -> waiting_decision -> ... -> ended`

Rules:
- sequence is generated once per run (`seed + sequence` recorded)
- `choose_continue()` is the single advance action in this stage
  - from `idle`: enters first event
  - from `waiting_decision`: enters next event
- event completion comes from event scene `completed(payload)`
- retreat is only valid in `waiting_decision`

## Main Files

- `runtime/ExpeditionRuntime.gd` + `runtime/ExpeditionRuntime.tscn`
  - runtime coordinator and event-scene orchestration
- `content/ExpeditionLocationDef.gd`
  - location metadata and `event_pool` reference
- `content/ExpeditionEventPoolDef.gd`
  - location event pool (`Array[PackedScene]`)
- `event/ExpeditionEventBase.gd`
  - event scene base contract (`start(context)` + async component execution)
- `ui_debug/ExpeditionImGuiDebugPanel.gd`
  - scene-owned ImGui debug tool

## Scene Tree

- `src/expedition_system/expedition/runtime/ExpeditionRuntime.tscn`
  - `ExpeditionRuntime`
	- `EventHost`

- `scenes/expedition/events/ExpeditionEventBase.tscn`
  - `ExpeditionEventBase`
	- `Components`

- `scenes/expedition/events/devtest/Event*.tscn`
  - devtest event scenes driven by `ExpeditionEventBase`

## Debug Validation (ImGui Only)

Use `scenes/expedition/ExpeditionSceneV2.tscn`.

Suggested manual validation:
1. Start Run
2. Continue (enter first event)
3. Continue (next event) / Retreat
4. Observe `phase`, `step_index`, `current_event`, and result payload

## Planning And Progress

- V2 plan: `src/expedition_system/docs/expedition_v2_plan.md`
- V2 progress tracking: `src/expedition_system/docs/expedition_v2_progress.md`
