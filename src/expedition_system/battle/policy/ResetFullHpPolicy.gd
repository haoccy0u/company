extends "res://src/expedition_system/battle/policy/PostBattleHpPolicy.gd"
class_name ResetFullHpPolicy


func get_policy_id() -> StringName:
	return &"reset_full"


func apply_hp(member, _player_result: Dictionary) -> float:
	if member == null:
		return 0.0
	return float(member.max_hp)
