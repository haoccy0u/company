extends RefCounted
class_name PostBattleHpPolicy

const POLICY_ID: StringName = &"base"


func get_policy_id() -> StringName:
	return POLICY_ID


func apply_hp(member, _player_result: Dictionary) -> float:
	if member == null:
		return 0.0
	return member.current_hp
