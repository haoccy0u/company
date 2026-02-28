class_name ExpeditionEventRouter extends RefCounted

const CombatEventHandlerRef = preload("res://src/expedition_system/expedition/handler/CombatEventHandler.gd")
const RestEventHandlerRef = preload("res://src/expedition_system/expedition/handler/RestEventHandler.gd")


static func _handlers() -> Array:
	return [
		CombatEventHandlerRef.new(),
		RestEventHandlerRef.new(),
	]


static func build_battle_start(event: RefCounted, squad_runtime: SquadRuntime) -> BattleStart:
	var handler = _find_handler(event)
	if handler == null:
		return null
	return handler.build_battle_start(event, squad_runtime)


static func resolve_stub(event: RefCounted, squad_runtime: SquadRuntime) -> Dictionary:
	var handler = _find_handler(event)
	if handler == null:
		return {}
	return handler.resolve_stub(event, squad_runtime)


static func _find_handler(event: RefCounted):
	for handler in _handlers():
		if handler != null and handler.can_handle(event):
			return handler
	return null
