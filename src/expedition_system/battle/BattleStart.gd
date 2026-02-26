class_name BattleStart extends RefCounted

var battle_id: StringName = &""
var source_event_id: StringName = &""
var location_id: StringName = &""
var step_index: int = -1

var enemy_group_id: StringName = &""

var players: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var rules: Dictionary = {}


func to_dict() -> Dictionary:
	return {
		"battle_id": battle_id,
		"source_event_id": source_event_id,
		"location_id": location_id,
		"step_index": step_index,
		"enemy_group_id": enemy_group_id,
		"players": players.duplicate(true),
		"enemies": enemies.duplicate(true),
		"rules": rules.duplicate(true),
	}
