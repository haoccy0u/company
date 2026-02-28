class_name ExpeditionEventDef extends RefCounted

var event_id: StringName = &""
var event_type: StringName = &""
var location_id: StringName = &""
var step_index: int = -1


func build_base_dict() -> Dictionary:
	return {
		"event_id": event_id,
		"event_type": event_type,
		"location_id": location_id,
		"step_index": step_index,
	}


func to_dict() -> Dictionary:
	return build_base_dict()
