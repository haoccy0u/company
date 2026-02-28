class_name ExpeditionSession extends RefCounted

var location: ExpeditionLocationDef
var squad: SquadRuntime

var step_count: int = 0
var progress: float = 0.0
var is_started: bool = false
var is_ended: bool = false
var end_reason: StringName = &""

var current_event: RefCounted
var last_event: RefCounted


func setup(location_def: ExpeditionLocationDef, squad_runtime: SquadRuntime) -> bool:
	if location_def == null:
		push_error("ExpeditionSession.setup failed: location is null")
		return false
	if squad_runtime == null:
		push_error("ExpeditionSession.setup failed: squad is null")
		return false
	if location_def.location_id.is_empty():
		push_error("ExpeditionSession.setup failed: location_id is empty")
		return false

	location = location_def
	squad = squad_runtime
	step_count = 0
	progress = 0.0
	is_started = true
	is_ended = false
	end_reason = &""
	current_event = null
	last_event = null
	return true


func can_advance() -> bool:
	if not is_started:
		return false
	if is_ended:
		return false
	if location == null:
		return false
	if squad == null:
		return false
	if current_event != null:
		return false
	if not squad.has_living_members():
		return false
	return true


func advance() -> RefCounted:
	if not is_started:
		push_warning("ExpeditionSession.advance blocked: session not started")
		return null

	if is_ended:
		push_warning("ExpeditionSession.advance blocked: session ended")
		return null

	if current_event != null:
		push_warning("ExpeditionSession.advance blocked: current event not completed")
		return null

	if squad == null or not squad.has_living_members():
		end_session(&"no_living_members")
		return null

	var event := EventSelector.select_next(location, step_count)
	if event == null:
		end_session(&"sequence_completed")
		return null

	current_event = event
	last_event = event
	step_count += 1
	progress = float(step_count)
	return event


func complete_current_event() -> bool:
	if current_event == null:
		push_warning("ExpeditionSession.complete_current_event skipped: no current event")
		return false

	current_event = null
	return true


func end_session(reason: StringName) -> void:
	is_ended = true
	end_reason = reason
	current_event = null


func get_current_event_type() -> StringName:
	if current_event == null:
		return &""
	if current_event.has_method("to_dict"):
		var event_data: Dictionary = current_event.call("to_dict")
		return event_data.get("event_type", &"")
	return &""
