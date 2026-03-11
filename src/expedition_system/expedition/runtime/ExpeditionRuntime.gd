extends Node
class_name ExpeditionRuntime

const RunStateRef = preload("res://src/expedition_system/expedition/model/ExpeditionRunState.gd")
const StepRecordRef = preload("res://src/expedition_system/expedition/model/ExpeditionStepRecord.gd")
const ResultRef = preload("res://src/expedition_system/expedition/model/ExpeditionResult.gd")

const END_REASON_SEQUENCE_COMPLETED: StringName = &"sequence_completed"
const END_REASON_RETREAT: StringName = &"retreat"

signal run_started(run_id: StringName)
signal event_entered(step_index: int, event_id: StringName, event_type: StringName)
signal event_completed(step_index: int, step_record: RefCounted)
signal decision_required(step_index: int)
signal run_ended(result: RefCounted)

@export var auto_destroy_on_retreat: bool = true
@export var auto_enter_first_event: bool = true

var _state: RefCounted = RunStateRef.new()
var _location: Resource
var _current_event_scene: PackedScene
var _current_event_instance: Node
var _current_event_id: StringName = &""
var _current_event_type: StringName = &""
var _step_records: Array = []
var _result_history: Array = []
var _latest_result: RefCounted
var _event_host: Node
var _squad_host: Node


func _ready() -> void:
	_ensure_event_host()
	_ensure_squad_host()


func _exit_tree() -> void:
	_clear_current_event_instance()
	_clear_squad_runtime()


func start_new_run(request: RefCounted) -> bool:
	if request == null or not request.is_valid():
		push_error("ExpeditionRuntime.start_new_run failed: invalid request")
		return false
	if _state.phase == RunStateRef.PHASE_ACTIVE_EVENT or _state.phase == RunStateRef.PHASE_WAITING_DECISION:
		push_warning("ExpeditionRuntime.start_new_run blocked: current run still active")
		return false

	var run_seed: int = request.run_seed if request.run_seed != 0 else _make_seed()
	var sequence: Array[PackedScene] = _build_sequence(request.location, request.difficulty, request.options, run_seed)
	if sequence.is_empty():
		push_error("ExpeditionRuntime.start_new_run failed: generated sequence is empty")
		return false

	var squad_runtime = _build_squad_runtime(request)
	if squad_runtime == null:
		push_error("ExpeditionRuntime.start_new_run failed: squad runtime build failed")
		return false

	_reset_active_state()
	_location = request.location
	_state.run_id = _build_run_id(run_seed)
	_state.location_id = request.location.location_id
	_state.difficulty = request.difficulty
	_state.options = request.options.duplicate(true)
	_state.run_seed = run_seed
	_state.generated_sequence = sequence
	_state.step_index = -1
	_state.phase = RunStateRef.PHASE_IDLE
	_state.squad_runtime = squad_runtime
	run_started.emit(_state.run_id)
	if auto_enter_first_event:
		var entered := choose_continue()
		if not entered:
			push_error("ExpeditionRuntime.start_new_run failed: auto enter first event failed")
			return false
	return true


func enter_next_event() -> Node:
	if _state.phase == RunStateRef.PHASE_ENDED:
		push_warning("ExpeditionRuntime.enter_next_event blocked: run already ended")
		return null
	if _state.phase != RunStateRef.PHASE_IDLE and _state.phase != RunStateRef.PHASE_WAITING_DECISION:
		push_warning("ExpeditionRuntime.enter_next_event blocked: invalid phase=%s" % String(_state.phase))
		return null
	if _current_event_instance != null:
		push_warning("ExpeditionRuntime.enter_next_event blocked: current event not completed")
		return null

	var next_index: int = _state.step_index + 1
	if next_index >= _state.generated_sequence.size():
		_end_run(END_REASON_SEQUENCE_COMPLETED)
		return null

	var previous_step_index: int = _state.step_index
	var previous_phase: StringName = _state.phase

	var next_scene: PackedScene = _state.generated_sequence[next_index]
	if next_scene == null:
		push_error("ExpeditionRuntime.enter_next_event failed: next scene is null")
		return null

	_state.step_index = next_index
	_state.phase = RunStateRef.PHASE_ACTIVE_EVENT
	_current_event_scene = next_scene
	if not _start_current_event_instance(next_scene):
		push_error("ExpeditionRuntime.enter_next_event failed: event scene start failed")
		_state.step_index = previous_step_index
		_state.phase = previous_phase
		_current_event_scene = null
		return null

	event_entered.emit(next_index, _current_event_id, _current_event_type)
	return _current_event_instance


func choose_continue() -> bool:
	if _state.phase != RunStateRef.PHASE_IDLE and _state.phase != RunStateRef.PHASE_WAITING_DECISION:
		push_warning("ExpeditionRuntime.choose_continue blocked: invalid phase=%s" % String(_state.phase))
		return false
	return enter_next_event() != null


