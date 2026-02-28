class_name MemberConfig extends Resource

@export var member_id: StringName
@export var actor_template_id: StringName
@export var equipment_container: ItemContainer
@export var equipment_ids: Array[StringName] = []

## < 0 means use template max_hp as initial HP (debug/test override).
@export var init_hp: float = -1.0


func get_init_hp(default_max_hp: float) -> float:
	var safe_max_hp: float = maxf(default_max_hp, 0.0)
	if init_hp < 0.0:
		return safe_max_hp
	return clampf(init_hp, 0.0, safe_max_hp)
