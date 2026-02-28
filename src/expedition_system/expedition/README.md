# Expedition Module

## Purpose

`src/expedition_system/expedition` handles expedition progression and event selection.

This layer is responsible for:
- holding `SquadRuntime`
- holding `ExpeditionLocationDef`
- advancing expedition steps
- selecting the next expedition event
- routing the current event to the correct handler

This layer is not responsible for:
- combat numeric rules
- `CombatEngine` internals
- battle result write-back rules

## Current Event Model

Expeditions now use a finite ordered event sequence.

Location input:
- `ExpeditionLocationDef.event_sequence: PackedStringArray`

Supported sequence items:
- `combat:training_dummy`
- `combat:wolves`
- `rest`

Meaning:
- `combat:<enemy_group_id>` creates a `CombatEventDef`
- `rest` creates a `RestEventDef`

The sequence is consumed by `step_index`.
When `step_index` reaches the end of the sequence, `ExpeditionSession.advance()` ends the expedition with `sequence_completed`.

## Main Files

- `ExpeditionLocationDef.gd`
  - stores finite `event_sequence`
  - provides helpers to read event type and payload for a given step

- `EventSelector.gd`
  - selects the next event from the current location and `step_index`

- `CombatEventDef.gd`
  - battle event payload

- `RestEventDef.gd`
  - minimal non-combat event payload

- `strategy/CombatEventStrategy.gd`
  - builds combat events from `combat:<enemy_group_id>`

- `strategy/RestEventStrategy.gd`
  - builds rest events from `rest`

- `handler/CombatEventHandler.gd`
  - converts combat events into `BattleStart` or battle stub results

- `handler/RestEventHandler.gd`
  - applies fixed healing directly to `SquadRuntime`

- `handler/ExpeditionEventRouter.gd`
  - unified event consumption entry

- `ExpeditionSession.gd`
  - session state and step progression

## Current Boundary

- `EventSelector` decides what the current step event is.
- `ExpeditionSession` decides when the expedition can advance and when it ends.
- `ExpeditionEventRouter` decides how the current event is consumed.
- `battle/` still owns actual combat execution.

## Manual Check

Use `TestHub -> Expedition Session`.

Suggested sequence:
1. `combat:training_dummy,rest,combat:wolves`
2. Build Session
3. Advance
4. Resolve or complete the current event
5. Repeat until the session ends with `sequence_completed`
