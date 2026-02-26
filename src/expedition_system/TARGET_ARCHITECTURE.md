# Expedition System Target Architecture (Draft)

## 1. Purpose

This document records the intended long-term architecture direction for the expedition + combat system.

It is a design note for future refactors. It does not imply all changes are implemented yet.

## 2. Current Decision Snapshot

### Confirmed direction

- `ActorRuntime` will be scene-based and instantiated from a reusable `ActorRuntime.tscn`.
- `ActorRuntime` integrates both runtime logic and visual presentation nodes.
- `CombatEngine` remains the single battle rules arbiter (actors do not directly modify other actors).
- `ActorTemplate` remains a data template (no `runtime_scene` field for now).

### Deferred decisions

- Whether `CombatEngine` itself should become a `Node` / scene.
- Whether `ExpeditionSession` should enter the scene tree.
- Whether to introduce `AttributeComponent` into `ActorRuntime` immediately or keep direct `AttributeSet` access first.

## 3. Layering Model (Recommended)

Use three conceptual layers:

1. Data state layer
- Focus: persistent state, serialization, deterministic data
- Typical types: `RefCounted`, `Resource`
- Examples:
  - `SquadRuntime`
  - `ExpeditionSession` (recommended to stay non-Node)
  - `BattleStart`, `BattleResult`, `ActorEntry`, `ActorResult`

2. Runtime orchestration layer
- Focus: scheduling, tick/update, coordination between systems
- Typical types: `Node` (manager) or `RefCounted` (rule engine)
- Examples:
  - `ExpeditionManager` (future, Node)
  - `CombatEngine` (current `RefCounted`, may later gain a Node wrapper)

3. Runtime instance / presentation layer
- Focus: battle unit state container + signals + visual nodes
- Typical types: scene-based `Node`
- Examples:
  - `ActorRuntime.tscn` + `ActorRuntime.gd`

## 4. Why Not Everything Must Be a Node

Making one object scene-based does not require all related objects to be scene-based.

Recommended split:

- `ActorRuntime`: scene-based (good for UI, FX, animation hooks, per-actor signals)
- `CombatEngine`: can remain rule-focused and manually tick actors
- `ExpeditionSession`: can remain data/session object and be managed by a separate Node manager

This avoids:

- over-coupling persistence logic to the scene tree
- difficult lifecycle management for background expeditions
- unnecessary node overhead for non-visible systems

## 5. Multi-Expedition Concurrency (Future)

When multiple expeditions run at the same time, prefer:

- `ExpeditionSession` stays as data/session object
- add `ExpeditionManager` (`Node`) to manage multiple sessions

`ExpeditionManager` responsibilities (future):

- hold a collection of active `ExpeditionSession`
- drive expedition time progression
- trigger events (`CombatEvent`, non-combat)
- coordinate UI notifications / selection
- decide which expedition needs a visible battle scene

This keeps background expeditions lightweight and easier to save/load.

## 6. Combat Runtime Options (Future)

### Option A (Recommended near-term)

- Keep `CombatEngine` as `RefCounted`
- `CombatEngine` instantiates `ActorRuntime.tscn`
- `CombatEngine` manually calls `actor.tick(delta)`
- UI observes actors via signals and/or host node

Why:

- low migration risk
- preserves deterministic battle control
- already matches current implementation direction

### Option B (Later, if needed)

- Add `CombatEngineNode` scene/wrapper (Node)
- Keep rules logic in `CombatEngine` or move gradually
- `CombatEngineNode` owns actor host root + battle UI integration

Why:

- cleaner scene integration for complex battle presentation
- easier to connect battle UI and debug tools in-editor

Risk:

- lifecycle and scene transitions become more complex

## 7. ActorRuntime Scene Direction (Planned End State)

`ActorRuntime` should become a reusable battle-unit scene instance.

Expected contents (can be phased in):

- root node with `ActorRuntime.gd`
- attribute access bridge (`AttributeSet` now; `AttributeComponent` optional later)
- visual root (`VisualRoot`)
- FX root (`StateFxRoot`)
- UI anchor (`UiAnchor`)
- animation player / animation tree (when needed)

Important rule remains:

- `ActorRuntime` owns only self-state and self-presentation
- `CombatEngine` decides battle outcomes and cross-actor effects

## 8. Current Implementation Alignment (as of now)

Already aligned with target direction:

- `ActorRuntime` is now a `Node`
- `ActorRuntime.tscn` exists as the unified actor runtime scene
- `CombatEngine` instantiates `ActorRuntime.tscn` and injects `ActorEntry` data
- `CombatEngine` can attach actor nodes to a host root (`CombatActors`)

Still pending:

- richer `ActorRuntime.tscn` node structure
- richer `ActorRuntime` signal/event interface for UI
- `InventoryComponent` equipment-item mapping and attribute application pipeline
- possible `CombatEngineNode` wrapper

## 9. Next Practical Steps (Actor First)

Before revisiting top-level architecture, prioritize finishing `ActorRuntime`:

1. Add base scene child structure (`VisualRoot`, `UiAnchor`, `StateFxRoot`)
2. Add generic attribute helper APIs on `ActorRuntime` (`apply_attribute_buff`, `find_attribute`, etc.)
3. Expand actor signals for UI (`value_changed`, `status_applied`, `status_removed`) if needed
4. Define equipment -> inventory item -> attribute modifier application path

After actor stabilization:

5. Re-evaluate `CombatEngine` Node wrapper vs current `RefCounted` form
6. Design `ExpeditionManager` for multi-expedition orchestration
