# Character Data Flow

## Purpose

This document describes the current data flow for player actors and enemy actors inside the expedition system.

It reflects the code that is already in use.

## Current Rules

1. `ActorTemplate` is the static source of actor definition.
2. `MemberConfig` stores player-side pre-departure choices only.
3. `MemberRuntime` stores expedition-persistent member state only.
4. `ActorEntry` is assembled only when battle input is needed.
5. Expedition events come from a finite ordered `event_sequence`.

## Player Flow

```text
MemberConfig
  -> SquadRuntimeFactory
  -> PlayerActorAssembler.build_member_runtime()
  -> MemberRuntime
  -> ExpeditionSession
  -> EventSelector
  -> CombatEventDef / RestEventDef
  -> ExpeditionEventRouter
  -> CombatEventHandler / RestEventHandler
  -> BattleBuilder
  -> PlayerActorAssembler.build_actor_entry()
  -> ActorEntry
  -> ActorRuntime
  -> BattleResult / ActorResult
  -> ResultApplier
  -> SquadRuntime
```

## Enemy Flow

```text
CombatEventDef.enemy_group_id
  -> EnemyEntryImporter
  -> EnemyGroupDef
  -> EnemySpawnDef
  -> ActorTemplateResolver
  -> ActorEntry
  -> ActorRuntime
```

## Layer Responsibilities

### Static Definition

Files:
- `src/expedition_system/actor/ActorTemplate.gd`
- `src/expedition_system/actor/ActorTemplateResolver.gd`

Responsibility:
- define what an actor is
- provide a unified template lookup by `template_id`

### Pre-Departure Config

Files:
- `src/expedition_system/squad/MemberConfig.gd`
- `src/expedition_system/squad/SquadConfig.gd`

Responsibility:
- store player choices before expedition

Current fields:
- `member_id`
- `actor_template_id`
- `equipment_container`
- `equipment_ids`
- `init_hp`

### Expedition Runtime

Files:
- `src/expedition_system/squad/MemberRuntime.gd`
- `src/expedition_system/squad/SquadRuntime.gd`
- `src/expedition_system/squad/SquadRuntimeFactory.gd`
- `src/expedition_system/actor/PlayerActorAssembler.gd`

Responsibility:
- keep expedition-persistent member state

Current fields:
- `member_id`
- `actor_template_id`
- `equipment_container`
- `equipment_ids`
- `current_hp`
- `max_hp`
- `alive`
- `injury_flags`
- `resources`

### Expedition Event Input

Files:
- `src/expedition_system/expedition/ExpeditionLocationDef.gd`
- `src/expedition_system/expedition/EventSelector.gd`

Responsibility:
- define a finite ordered expedition event sequence
- select the current event by `step_index`

Current input format:
- `combat:<enemy_group_id>`
- `rest`

### Battle Input

Files:
- `src/expedition_system/actor/ActorEntry.gd`
- `src/expedition_system/battle/BattleBuilder.gd`

Responsibility:
- convert player members and enemies into battle-ready `ActorEntry`

### Battle Runtime

Files:
- `src/expedition_system/actor/ActorRuntime.gd`
- `src/expedition_system/battle/CombatEngine.gd`

Responsibility:
- `ActorRuntime`: single actor battle runtime
- `CombatEngine`: unified battle execution

### Result Write-Back

Files:
- `src/expedition_system/battle/BattleResult.gd`
- `src/expedition_system/actor/ActorResult.gd`
- `src/expedition_system/battle/ResultApplier.gd`

Responsibility:
- apply battle results back to `SquadRuntime`

## Simplification Goal

This chain was simplified to avoid duplicate template snapshots across layers.

Current policy:
- expedition layer stores expedition state only
- battle layer rebuilds battle input from template + runtime state only when needed
- player actor assembly goes through `PlayerActorAssembler`
- enemy actor assembly goes through `EnemyEntryImporter`
