class_name ExpeditionLocationDef extends Resource

@export var location_id: StringName
@export var combat_enemy_groups: Array[StringName] = []
@export var allow_non_combat_stub: bool = false
@export var tags: Array[StringName] = []


func has_combat_content() -> bool:
	return not combat_enemy_groups.is_empty()


func pick_combat_enemy_group(step_index: int = 0) -> StringName:
	if combat_enemy_groups.is_empty():
		return &""
	if step_index < 0:
		step_index = 0
	var idx: int = step_index % combat_enemy_groups.size()
	return combat_enemy_groups[idx]
