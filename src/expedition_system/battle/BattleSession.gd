class_name BattleSession extends RefCounted

const ActorResultRef = preload("res://src/expedition_system/actor/ActorResult.gd")
const BattleBuilderRef = preload("res://src/expedition_system/battle/BattleBuilder.gd")
const CombatEngineRef = preload("res://src/expedition_system/battle/CombatEngine.gd")


func run_stub_from_combat_event(combat_event: CombatEventDef, squad_runtime: SquadRuntime) -> BattleResult:
	if combat_event == null:
		push_error("BattleSession.run_stub_from_combat_event failed: combat_event is null")
		return null
	if squad_runtime == null:
		push_error("BattleSession.run_stub_from_combat_event failed: squad_runtime is null")
		return null

	var start := BattleBuilderRef.from_combat_event(combat_event, squad_runtime)
	if start == null:
		push_error("BattleSession.run_stub_from_combat_event failed: BattleBuilder returned null")
		return null

	return run_stub_from_battle_start(start)


func run_stub_from_battle_start(start: BattleStart) -> BattleResult:
	if start == null:
		push_error("BattleSession.run_stub_from_battle_start failed: start is null")
		return null

	var result := BattleResult.new()
	result.battle_id = start.battle_id
	result.source_event_id = start.source_event_id
	result.event_type = &"combat"
	result.step_index = start.step_index
	result.enemy_group_id = start.enemy_group_id

	result.player_count = start.player_entries.size()

	var engine := CombatEngineRef.new()
	var run_outcome: Dictionary = engine.run_stub_until_end(start)
	if run_outcome.is_empty():
		push_error("BattleSession.run_stub_from_battle_start failed: CombatEngine returned empty outcome")
		return null

	result.success = bool(run_outcome.get("success", false))
	result.victory = bool(run_outcome.get("victory", false))
	result.ended_reason = _as_string_name(run_outcome.get("end_reason", &"stub_failed"))
	result.living_player_count = int(run_outcome.get("living_player_count", 0))
	result.player_actor_results = _cast_actor_results_array(run_outcome.get("player_actor_results", []))
	result.event_log = _cast_event_log_array(run_outcome.get("event_log", []))

	return result


func _cast_actor_results_array(value: Variant) -> Array:
	var rows: Array = []
	if value is Array:
		for item in value:
			if item == null:
				continue
			if item is RefCounted and item.has_method("to_dict"):
				rows.append(item)
				continue
			if item is Dictionary:
				var row := ActorResultRef.new()
				row.member_id = _as_string_name(item.get("member_id", &""))
				row.hp_before = float(item.get("hp_before", 0.0))
				row.hp_after = float(item.get("hp_after", 0.0))
				row.max_hp = float(item.get("max_hp", 0.0))
				row.alive = bool(item.get("alive", false))
				rows.append(row)
	return rows


func _cast_event_log_array(value: Variant) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if value is Array:
		for item in value:
			if item is Dictionary:
				rows.append(item)
	return rows


func _as_string_name(value: Variant) -> StringName:
	if value is StringName:
		return value
	return StringName(str(value))
