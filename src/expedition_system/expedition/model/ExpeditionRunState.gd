class_name ExpeditionRunState extends RefCounted

const PHASE_IDLE: StringName = &"idle"
const PHASE_ACTIVE_EVENT: StringName = &"active_event"
const PHASE_WAITING_DECISION: StringName = &"waiting_decision"
const PHASE_ENDED: StringName = &"ended"

var run_id: StringName = &""
var location_id: StringName = &""
var difficulty: int = 0
var options: Dictionary = {}
var seed: int = 0
var generated_sequence: Array[PackedScene] = []
var step_index: int = -1
var phase: StringName = PHASE_IDLE
var squad_runtime: SquadRuntime


func reset() -> void:
	run_id = &""
	location_id = &""
	difficulty = 0
	options = {}
	seed = 0
	generated_sequence.clear()
	step_index = -1
	phase = PHASE_IDLE
	squad_runtime = null


func is_active() -> bool:
	return phase == PHASE_ACTIVE_EVENT or phase == PHASE_WAITING_DECISION


func to_dict() -> Dictionary:
	var sequence_scene_paths: Array[String] = []
	for scene_res in generated_sequence:
		if scene_res == null:
			sequence_scene_paths.append("")
			continue
		sequence_scene_paths.append(scene_res.resource_path)

	return {
		"run_id": run_id,
		"location_id": location_id,
		"difficulty": difficulty,
		"options": options.duplicate(true),
		"seed": seed,
		"sequence_scene_paths": sequence_scene_paths,
		"step_index": step_index,
		"phase": phase,
		"sequence_length": generated_sequence.size(),
	}
