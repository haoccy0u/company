# Expedition Event Pool Plan

## Status

Deferred.

The current expedition baseline is frozen as:
- finite ordered `event_sequence`
- explicit step-by-step events
- current supported event types:
  - `combat:<enemy_group_id>`
  - `rest`

This document describes a later replacement for hand-written event sequences.

## Problem

Current expeditions still hardcode event content at authoring time.

Examples:
- `combat:training_dummy,rest`
- `combat:wolves,rest,combat:bandits`

This is good for stabilization and testing, but not enough for long-term content generation.

## Target

Replace fixed event sequences with:
- an event pool
- a difficulty policy
- a generated finite event sequence at expedition start

The key point is:
- runtime consumption stays sequence-based
- only the sequence generation step changes

## Proposed Shape

### Location Input

Location should eventually define:
- `expedition_length`
- `event_pool_id`
- `base_difficulty`

### Event Pool

Add resource definitions similar to:
- `ExpeditionEventPoolDef`
- `ExpeditionEventPoolEntryDef`

Each pool entry should be able to describe:
- `event_type`
- `payload_id`
- `weight`
- `min_step`
- `max_step`
- `min_difficulty`
- `max_difficulty`
- optional tags

### Selection Policy

Add a small selection policy layer, for example:
- `DefaultEventSelectionPolicy`

Minimum first version:
- `difficulty = base_difficulty + step_index`
- filter entries by step and difficulty range
- choose from candidates by weight
- generate a finite sequence before the expedition starts

## Boundary

Do not change these current responsibilities:
- `ExpeditionSession` still advances one current event at a time
- `EventSelector` still resolves the current step event
- `CombatEventHandler` and `RestEventHandler` still consume concrete events
- `BattleBuilder` still only consumes combat events

The future event-pool system should only replace:
- how the finite event sequence is produced

## Deferred Related Cleanup

The following issues were intentionally deferred together with the later event-system expansion:

### 1. Manual event consumption flow in devtest

Current devtest panels still drive event handling step by step, for example:
- build session
- advance
- build battle start
- resolve event
- complete event

This is acceptable during stabilization because current event content is still sparse.
It should not be treated as the final runtime flow.

Long-term direction:
- expedition events should be consumed automatically by the runtime path
- devtest panels should observe or trigger that path
- panel-specific manual sequencing should stop influencing core API shape

### 6. Raw string event spec parsing

The current baseline still uses string specs such as:
- `combat:training_dummy`
- `rest`

This is intentionally simple for current stabilization.
It also reflects that the full event system is not complete yet.

Long-term direction:
- generated event content should move toward typed descriptors or typed generated sequence rows
- raw string parsing should become a compatibility/devtest layer, not the long-term core format
- this cleanup should be revisited after the event pool and generation path are defined

## Suggested Migration Order

1. Add event pool resources.
2. Add one default selection policy.
3. Generate a finite sequence during `ExpeditionSession.setup()`.
4. Keep manual `event_sequence` as a devtest fallback during migration.
5. Remove direct hand-written sequences only after the generated path is stable.
