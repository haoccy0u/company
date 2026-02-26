class_name NonCombatEventStub extends RefCounted

const EVENT_TYPE: StringName = &"non_combat"

var event_id: StringName
var event_type: StringName = EVENT_TYPE
var location_id: StringName
var step_index: int = -1


static func create(_location_id: StringName, _step_index: int) -> NonCombatEventStub:
	var event := NonCombatEventStub.new()
	event.location_id = _location_id
	event.step_index = _step_index
	event.event_id = StringName("%s_non_combat_%d" % [String(_location_id), _step_index])
	return event


func to_dict() -> Dictionary:
	return {
		"event_id": event_id,
		"event_type": event_type,
		"location_id": location_id,
		"step_index": step_index,
	}
