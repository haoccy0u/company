class_name BattleBuilder extends RefCounted


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

	start.players = _build_player_entries(squad_runtime)
	start.enemies = _build_enemy_entries(combat_event)
	start.rules = {
		"hp_policy_id": &"carry_over",
		"cooldown_stagger": true,
	}

	return start


static func _build_player_entries(squad_runtime: SquadRuntime) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []

	for member in squad_runtime.members:
		if member == null:
			continue
		if not member.alive:
			continue

		entries.append({
			"actor_id": StringName("p_%s" % String(member.member_id)),
			"camp": &"player",
			"member_id": member.member_id,
			"actor_template_id": member.actor_template_id,
			"hp": member.current_hp,
			"max_hp": member.max_hp,
			"ai_id": member.ai_id,
			"action_ids": member.action_ids.duplicate(),
			"passive_ids": member.passive_ids.duplicate(),
			"equipment_ids": member.equipment_ids.duplicate(),
		})

	return entries


static func _build_enemy_entries(combat_event: CombatEventDef) -> Array[Dictionary]:
	# Stub builder: one placeholder enemy entry derived from enemy_group_id.
	return [
		{
			"actor_id": StringName("e_%d_0" % max(combat_event.step_index, 0)),
			"camp": &"enemy",
			"enemy_group_id": combat_event.enemy_group_id,
			"actor_template_id": StringName("%s_enemy" % String(combat_event.enemy_group_id)),
			"count": 1,
		}
	]
