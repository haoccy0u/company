extends RefCounted
class_name ResultApplier

const DEFAULT_HP_POLICY_ID: StringName = &"carry_over"
const CARRY_OVER_HP_POLICY_ID: StringName = &"carry_over"
const CARRY_OVER_HP_POLICY_PATH := "res://src/expedition_system/battle/policy/CarryOverHpPolicy.gd"
const RESET_FULL_HP_POLICY_ID: StringName = &"reset_full"
const RESET_FULL_HP_POLICY_PATH := "res://src/expedition_system/battle/policy/ResetFullHpPolicy.gd"


static func apply_stub_result_to_squad_runtime(
	result: BattleResult,
	squad_runtime: SquadRuntime,
	hp_policy_id: StringName = DEFAULT_HP_POLICY_ID
) -> bool:
	if result == null:
		push_error("ResultApplier.apply_stub_result_to_squad_runtime failed: result is null")
		return false
	if squad_runtime == null:
		push_error("ResultApplier.apply_stub_result_to_squad_runtime failed: squad_runtime is null")
		return false

	var hp_policy: RefCounted = _make_hp_policy(hp_policy_id)

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

		var next_hp: float = hp_policy.apply_hp(member, row)
		member.current_hp = clampf(next_hp, 0.0, maxf(member.max_hp, 0.0))
		member.alive = bool(row.get("alive", member.current_hp > 0.0))

	return true


static func _make_hp_policy(hp_policy_id: StringName) -> RefCounted:
	match hp_policy_id:
		CARRY_OVER_HP_POLICY_ID:
			return _load_policy(CARRY_OVER_HP_POLICY_PATH)
		RESET_FULL_HP_POLICY_ID:
			return _load_policy(RESET_FULL_HP_POLICY_PATH)
		_:
			push_warning("ResultApplier: unknown hp_policy_id=%s, fallback to carry_over" % String(hp_policy_id))
			return _load_policy(CARRY_OVER_HP_POLICY_PATH)


static func _load_policy(script_path: String) -> RefCounted:
	var script_res := load(script_path)
	if script_res == null:
		push_warning("ResultApplier: failed to load hp policy script: %s; fallback inline policy" % script_path)
		if script_path == RESET_FULL_HP_POLICY_PATH:
			return _ResetFullHpPolicyFallback.new()
		return _CarryOverHpPolicyFallback.new()
	return script_res.new()


class _CarryOverHpPolicyFallback extends RefCounted:
	func apply_hp(member, player_result: Dictionary) -> float:
		if member == null:
			return 0.0
		return float(player_result.get("hp_after", member.current_hp))


class _ResetFullHpPolicyFallback extends RefCounted:
	func apply_hp(member, _player_result: Dictionary) -> float:
		if member == null:
			return 0.0
		return float(member.max_hp)
