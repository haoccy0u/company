class_name BattleResult extends RefCounted

var battle_id: StringName = &""
var source_event_id: StringName = &""
var event_type: StringName = &""
var step_index: int = -1

var success: bool = false
var victory: bool = false
var ended_reason: StringName = &""

var player_count: int = 0
var living_player_count: int = 0
var enemy_group_id: StringName = &""

var player_actor_results: Array = [] # ActorResult[]
var player_results: Array[Dictionary] = []
var event_log: Array[Dictionary] = []


func to_dict() -> Dictionary:
	return {
		"battle_id": battle_id,
		"source_event_id": source_event_id,
		"event_type": event_type,
		"step_index": step_index,
		"success": success,
		"victory": victory,
		"ended_reason": ended_reason,
		"player_count": player_count,
		"living_player_count": living_player_count,
		"enemy_group_id": enemy_group_id,
		"player_results": _actor_results_to_dict_array(player_actor_results) if not player_actor_results.is_empty() else player_results.duplicate(true),
		"player_actor_results": _actor_results_to_dict_array(player_actor_results),
		"log": event_log.duplicate(true),
	}


func _actor_results_to_dict_array(results: Array) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for item in results:
		if item == null:
			continue
		rows.append(item.to_dict())
	return rows
