extends Node
class_name ExpeditionImGuiDebugPanel

const RuntimeRef = preload("res://src/expedition_system/expedition/runtime/ExpeditionRuntime.gd")

@export var runtime_path: NodePath
@export var enabled_in_debug: bool = true
@export var toggle_key: Key = KEY_F10
@export var show_demo_window: bool = false

var _runtime: Node
var _imgui: Object
var _debug_visible: bool = true
var _last_action_message: String = "idle"
var _last_result: RefCounted


func _ready() -> void:
	_resolve_runtime_from_path()
	_resolve_imgui_api()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_enabled_for_current_build():
		return
	if not (event is InputEventKey):
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != toggle_key:
		return

	_debug_visible = not _debug_visible
	get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	_disconnect_runtime_signals()


func set_runtime(node: Node) -> void:
	if _runtime == node:
		return
	_disconnect_runtime_signals()
	_runtime = node
	_connect_runtime_signals()
	if _runtime != null and _runtime.is_inside_tree() and is_inside_tree():
		runtime_path = get_path_to(_runtime)


func _process(_delta: float) -> void:
	if not _is_enabled_for_current_build():
		return
	if not _debug_visible:
		return
	if not _has_imgui():
		return

	if show_demo_window:
		_imgui.ShowDemoWindow()
	_draw_imgui_panel()


func _connect_runtime_signals() -> void:
	if _runtime == null or not is_instance_valid(_runtime):
		return
	if not _runtime.run_ended.is_connected(_on_runtime_ended):
		_runtime.run_ended.connect(_on_runtime_ended)


func _disconnect_runtime_signals() -> void:
	if _runtime == null or not is_instance_valid(_runtime):
		return
	if _runtime.run_ended.is_connected(_on_runtime_ended):
		_runtime.run_ended.disconnect(_on_runtime_ended)


func _resolve_runtime_from_path() -> void:
	if _has_runtime():
		return
	if runtime_path.is_empty():
		return
	var node := get_node_or_null(runtime_path)
	if node == null or node.get_script() != RuntimeRef:
		return
	set_runtime(node)


func _has_runtime() -> bool:
	if _runtime == null:
		return false
	if not is_instance_valid(_runtime):
		return false
	if _runtime.is_queued_for_deletion():
		return false
	return true


func _is_enabled_for_current_build() -> bool:
	return enabled_in_debug and OS.is_debug_build()


func _resolve_imgui_api() -> void:
	if Engine.has_singleton("ImGuiAPI"):
		_imgui = Engine.get_singleton("ImGuiAPI")
	else:
		_imgui = null


func _has_imgui() -> bool:
	if _imgui == null:
		_resolve_imgui_api()
	return _imgui != null


func _draw_imgui_panel() -> void:
	if not _has_imgui():
		return

	_resolve_runtime_from_path()
	if not _has_runtime():
		_disconnect_runtime_signals()
		_runtime = null

	if _imgui.Begin("Expedition Runtime Debug"):
		_draw_runtime_state()
		_draw_actions()
		_draw_result_snapshot()
	_imgui.End()


func _draw_runtime_state() -> void:
	_imgui.SeparatorText("Runtime State")
	if not _has_runtime():
		_imgui.Text("runtime: null or invalid")
		_imgui.Text("runtime_path: %s" % String(runtime_path))
		_imgui.Text("action: %s" % _last_action_message)
		return

	var state = _runtime.get_state()
	_imgui.Text("run_id: %s" % String(state.run_id))
	_imgui.Text("phase: %s" % String(state.phase))
	_imgui.Text("step_index: %d" % state.step_index)
	_imgui.Text("seed: %d" % state.run_seed)
	_imgui.Text("sequence_len: %d" % state.generated_sequence.size())
	_imgui.Text("location_id: %s" % String(state.location_id))
	_imgui.Text("difficulty: %d" % state.difficulty)
	if state.squad_runtime != null and is_instance_valid(state.squad_runtime) and state.squad_runtime.has_method("get_shared"):
		var debug_counter: int = int(state.squad_runtime.call("get_shared", &"debug_event_counter", 0))
		_imgui.Text("squad.debug_event_counter: %d" % debug_counter)

	var current_event: Node = _runtime.get_current_event_instance()
	if current_event == null:
		_imgui.Text("current_event: null")
	else:
		var event_id: Variant = current_event.get("event_id")
		var event_type: Variant = current_event.get("event_type")
		_imgui.Text("current_event: %s (%s)" % [str(event_id), str(event_type)])
		_imgui.Text("current_event_scene: %s" % current_event.scene_file_path)

	_imgui.Text("action: %s" % _last_action_message)


func _draw_actions() -> void:
	_imgui.SeparatorText("Flow Actions")

	if _imgui.Button("choose_continue"):
		_handle_choose_continue()

	if _imgui.Button("choose_retreat"):
		_handle_choose_retreat()


func _draw_result_snapshot() -> void:
	_imgui.SeparatorText("Latest Result")

	var result = _last_result
	if result == null and _has_runtime():
		result = _runtime.get_latest_result()

	if result == null:
		_imgui.Text("result: none")
		return

	_imgui.Text("run_id: %s" % String(result.run_id))
	_imgui.Text("end_reason: %s" % String(result.end_reason))
	_imgui.Text("completed_steps: %d" % result.completed_steps)
	_imgui.Text("seed: %d" % result.run_seed)


func _handle_choose_continue() -> void:
	if not _has_runtime():
		_last_action_message = "choose_continue blocked: runtime missing"
		return
	var ok: bool = _runtime.choose_continue()
	_last_action_message = "choose_continue -> %s" % str(ok)


func _handle_choose_retreat() -> void:
	if not _has_runtime():
		_last_action_message = "choose_retreat blocked: runtime missing"
		return
	var result = _runtime.choose_retreat()
	if result == null:
		_last_action_message = "choose_retreat -> null"
		return
	_last_result = result
	_last_action_message = "choose_retreat -> %s" % String(result.end_reason)
	if _runtime.is_queued_for_deletion():
		_disconnect_runtime_signals()
		_runtime = null


func _on_runtime_ended(result: RefCounted) -> void:
	_last_result = result
