class_name BattleBuilder extends RefCounted

const PlayerActorAssemblerRef = preload("res://src/expedition_system/actor/PlayerActorAssembler.gd")
const EnemyEntryImporterRef = preload("res://src/expedition_system/enemy/EnemyEntryImporter.gd")


static func from_combat_event(combat_event: CombatEventDef, squad_runtime: SquadRuntime) -> BattleStart:
	if combat_event == null:
		push_error("BattleBuilder.from_combat_event failed: combat_event is null")
		return null
	if squad_runtime == null:
		push_error("BattleBuilder.from_combat_event failed: squad_runtime is null")
		return null

	var start := BattleStart.new()
	start.battle_id = StringName("battle_%s" % String(combat_event.event_id))
	start.source_event_id = combat_event.event_id
	start.location_id = combat_event.location_id
	start.step_index = combat_event.step_index
	start.enemy_group_id = combat_event.enemy_group_id

	start.player_entries = _build_player_entries(squad_runtime)
	start.enemy_entries = _build_enemy_entries(combat_event)
	start.rules = {
		"hp_policy_id": &"carry_over",
		"cooldown_stagger": true,
	}

	return start


static func _build_player_entries(squad_runtime: SquadRuntime) -> Array:
	var entries: Array = []

	for member in squad_runtime.members:
		if member == null:
			continue
		if not member.alive:
			continue

		var entry = PlayerActorAssemblerRef.build_actor_entry(member)
		if entry != null:
			entries.append(entry)

	return entries


static func _build_enemy_entries(combat_event: CombatEventDef) -> Array:
	return EnemyEntryImporterRef.from_combat_event(combat_event)
