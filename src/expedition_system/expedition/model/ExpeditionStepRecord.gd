extends RefCounted
class_name ExpeditionStepRecord

var run_id: StringName = &""
var step_index: int = -1
var event_id: StringName = &""
var event_type: StringName = &""
var event_payload: Dictionary = {}
var resolution_payload: Dictionary = {}


func to_dict() -> Dictionary:
	return {
		"run_id": run_id,
		"step_index": step_index,
		"event_id": event_id,
		"event_type": event_type,
		"event_payload": event_payload.duplicate(true),
		"resolution_payload": resolution_payload.duplicate(true),
	}
