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
	result.player_results = _build_stub_player_results(combat_event, squad_runtime)

	var living_after_stub: int = 0
	for member_result in result.player_results:
		if bool(member_result.get("alive", false)):
			living_after_stub += 1
	result.living_player_count = living_after_stub

	# Stub rule: if any player is alive, treat the stub battle as victory.
	if result.living_player_count > 0:
		result.victory = true
		result.ended_reason = &"stub_victory"
	else:
		result.victory = false
		result.ended_reason = &"stub_no_living_players"

	result.event_log.append({
		"type": &"battle_stub",
		"event_id": combat_event.event_id,
		"enemy_group_id": combat_event.enemy_group_id,
		"step_index": combat_event.step_index,
		"sim_damage": _calc_stub_damage(combat_event),
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


func _build_stub_player_results(combat_event: CombatEventDef, squad_runtime: SquadRuntime) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var damage_left: float = _calc_stub_damage(combat_event)

	for member in squad_runtime.members:
		if member == null:
			continue

		var current_hp: float = maxf(member.current_hp, 0.0)
		var max_hp: float = maxf(member.max_hp, 0.0)
		var next_hp: float = current_hp

		# Stub behavior: apply deterministic damage to the first living member only.
		if damage_left > 0.0 and member.is_usable():
			next_hp = maxf(current_hp - damage_left, 0.0)
			damage_left = 0.0

		results.append({
			"member_id": member.member_id,
			"hp_before": current_hp,
			"hp_after": next_hp,
			"max_hp": max_hp,
			"alive": next_hp > 0.0,
		})

	return results


func _calc_stub_damage(combat_event: CombatEventDef) -> float:
	# Deterministic small damage so repeated tests show changing squad state.
	var step_factor: int = max(combat_event.step_index + 1, 1)
	return float(8 + (step_factor * 3))
