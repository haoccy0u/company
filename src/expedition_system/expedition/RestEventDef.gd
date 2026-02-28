class_name RestEventDef extends ExpeditionEventDef

const EVENT_TYPE: StringName = &"rest"
const DEFAULT_HEAL_AMOUNT: float = 10.0

var heal_amount: float = DEFAULT_HEAL_AMOUNT


func _init() -> void:
	event_type = EVENT_TYPE


static func create(_location_id: StringName, _step_index: int, _heal_amount: float = DEFAULT_HEAL_AMOUNT) -> RestEventDef:
	var event := RestEventDef.new()
	event.event_type = EVENT_TYPE
	event.location_id = _location_id
	event.step_index = _step_index
	event.heal_amount = _heal_amount
	event.event_id = StringName("%s_rest_%d" % [String(_location_id), _step_index])
	return event


func to_dict() -> Dictionary:
	var data := build_base_dict()
	data["heal_amount"] = heal_amount
	return data
