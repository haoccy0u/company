class_name CombatEventDef extends ExpeditionEventDef

const EVENT_TYPE: StringName = &"combat"

var enemy_group_id: StringName
var difficulty_seed: int = 0


func _init() -> void:
	event_type = EVENT_TYPE


static func create(_location_id: StringName, _enemy_group_id: StringName, _step_index: int, _difficulty_seed: int = 0) -> CombatEventDef:
	var event := CombatEventDef.new()
	event.event_type = EVENT_TYPE
	event.location_id = _location_id
	event.enemy_group_id = _enemy_group_id
	event.step_index = _step_index
	event.difficulty_seed = _difficulty_seed
	event.event_id = StringName("%s_combat_%d" % [String(_location_id), _step_index])
	return event


func to_dict() -> Dictionary:
	var data := build_base_dict()
	data["enemy_group_id"] = enemy_group_id
	data["difficulty_seed"] = difficulty_seed
	return data
