class_name ExpeditionImGuiDebugPanel extends Node

const StartRequestRef = preload("res://src/expedition_system/expedition/model/ExpeditionStartRequest.gd")

const DEFAULT_LOCATION_PATH := "res://data/devtest/expedition_v2/locations/forest_outpost_v2.tres"
const DEFAULT_SQUAD_PATH := "res://data/devtest/expedition_v2/squads/default_squad_runtime.tres"
const INPUT_TEXT_CAPACITY: int = 256

@export var runtime_path: NodePath
@export var enabled_in_debug: bool = true
@export var toggle_key: Key = KEY_F10
@export var show_demo_window: bool = false
@export var default_location_path: String = DEFAULT_LOCATION_PATH
@export var default_difficulty: int = 1
@export var default_sequence_length: int = 3
@export var default_seed: int = -1
@export var default_squad_path: String = DEFAULT_SQUAD_PATH
@export var squad_runtime_override: SquadRuntime

var _runtime: ExpeditionRuntime
var _imgui: Object
var _debug_visible: bool = true
var _last_action_message: String = "idle"
var _last_result: ExpeditionResult

var _location_path_input: Array[String] = [DEFAULT_LOCATION_PATH]
var _difficulty_input: Array[int] = [1]
var _sequence_length_input: Array[int] = [3]
var _seed_input: Array[int] = [-1]
var _squad_runtime_path_input: Array[String] = [DEFAULT_SQUAD_PATH]


func _ready() -> void:
	_reset_inputs()
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


func set_runtime(node: ExpeditionRuntime) -> void:
	if _runtime == node:
		return
	_disconnect_runtime_signals()
	_runtime = node
	_connect_runtime_signals()
	if _runtime != null and _runtime.is_inside_tree() and is_inside_tree():
		runtime_path = get_path_to(_runtime)


func set_visible_debug_ui(v: bool) -> void:
	_debug_visible = v


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
	if node == null or not (node is ExpeditionRuntime):
		return
	set_runtime(node as ExpeditionRuntime)


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
		_draw_input_fields()
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

	var state: ExpeditionRunState = _runtime.get_state()
	_imgui.Text("run_id: %s" % String(state.run_id))
	_imgui.Text("phase: %s" % String(state.phase))
	_imgui.Text("step_index: %d" % state.step_index)
	_imgui.Text("seed: %d" % state.seed)
	_imgui.Text("sequence_len: %d" % state.generated_sequence.size())
	_imgui.Text("location_id: %s" % String(state.location_id))
	_imgui.Text("difficulty: %d" % state.difficulty)
	if state.squad_runtime != null:
		var debug_counter: int = int(state.squad_runtime.get_shared(&"debug_event_counter", 0))
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


func _draw_input_fields() -> void:
	_imgui.SeparatorText("Start Input")
	_imgui.InputText("location_path", _location_path_input, INPUT_TEXT_CAPACITY)
	_imgui.InputText("squad_runtime_path", _squad_runtime_path_input, INPUT_TEXT_CAPACITY)
	_imgui.DragInt("difficulty", _difficulty_input)
	_imgui.DragInt("sequence_length", _sequence_length_input)
	_imgui.DragInt("seed (-1 random)", _seed_input)


func _draw_actions() -> void:
	_imgui.SeparatorText("Flow Actions")

	if _imgui.Button("start_new_run"):
		_handle_start_new_run()
	_imgui.SameLine()
	if _imgui.Button("choose_continue"):
		_handle_choose_continue()

	if _imgui.Button("choose_retreat"):
		_handle_choose_retreat()


func _draw_result_snapshot() -> void:
	_imgui.SeparatorText("Latest Result")

	var result: ExpeditionResult = _last_result
	if result == null and _has_runtime():
		result = _runtime.get_latest_result()

	if result == null:
		_imgui.Text("result: none")
		return

	_imgui.Text("run_id: %s" % String(result.run_id))
	_imgui.Text("end_reason: %s" % String(result.end_reason))
	_imgui.Text("completed_steps: %d" % result.completed_steps)
	_imgui.Text("seed: %d" % result.seed)


func _handle_start_new_run() -> void:
	if not _has_runtime():
		_last_action_message = "start_new_run blocked: runtime missing"
		return

	var request: ExpeditionStartRequest = _build_start_request()
	if request == null:
		_last_action_message = "start_new_run blocked: invalid request"
		return

	var ok: bool = _runtime.start_new_run(request)
	_last_action_message = "start_new_run -> %s" % str(ok)
	if ok:
		_last_result = null


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
	var result: ExpeditionResult = _runtime.choose_retreat()
	if result == null:
		_last_action_message = "choose_retreat -> null"
		return
	_last_result = result
	_last_action_message = "choose_retreat -> %s" % String(result.end_reason)
	if _runtime.is_queued_for_deletion():
		_disconnect_runtime_signals()
		_runtime = null


func _build_start_request() -> ExpeditionStartRequest:
	var location_path: String = _location_path_input[0].strip_edges()
	if location_path.is_empty():
		return null

	var location_res := load(location_path)
	if not (location_res is ExpeditionLocationDef):
		return null

	var request := StartRequestRef.new()
	request.location = location_res as ExpeditionLocationDef
	request.difficulty = _difficulty_input[0]
	request.options = {
		"sequence_length": maxi(_sequence_length_input[0], 1),
	}

	var seed_value: int = _seed_input[0]
	request.seed = 0 if seed_value < 0 else seed_value
	request.squad = _load_squad_runtime_template()
	if not request.is_valid():
		return null
	return request


func _load_squad_runtime_template() -> SquadRuntime:
	if squad_runtime_override != null:
		return squad_runtime_override

	var squad_path: String = _squad_runtime_path_input[0].strip_edges()
	if squad_path.is_empty():
		return null
	var squad_res := load(squad_path)
	if not (squad_res is SquadRuntime):
		return null
	return squad_res as SquadRuntime


func _reset_inputs() -> void:
	_location_path_input[0] = default_location_path
	_difficulty_input[0] = default_difficulty
	_sequence_length_input[0] = default_sequence_length
	_seed_input[0] = default_seed
	_squad_runtime_path_input[0] = default_squad_path


func _on_runtime_ended(result: ExpeditionResult) -> void:
	_last_result = result
