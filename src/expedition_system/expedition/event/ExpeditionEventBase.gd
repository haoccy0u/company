extends Node
class_name ExpeditionEventBase

signal completed(payload: Dictionary)

@export var event_id: StringName = &""
@export var event_type: StringName = &"generic"
@export var components_root_path: NodePath = ^"Components"
@export var auto_complete_when_no_components: bool = true
@export var auto_complete_delay_seconds: float = 0.2
@export var debug_counter_key: StringName = &"debug_event_counter"

var _active_context: Dictionary = {}
var _payload: Dictionary = {}
var _pending_components: Array[Node] = []
var _current_component: Node
var _current_component_index: int = -1
var _is_running: bool = false


func start(context: Dictionary) -> void:
	if _is_running:
		push_warning("ExpeditionEventBase.start blocked: event already running")
		return

	_increment_debug_counter(context)
	_active_context = context.duplicate(true)

	_payload = {
		"event_id": event_id,
		"event_type": event_type,
		"component_results": [],
		"step_index": int(context.get("step_index", -1)),
	}

	var components_root: Node = get_node_or_null(components_root_path)
	if components_root == null:
		_payload["note"] = "missing_components_root"
		if auto_complete_when_no_components:
			_schedule_completed(_payload)
		return

	_pending_components = _collect_components(components_root)
	_current_component_index = -1
	_current_component = null
	_is_running = true

	if _pending_components.is_empty():
		_payload["note"] = "no_components"
		_schedule_completed(_payload)
		return

	_start_next_component()


func _increment_debug_counter(context: Dictionary) -> void:
	var squad_runtime = context.get("squad_runtime", null)
	if squad_runtime == null:
		return
	squad_runtime.inc_shared_int(debug_counter_key, 1)


func _collect_components(components_root: Node) -> Array[Node]:
	var out: Array[Node] = []
	for child in components_root.get_children():
		if child == null:
			continue
		if not child.has_method("start_component"):
			continue
		if not child.has_signal("completed"):
			continue
		out.append(child)
	return out


func _start_next_component() -> void:
	_current_component_index += 1
	if _current_component_index >= _pending_components.size():
		_schedule_completed(_payload)
		return

	_current_component = _pending_components[_current_component_index]
	if _current_component == null:
		_start_next_component()
		return

	var completed_callable := Callable(self, "_on_component_completed")
	if not _current_component.is_connected("completed", completed_callable):
		_current_component.connect("completed", completed_callable, CONNECT_ONE_SHOT)
	_current_component.call("start_component", _active_context)


func _on_component_completed(component_payload: Dictionary) -> void:
	var safe_payload: Dictionary = component_payload.duplicate(true)
	var component_name: String = ""
	if _current_component != null:
		component_name = String(_current_component.name)
	(_payload["component_results"] as Array).append({
		"component_name": component_name,
		"result": safe_payload,
	})
	_current_component = null

	var end_reason_override: StringName = _read_end_reason_override(safe_payload)
	if not end_reason_override.is_empty():
		_payload["expedition_end_reason"] = end_reason_override
		_schedule_completed(_payload)
		return

	_start_next_component()


func _read_end_reason_override(component_payload: Dictionary) -> StringName:
	var value: Variant = component_payload.get("expedition_end_reason", null)
	if value == null:
		return &""
	if value is StringName:
		return value
	var text: String = String(value)
	if text.is_empty():
		return &""
	return StringName(text)


func _schedule_completed(payload: Dictionary) -> void:
	_is_running = false
	_pending_components.clear()
	_current_component = null
	_current_component_index = -1
	var snapshot: Dictionary = payload.duplicate(true)
	if auto_complete_delay_seconds <= 0.0:
		call_deferred("_emit_completed", snapshot)
		return

	var timer := get_tree().create_timer(auto_complete_delay_seconds)
	var emit_callable := func() -> void:
		_emit_completed(snapshot)
	timer.timeout.connect(emit_callable, CONNECT_ONE_SHOT)


func _emit_completed(payload: Dictionary) -> void:
	completed.emit(payload)
