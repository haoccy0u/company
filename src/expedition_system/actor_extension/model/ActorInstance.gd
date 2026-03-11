extends Resource
class_name ActorInstance

@export var unit_uid: StringName = &""
@export var member_id: StringName = &""
@export var actor_id: StringName = &""

@export var owner_type: StringName = &"player"
@export var owner_id: StringName = &""
@export var faction: StringName = &"player"
@export var is_persistent: bool = true

@export var level: int = 1
@export var growth_seed: int = 0

@export var equipment_container: ItemContainer
@export var equipment_ids: Array[StringName] = []
## < 0 means use actor scene default hp_max as initial HP.
@export var init_hp: float = -1.0

@export var alive: bool = true
@export var current_hp: float = 0.0
@export var max_hp: float = 0.0

@export var injury_flags: Dictionary = {}
@export var resources: Dictionary = {}
@export var capture_meta: Dictionary = {}
@export var long_states: Dictionary = {}


func is_usable() -> bool:
	return alive and current_hp > 0.0


func get_init_hp(default_max_hp: float) -> float:
	var safe_max_hp: float = maxf(default_max_hp, 0.0)
	if init_hp < 0.0:
		return safe_max_hp
	return clampf(init_hp, 0.0, safe_max_hp)


func set_current_hp(next_hp: float) -> void:
	current_hp = clampf(next_hp, 0.0, maxf(max_hp, 0.0))
	alive = current_hp > 0.0


func apply_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	set_current_hp(current_hp - amount)


func heal(amount: float) -> void:
	if amount <= 0.0:
		return
	set_current_hp(current_hp + amount)
