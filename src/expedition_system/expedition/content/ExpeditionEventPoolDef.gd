class_name ExpeditionEventPoolDef extends Resource

@export var pool_id: StringName
@export var event_scenes: Array[PackedScene] = []
@export var default_sequence_length: int = 3
@export var allow_repeat: bool = true


func get_scenes_for_difficulty(_difficulty: int) -> Array[PackedScene]:
	var out: Array[PackedScene] = []
	for scene_res in event_scenes:
		if scene_res == null:
			continue
		out.append(scene_res)
	return out
