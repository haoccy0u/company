extends RefCounted
class_name ExpeditionResult

var run_id: StringName = &""
var location_id: StringName = &""
var difficulty: int = 0
var end_reason: StringName = &""
var completed_steps: int = 0
var run_seed: int = 0
var reward_snapshot: Dictionary = {}
var step_records: Array = []
var final_squad_snapshot: Dictionary = {}


func to_dict() -> Dictionary:
	var record_rows: Array[Dictionary] = []
	for record in step_records:
		if record == null:
			continue
		record_rows.append(record.to_dict())

	var squad_rows: Array[Dictionary] = []
	var members_any: Variant = final_squad_snapshot.get("members", [])
	if members_any is Array:
		for row in members_any:
			if row is Dictionary:
				squad_rows.append((row as Dictionary).duplicate(true))

	return {
		"run_id": run_id,
		"location_id": location_id,
		"difficulty": difficulty,
		"end_reason": end_reason,
		"completed_steps": completed_steps,
		"seed": run_seed,
		"reward_snapshot": reward_snapshot.duplicate(true),
		"step_records": record_rows,
		"final_squad_members": squad_rows,
	}
