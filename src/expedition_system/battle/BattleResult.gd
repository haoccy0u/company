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

var log: Array[Dictionary] = []


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
		"log": log.duplicate(true),
	}
