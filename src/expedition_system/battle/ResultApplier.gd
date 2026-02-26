class_name ResultApplier extends RefCounted


static func apply_stub_result_to_squad_runtime(result: BattleResult, squad_runtime: SquadRuntime) -> bool:
	if result == null:
		push_error("ResultApplier.apply_stub_result_to_squad_runtime failed: result is null")
		return false
	if squad_runtime == null:
		push_error("ResultApplier.apply_stub_result_to_squad_runtime failed: squad_runtime is null")
		return false

	for row in result.player_results:
		if not (row is Dictionary):
			continue

		var member_id_variant: Variant = row.get("member_id", &"")
		var member_id: StringName = member_id_variant if member_id_variant is StringName else StringName(str(member_id_variant))
		if member_id.is_empty():
			continue

		var member := squad_runtime.find_member(member_id)
		if member == null:
			continue

		member.current_hp = clampf(float(row.get("hp_after", member.current_hp)), 0.0, maxf(member.max_hp, 0.0))
		member.alive = bool(row.get("alive", member.current_hp > 0.0))

	return true
