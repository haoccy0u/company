class_name RestEventHandler extends RefCounted

const RestEventDefRef = preload("res://src/expedition_system/expedition/RestEventDef.gd")


func can_handle(event: RefCounted) -> bool:
	return event is RestEventDefRef


func build_battle_start(_event: RefCounted, _squad_runtime: SquadRuntime) -> BattleStart:
	return null


func resolve_stub(event: RefCounted, squad_runtime: SquadRuntime) -> Dictionary:
	if not can_handle(event) or squad_runtime == null:
		return {}

	var rest_event = event
	var healed_members: Array[StringName] = []
	for member in squad_runtime.members:
		if member == null or not member.alive:
			continue
		var next_hp: float = clampf(member.current_hp + rest_event.heal_amount, 0.0, member.max_hp)
		if next_hp > member.current_hp:
			healed_members.append(member.member_id)
		member.current_hp = next_hp
		member.alive = member.current_hp > 0.0

	return {
		"completed": true,
		"event_type": rest_event.event_type,
		"event_id": rest_event.event_id,
		"healed_members": healed_members,
		"heal_amount": rest_event.heal_amount,
	}
