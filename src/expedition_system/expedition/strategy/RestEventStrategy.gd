class_name RestEventStrategy extends RefCounted

const RestEventDefRef = preload("res://src/expedition_system/expedition/RestEventDef.gd")


func strategy_id() -> StringName:
	return &"rest"


func can_build(location: ExpeditionLocationDef, _step_index: int) -> bool:
	if location == null:
		return false
	return location.get_event_type(_step_index) == &"rest"


func build_event(location: ExpeditionLocationDef, step_index: int) -> RefCounted:
	if location == null:
		return null
	if location.get_event_type(step_index) != &"rest":
		return null
	return RestEventDefRef.create(location.location_id, step_index, RestEventDefRef.DEFAULT_HEAL_AMOUNT)