func choose_retreat() -> RefCounted:
	if _state.phase != RunStateRef.PHASE_WAITING_DECISION:
		push_warning("ExpeditionRuntime.choose_retreat blocked: phase is not waiting_decision")
		return null

	var result: RefCounted = _end_run(END_REASON_RETREAT)
	if auto_destroy_on_retreat and is_inside_tree():
		queue_free()
	return result


func get_state() -> RefCounted:
	return _state


func get_current_event_instance() -> Node:
	return _current_event_instance


func get_current_event() -> Node:
	return _current_event_instance


func get_latest_result() -> RefCounted:
	return _latest_result


func get_result_history() -> Array:
	return _result_history.duplicate()


func _build_sequence(
	location: Resource,
	difficulty: int,
	options: Dictionary,
	run_seed: int
) -> Array[PackedScene]:
	var source_scenes: Array[PackedScene] = _collect_source_scenes(location, difficulty)
	if source_scenes.is_empty():
		return []

	var sequence_length: int = int(options.get("sequence_length", _default_sequence_length(location)))
	sequence_length = maxi(sequence_length, 1)

	var allow_repeat: bool = location.event_pool.allow_repeat

	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed

	var out: Array[PackedScene] = []
	var working: Array[PackedScene] = source_scenes.duplicate()
	while out.size() < sequence_length and not working.is_empty():
		var pick_index: int = rng.randi_range(0, working.size() - 1)
		var picked_scene: PackedScene = working[pick_index]
		if picked_scene != null:
			out.append(picked_scene)
		if not allow_repeat:
			working.remove_at(pick_index)
	return out


func _collect_source_scenes(location: Resource, difficulty: int) -> Array[PackedScene]:
	if location == null or location.event_pool == null:
		return []
	return location.event_pool.get_scenes_for_difficulty(difficulty)


func _default_sequence_length(location: Resource) -> int:
	if location != null and location.event_pool != null:
		return maxi(location.event_pool.default_sequence_length, 1)
	return 1


func _end_run(reason: StringName) -> RefCounted:
	if _state.phase == RunStateRef.PHASE_ENDED and _latest_result != null:
		return _latest_result

	var result := ResultRef.new()
	result.run_id = _state.run_id
	result.location_id = _state.location_id
	result.difficulty = _state.difficulty
	result.end_reason = reason
	result.completed_steps = _step_records.size()
	result.run_seed = _state.run_seed
	result.reward_snapshot = _build_reward_snapshot(reason)
	result.step_records = _step_records.duplicate()
	result.final_squad_snapshot = _snapshot_squad_runtime()

	_latest_result = result
	_result_history.append(result)
	_clear_current_event_instance()
	_state.phase = RunStateRef.PHASE_ENDED
	run_ended.emit(result)
	return result


func _build_reward_snapshot(reason: StringName) -> Dictionary:
	return {
		"gold": 0,
		"items": [],
		"result_note": "stub_only",
		"reason": reason,
	}


func _build_run_id(run_seed: int) -> StringName:
	var unix_sec: int = int(Time.get_unix_time_from_system())
	var nonce: int = abs(run_seed) % 1000000
	return StringName("run_%d_%06d" % [unix_sec, nonce])


func _make_seed() -> int:
	return int(Time.get_ticks_usec()) ^ int(randi())


func _reset_active_state() -> void:
	_clear_current_event_instance()
	_clear_squad_runtime()
	_step_records.clear()
	_latest_result = null
	_location = null


func _start_current_event_instance(event_scene: PackedScene) -> bool:
	if event_scene == null:
		return false

	_ensure_event_host()
	_clear_current_event_instance()

	var node := event_scene.instantiate()
	if node == null:
		return false
	if not node.has_method("start") or not node.has_signal("completed"):
		push_error("ExpeditionRuntime: event scene missing contract start()+completed signal")
		return false

	_current_event_instance = node
	_event_host.add_child(_current_event_instance)

	_current_event_id = _read_event_id_from_instance(_current_event_instance)
	_current_event_type = _read_event_type_from_instance(_current_event_instance)

	var completed_callable := Callable(self, "_on_event_instance_completed")
	if not _current_event_instance.is_connected("completed", completed_callable):
		_current_event_instance.connect("completed", completed_callable)

	var context := _build_event_context()
	_current_event_instance.call("start", context)
	return true


func _build_event_context() -> Dictionary:
	return {
		"run_id": _state.run_id,
		"step_index": _state.step_index,
		"location_id": _state.location_id,
		"difficulty": _state.difficulty,
		"seed": _state.run_seed,
		"options": _state.options,
		"event_id": _current_event_id,
		"event_type": _current_event_type,
		"event_scene_path": _current_event_scene.resource_path if _current_event_scene != null else "",
		"squad_runtime": _state.squad_runtime,
	}


