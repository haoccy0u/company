class_name BattleStart extends RefCounted

var battle_id: StringName = &""
var source_event_id: StringName = &""
var location_id: StringName = &""
var step_index: int = -1

var enemy_group_id: StringName = &""

var player_entries: Array = [] # ActorEntry[]
var enemy_entries: Array = [] # ActorEntry[]

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
		"players": _entries_to_dict_array(player_entries) if not player_entries.is_empty() else players.duplicate(true),
		"enemies": _entries_to_dict_array(enemy_entries) if not enemy_entries.is_empty() else enemies.duplicate(true),
		"player_entries": _entries_to_dict_array(player_entries),
		"enemy_entries": _entries_to_dict_array(enemy_entries),
		"rules": rules.duplicate(true),
	}


func _entries_to_dict_array(entries: Array) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for entry in entries:
		if entry == null:
			continue
		rows.append(entry.to_dict())
	return rows
