class_name CombatEventDef extends RefCounted

const EVENT_TYPE: StringName = &"combat"

var event_id: StringName
var event_type: StringName = EVENT_TYPE
var location_id: StringName
var enemy_group_id: StringName
var difficulty_seed: int = 0
var step_index: int = -1


static func create(_location_id: StringName, _enemy_group_id: StringName, _step_index: int, _difficulty_seed: int = 0) -> CombatEventDef:
	var event := CombatEventDef.new()
	event.location_id = _location_id
	event.enemy_group_id = _enemy_group_id
	event.step_index = _step_index
	event.difficulty_seed = _difficulty_seed
	event.event_id = StringName("%s_combat_%d" % [String(_location_id), _step_index])
	return event


func to_dict() -> Dictionary:
	return {
		"event_id": event_id,
		"event_type": event_type,
		"location_id": location_id,
		"enemy_group_id": enemy_group_id,
		"difficulty_seed": difficulty_seed,
		"step_index": step_index,
	}
