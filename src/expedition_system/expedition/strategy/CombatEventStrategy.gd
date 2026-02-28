class_name CombatEventStrategy extends RefCounted

const CombatEventDefRef = preload("res://src/expedition_system/expedition/CombatEventDef.gd")


func strategy_id() -> StringName:
	return &"combat"


func can_build(location: ExpeditionLocationDef, step_index: int) -> bool:
	if location == null:
		return false
	return location.get_event_type(step_index) == &"combat" and not location.get_event_payload_id(step_index).is_empty()


func build_event(location: ExpeditionLocationDef, step_index: int) -> RefCounted:
	if location == null:
		return null

	var enemy_group_id: StringName = location.get_event_payload_id(step_index)
	if enemy_group_id.is_empty():
		return null
	return CombatEventDefRef.create(location.location_id, enemy_group_id, step_index, step_index)
