class_name ExpeditionStartRequest extends RefCounted

var location: ExpeditionLocationDef
var difficulty: int = 0
var options: Dictionary = {}
var squad: SquadRuntime
var seed: int = 0


func is_valid() -> bool:
	if location == null:
		return false
	if squad == null:
		return false
	if location.location_id.is_empty():
		return false
	if squad.members.is_empty():
		return false
	return true


func to_dict() -> Dictionary:
	return {
		"location_id": location.location_id if location != null else &"",
		"difficulty": difficulty,
		"options": options.duplicate(true),
		"squad_id": squad.source_squad_id if squad != null else &"",
		"seed": seed,
	}
