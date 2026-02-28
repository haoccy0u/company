extends RefCounted
class_name ResultApplier

const ActorResultRef = preload("res://src/expedition_system/actor/ActorResult.gd")
const DEFAULT_HP_POLICY_ID: StringName = &"carry_over"
const CARRY_OVER_HP_POLICY_ID: StringName = &"carry_over"
const CARRY_OVER_HP_POLICY_PATH := "res://src/expedition_system/battle/policy/CarryOverHpPolicy.gd"
const RESET_FULL_HP_POLICY_ID: StringName = &"reset_full"
const RESET_FULL_HP_POLICY_PATH := "res://src/expedition_system/battle/policy/ResetFullHpPolicy.gd"
const PlayerActorAssemblerRef = preload("res://src/expedition_system/actor/PlayerActorAssembler.gd")


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
	if not result.player_actor_results.is_empty():
		for actor_result in result.player_actor_results:
			if actor_result is ActorResultRef:
				_apply_actor_result(actor_result as ActorResultRef, squad_runtime, hp_policy)
		return true

	for row in result.get_player_result_rows():
		if row is Dictionary:
			_apply_player_result_row(row, squad_runtime, hp_policy)

	return true


static func _apply_actor_result(actor_result: ActorResultRef, squad_runtime: SquadRuntime, hp_policy: RefCounted) -> void:
	if actor_result == null or squad_runtime == null:
		return
	if actor_result.member_id.is_empty():
		return

	var member := squad_runtime.find_member(actor_result.member_id)
	if member == null:
		return

	_ensure_member_max_hp(member)
	var next_hp: float = hp_policy.apply_hp(member, actor_result.to_dict())
	member.current_hp = clampf(next_hp, 0.0, maxf(member.max_hp, 0.0))
	member.alive = actor_result.alive


static func _apply_player_result_row(row: Dictionary, squad_runtime: SquadRuntime, hp_policy: RefCounted) -> void:
	if squad_runtime == null:
		return

	var member_id_variant: Variant = row.get("member_id", &"")
	var member_id: StringName = member_id_variant if member_id_variant is StringName else StringName(str(member_id_variant))
	if member_id.is_empty():
		return

	var member := squad_runtime.find_member(member_id)
	if member == null:
		return

	_ensure_member_max_hp(member)
	var next_hp: float = hp_policy.apply_hp(member, row)
	member.current_hp = clampf(next_hp, 0.0, maxf(member.max_hp, 0.0))
	member.alive = bool(row.get("alive", member.current_hp > 0.0))


static func _ensure_member_max_hp(member) -> void:
	if member == null:
		return
	if member.max_hp > 0.0:
		return

	var template := PlayerActorAssemblerRef.resolve_template(member.actor_template_id)
	if template != null:
		member.max_hp = PlayerActorAssemblerRef.get_template_max_hp(template)


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
