# Expedition Code Cleanup Plan

## Status

Planned.

Current priority for cleanup:
- `2.` reduce strong-type / dictionary dual maintenance
- `3.` add a minimal expedition event base class
- `4.` replace broad resource scanning with path-based loading

Deferred for later:
- `5.` player/enemy entry assembly restructuring

## Goal

Improve maintainability without changing current expedition behavior.

This plan stays inside the current frozen baseline:
- finite ordered `event_sequence`
- explicit event consumption
- current event types remain `combat:<enemy_group_id>` and `rest`

## Non-Goals

This plan does not include:
- replacing the event sequence model
- redesigning devtest panel flow
- event pool generation
- entry-builder refactor for player/enemy assembly

## Problem 2: Strong Type And Dictionary Dual Maintenance

### Current issue

Battle data is currently kept in two parallel forms:
- strong-type objects such as `ActorEntry` and `ActorResult`
- duplicated dictionary arrays for compatibility output

This causes repeated conversions in:
- `BattleStart`
- `BattleResult`
- `BattleSession`
- `ResultApplier`

The result is:
- more boilerplate
- higher risk of one representation drifting away from the other
- extra conversion work in the main runtime path

### Target

Use strong-type objects as the only internal source of truth.

Keep dictionary data only as:
- `to_dict()` output
- devtest/debug display data

### Suggested change

Internal flow should prefer:
- `BattleStart.player_entries`
- `BattleStart.enemy_entries`
- `BattleResult.player_actor_results`

Compatibility fields should become derived output only:
- `players`
- `enemies`
- `player_results`

`ResultApplier` should apply from `ActorResult[]` first and only fall back to dictionaries when needed for compatibility.

### Suggested order

1. Treat strong-type arrays as authoritative in `BattleStart` and `BattleResult`.
2. Move dictionary generation behind `to_dict()`.
3. Remove unnecessary object-to-dictionary-to-object conversions in `BattleSession`.
4. Narrow `ResultApplier` to a strong-type-first path.

## Problem 3: Missing Event Base Class

### Current issue

Expedition events share common fields, but there is no explicit common base type.

Current consequences:
- shared fields are duplicated across event defs
- callers sometimes inspect events indirectly
- event contracts are less clear than they should be

### Target

Add one minimal base class for expedition events.

Suggested shared fields:
- `event_id`
- `event_type`
- `location_id`
- `step_index`

### Suggested shape

Add:
- `ExpeditionEventDef.gd`

Then make these inherit from it:
- `CombatEventDef.gd`
- `RestEventDef.gd`

### Suggested order

1. Add the base event class with shared fields and shared `to_dict()` support.
2. Move duplicated common fields from concrete event defs into the base class.
3. Update session/router code to read event metadata directly from the event object.
4. Keep existing behavior unchanged.

## Problem 4: Resource Lookup By Broad Scan

### Current issue

Current resource lookup scans large data roots on first miss.

This is workable in early development, but it becomes less predictable as content grows.

It also duplicates lookup logic in multiple places.

### Direction

Use folder conventions plus direct path loading as the default lookup path.

Suggested resource layout:
- `res://data/expedition/actors/<template_id>.tres`
- `res://data/expedition/enemy_groups/<group_id>.tres`

### Target

Resolvers should:
- build the expected resource path from the id
- load directly from that path
- cache the loaded resource

Manual registration should remain available for:
- devtest resources
- temporary overrides
- special loading cases

### Suggested order

1. Define canonical folders for expedition actor templates and enemy groups.
2. Update `ActorTemplateResolver` to use direct path loading first.
3. Update enemy-group lookup to use direct path loading first.
4. Keep cache and manual registration support.
5. Remove broad fallback scans when the directory convention is stable.

## Validation

After implementation, validate at minimum:

1. Existing expedition devtest flow still resolves `combat` and `rest`.
2. `BattleStart` and `BattleResult` still produce correct debug output through `to_dict()`.
3. `ResultApplier` still writes HP back correctly for both HP policies.
4. Actor template and enemy group loading still works from the new canonical folders.

## Risk

- Strong-type cleanup can break devtest panels if they still read compatibility fields directly.
- Event base-class migration can cause hidden type assumptions in session/router code.
- Path-based loading depends on resource folder conventions staying strict.

## Rollback

If this cleanup needs to be reverted later, revert only the files in:
- `src/expedition_system/battle/`
- `src/expedition_system/expedition/`
- `src/expedition_system/actor/`
- `src/expedition_system/enemy/`

The intended rollout is incremental so each step can be rolled back independently.
