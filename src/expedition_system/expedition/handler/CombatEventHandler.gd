class_name CombatEventHandler extends RefCounted

const BattleBuilderRef = preload("res://src/expedition_system/battle/BattleBuilder.gd")
const BattleSessionRef = preload("res://src/expedition_system/battle/BattleSession.gd")


func can_handle(event: RefCounted) -> bool:
	return event is CombatEventDef


func build_battle_start(event: RefCounted, squad_runtime: SquadRuntime) -> BattleStart:
	if not can_handle(event):
		return null
	return BattleBuilderRef.from_combat_event(event as CombatEventDef, squad_runtime)


func resolve_stub(event: RefCounted, squad_runtime: SquadRuntime) -> Dictionary:
	if not can_handle(event):
		return {}

	var battle_session := BattleSessionRef.new()
	var battle_result = battle_session.run_stub_from_combat_event(event as CombatEventDef, squad_runtime)
	return {
		"completed": battle_result != null,
		"battle_result": battle_result,
	}