func _on_event_instance_completed(payload: Dictionary) -> void:
	if _state.phase != RunStateRef.PHASE_ACTIVE_EVENT:
		push_warning("ExpeditionRuntime event completed ignored: phase is not active_event")
		return
	if _current_event_instance == null:
		push_warning("ExpeditionRuntime event completed ignored: current event instance is null")
		return

	var record := StepRecordRef.new()
	record.run_id = _state.run_id
	record.step_index = _state.step_index
	record.event_id = _current_event_id
	record.event_type = _current_event_type
	record.event_payload = _build_event_payload_snapshot()
	record.resolution_payload = payload.duplicate(true)
	_step_records.append(record)
	event_completed.emit(_state.step_index, record)

	var end_reason_override := _read_end_reason_override(payload)

	_clear_current_event_instance()
	if not end_reason_override.is_empty():
		_end_run(end_reason_override)
		return
	if _state.step_index >= _state.generated_sequence.size() - 1:
		_end_run(END_REASON_SEQUENCE_COMPLETED)
		return

	_state.phase = RunStateRef.PHASE_WAITING_DECISION
	decision_required.emit(_state.step_index)


func _build_event_payload_snapshot() -> Dictionary:
	return {
		"event_id": _current_event_id,
		"event_type": _current_event_type,
		"event_scene_path": _current_event_scene.resource_path if _current_event_scene != null else "",
		"difficulty": _state.difficulty,
		"location_id": _state.location_id,
	}


func _read_end_reason_override(payload: Dictionary) -> StringName:
	if payload.is_empty():
		return &""
	var raw: Variant = payload.get("expedition_end_reason", null)
	if raw == null:
		return &""
	if raw is StringName:
		return raw
	var text: String = str(raw)
	if text.is_empty():
		return &""
	return StringName(text)


func _read_event_id_from_instance(node: Node) -> StringName:
	if node == null:
		return &""
	var raw: Variant = node.get("event_id")
	if raw == null:
		return StringName(node.name)
	if raw is StringName:
		return raw
	return StringName(str(raw))


func _read_event_type_from_instance(node: Node) -> StringName:
	if node == null:
		return &"generic"
	var raw: Variant = node.get("event_type")
	if raw == null:
		return &"generic"
	if raw is StringName:
		return raw
	return StringName(str(raw))


func _ensure_event_host() -> void:
	if _event_host != null and is_instance_valid(_event_host):
		return

	_event_host = get_node_or_null("EventHost")
	if _event_host != null:
		return

	_event_host = Node.new()
	_event_host.name = "EventHost"
	add_child(_event_host)


func _ensure_squad_host() -> void:
	if _squad_host != null and is_instance_valid(_squad_host):
		return

	_squad_host = get_node_or_null("SquadHost")
	if _squad_host != null:
		return

	_squad_host = Node.new()
	_squad_host.name = "SquadHost"
	add_child(_squad_host)


func _clear_current_event_instance() -> void:
	if _current_event_instance == null:
		return
	if not is_instance_valid(_current_event_instance):
		_current_event_instance = null
		_current_event_scene = null
		_current_event_id = &""
		_current_event_type = &""
		return

	var completed_callable := Callable(self, "_on_event_instance_completed")
	if _current_event_instance.is_connected("completed", completed_callable):
		_current_event_instance.disconnect("completed", completed_callable)
	_current_event_instance.queue_free()
	_current_event_instance = null
	_current_event_scene = null
	_current_event_id = &""
	_current_event_type = &""


func _build_squad_runtime(request: RefCounted) -> Node:
	if request == null or request.squad_scene == null:
		return null

	_ensure_squad_host()
	var squad_node: Node = request.squad_scene.instantiate()
	if squad_node == null:
		return null
	if not squad_node.has_method("build_from_roster"):
		push_error("ExpeditionRuntime: squad scene missing build_from_roster()")
		squad_node.queue_free()
		return null

	_squad_host.add_child(squad_node)
	var built: bool = squad_node.call(
		"build_from_roster",
		request.player_roster,
		request.selected_player_actor_ids,
		request.actor_catalog
	)
	if not built:
		squad_node.queue_free()
		return null
	return squad_node


func _clear_squad_runtime() -> void:
	var squad_runtime: Node = _state.squad_runtime
	if squad_runtime != null and is_instance_valid(squad_runtime):
		squad_runtime.queue_free()
	_state.squad_runtime = null


func _snapshot_squad_runtime() -> Dictionary:
	var squad_runtime: Node = _state.squad_runtime
	if squad_runtime == null or not is_instance_valid(squad_runtime):
		return {}
	if not squad_runtime.has_method("export_run_snapshot"):
		return {}
	var snapshot: Variant = squad_runtime.call("export_run_snapshot")
	if snapshot is Dictionary:
		return (snapshot as Dictionary).duplicate(true)
	return {}
