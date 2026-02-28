class_name EventSelector extends RefCounted

const CombatEventStrategyRef = preload("res://src/expedition_system/expedition/strategy/CombatEventStrategy.gd")
const RestEventStrategyRef = preload("res://src/expedition_system/expedition/strategy/RestEventStrategy.gd")


static func get_strategies() -> Array:
	return [
		CombatEventStrategyRef.new(),
		RestEventStrategyRef.new(),
	]


static func select_next(location: ExpeditionLocationDef, step_index: int) -> ExpeditionEventDef:
	if location == null:
		push_error("EventSelector.select_next failed: location is null")
		return null

	for strategy in get_strategies():
		if strategy == null:
			continue
		if not strategy.can_build(location, step_index):
			continue
		var event: ExpeditionEventDef = strategy.build_event(location, step_index)
		if event != null:
			return event

	push_warning("EventSelector.select_next failed: no event available | location_id=%s" % String(location.location_id))
	return null
