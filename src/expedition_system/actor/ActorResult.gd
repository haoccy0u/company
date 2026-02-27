extends RefCounted
class_name ActorResult

var member_id: StringName = &""
var hp_before: float = 0.0
var hp_after: float = 0.0
var max_hp: float = 0.0
var alive: bool = false

var extra: Dictionary = {}


func to_dict() -> Dictionary:
	var data: Dictionary = {
		"member_id": member_id,
		"hp_before": hp_before,
		"hp_after": hp_after,
		"max_hp": max_hp,
		"alive": alive,
	}

	for key in extra.keys():
		data[key] = extra[key]

	return data
