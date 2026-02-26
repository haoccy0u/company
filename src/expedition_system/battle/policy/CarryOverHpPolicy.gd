extends "res://src/expedition_system/battle/policy/PostBattleHpPolicy.gd"
class_name CarryOverHpPolicy

func get_policy_id() -> StringName:
	return &"carry_over"


func apply_hp(member, player_result: Dictionary) -> float:
	if member == null:
		return 0.0
	return float(player_result.get("hp_after", member.current_hp))
