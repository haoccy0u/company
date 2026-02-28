class_name RestEventDef extends RefCounted

const EVENT_TYPE: StringName = &"rest"
const DEFAULT_HEAL_AMOUNT: float = 10.0

var event_id: StringName
var event_type: StringName = EVENT_TYPE
var location_id: StringName
var step_index: int = -1
var heal_amount: float = DEFAULT_HEAL_AMOUNT


func to_dict() -> Dictionary:
	return {
		"event_id": event_id,
		"event_type": event_type,
		"location_id": location_id,
		"step_index": step_index,
		"heal_amount": heal_amount,
	}
