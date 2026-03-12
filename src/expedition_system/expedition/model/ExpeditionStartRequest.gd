extends RefCounted
class_name ExpeditionStartRequest

var location: Resource
var difficulty: int = 0
var options: Dictionary = {}
var squad_scene: PackedScene
var player_roster_state: Node
var selected_player_actor_ids: Array[StringName] = []
var actor_catalog: Resource
var run_seed: int = 0


func is_valid() -> bool:
	if location == null:
		return false
	if squad_scene == null:
		return false
	if player_roster_state == null:
		return false
	if not player_roster_state.has_method("find_player_actor"):
		return false
	if actor_catalog == null:
		return false
	if selected_player_actor_ids.is_empty():
		return false
	if location.location_id.is_empty():
		return false
	for player_actor_id in selected_player_actor_ids:
		if player_actor_id.is_empty():
			return false
	return true


func to_dict() -> Dictionary:
	var selected_ids: Array[String] = []
	for player_actor_id in selected_player_actor_ids:
		selected_ids.append(String(player_actor_id))

	return {
		"location_id": location.location_id if location != null else &"",
		"difficulty": difficulty,
		"options": options.duplicate(true),
		"squad_scene_path": squad_scene.resource_path if squad_scene != null else "",
		"selected_player_actor_ids": selected_ids,
		"seed": run_seed,
	}
