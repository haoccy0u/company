class_name BattleSession extends RefCounted


func run_stub_from_combat_event(combat_event: CombatEventDef, squad_runtime: SquadRuntime) -> BattleResult:
	if combat_event == null:
		push_error("BattleSession.run_stub_from_combat_event failed: combat_event is null")
		return null
	if squad_runtime == null:
		push_error("BattleSession.run_stub_from_combat_event failed: squad_runtime is null")
		return null

	var result := BattleResult.new()
	result.battle_id = StringName("battle_%s" % String(combat_event.event_id))
	result.source_event_id = combat_event.event_id
	result.event_type = combat_event.event_type
	result.step_index = combat_event.step_index
	result.enemy_group_id = combat_event.enemy_group_id

	result.player_count = squad_runtime.members.size()
	result.living_player_count = _count_living_members(squad_runtime)
	result.success = true

	# Stub rule: if any player is alive, treat the stub battle as victory.
	if result.living_player_count > 0:
		result.victory = true
		result.ended_reason = &"stub_victory"
	else:
		result.victory = false
		result.ended_reason = &"stub_no_living_players"

	result.log.append({
		"type": &"battle_stub",
		"event_id": combat_event.event_id,
		"enemy_group_id": combat_event.enemy_group_id,
		"living_player_count": result.living_player_count,
		"victory": result.victory,
	})

	return result


func _count_living_members(squad_runtime: SquadRuntime) -> int:
	var count: int = 0
	for member in squad_runtime.members:
		if member != null and member.is_usable():
			count += 1
	return count
