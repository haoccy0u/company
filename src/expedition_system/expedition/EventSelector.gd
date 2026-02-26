class_name EventSelector extends RefCounted


static func select_next(location: ExpeditionLocationDef, step_index: int) -> RefCounted:
	if location == null:
		push_error("EventSelector.select_next failed: location is null")
		return null

	var enemy_group_id: StringName = location.pick_combat_enemy_group(step_index)
	if not enemy_group_id.is_empty():
		return CombatEventDef.create(location.location_id, enemy_group_id, step_index, step_index)

	if location.allow_non_combat_stub:
		return NonCombatEventStub.create(location.location_id, step_index)

	push_warning("EventSelector.select_next failed: no event available | location_id=%s" % String(location.location_id))
	return null
