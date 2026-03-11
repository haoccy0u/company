class_name ExpeditionResult extends RefCounted

var run_id: StringName = &""
var location_id: StringName = &""
var difficulty: int = 0
var end_reason: StringName = &""
var completed_steps: int = 0
var seed: int = 0
var reward_snapshot: Dictionary = {}
var step_records: Array[ExpeditionStepRecord] = []
var final_squad_snapshot: SquadRuntime


func to_dict() -> Dictionary:
	var record_rows: Array[Dictionary] = []
	for record in step_records:
		if record == null:
			continue
		record_rows.append(record.to_dict())

	var squad_rows: Array[Dictionary] = []
	if final_squad_snapshot != null:
		for member in final_squad_snapshot.members:
			if member == null:
				continue
			squad_rows.append({
				"unit_uid": member.unit_uid,
				"member_id": member.member_id,
				"actor_id": member.actor_id,
				"current_hp": member.current_hp,
				"max_hp": member.max_hp,
				"alive": member.alive,
			})

	return {
		"run_id": run_id,
		"location_id": location_id,
		"difficulty": difficulty,
		"end_reason": end_reason,
		"completed_steps": completed_steps,
		"seed": seed,
		"reward_snapshot": reward_snapshot.duplicate(true),
		"step_records": record_rows,
		"final_squad_members": squad_rows,
	}
