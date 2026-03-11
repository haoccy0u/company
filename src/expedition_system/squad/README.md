# Squad Module (V2)

## Purpose

`src/expedition_system/squad` stores squad data for expedition start input and expedition runtime state.

Current model is single-type:
- `SquadRuntime` is the template data container and also the runtime container type.
- `make_run_instance()` creates a deep-copied run instance from a template asset.

## Files

- `MemberRuntime.gd`
  - member template/runtime fields
  - includes init fields (`member_id`, `actor_id`, `equipment_*`, `init_hp`)
  - includes runtime fields (`current_hp`, `max_hp`, `alive`, `injury_flags`, `resources`)
  - explicit state helpers: `set_current_hp`, `apply_damage`, `heal`

- `SquadRuntime.gd`
  - squad template/runtime fields (`source_squad_id`, `members`, `shared_res`, `long_states`)
  - strict run builder: `make_run_instance() -> SquadRuntime`
  - shared helpers: `get_shared`, `set_shared`, `inc_shared_int`

## Run Build Rules

`SquadRuntime.make_run_instance()` fails if:
- `members` is empty
- any member is null
- any member has empty `member_id`
- any member has empty `actor_id`
- duplicated `member_id` exists
- actor def cannot be resolved

On success it initializes runtime member state from template:
- resolve actor by `actor_id`
- read `hp_max`
- apply `init_hp` rule
- reset runtime dictionaries

## Runtime Contract

- Expedition runtime and event scenes receive the run instance by reference.
- Event logic can read/write squad state directly on this run instance.
- Template assets are never mutated during a run.

## Manual Check

1. Open `scenes/expedition/ExpeditionSceneV2.tscn`.
2. In ImGui panel, set `squad_runtime_path` to a valid `SquadRuntime` resource.
3. Start run and verify event flow can continue/retreat.
4. Verify squad mutations are visible across steps and in final snapshot.
