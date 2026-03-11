extends Node
class_name ExpeditionSquadConfigImGuiPanel

const StartRequestRef = preload("res://src/expedition_system/expedition/model/ExpeditionStartRequest.gd")
const RuntimeRef = preload("res://src/expedition_system/expedition/runtime/ExpeditionRuntime.gd")
const LocationDefRef = preload("res://src/expedition_system/expedition/content/ExpeditionLocationDef.gd")
const ActorCatalogRef = preload("res://src/actor_system/ActorCatalog.gd")
const PlayerActorRosterRef = preload("res://src/actor_system/PlayerActorRoster.gd")

const DEFAULT_LOCATION_PATH := "res://data/devtest/expedition_v2/locations/forest_outpost_v2.tres"
const DEFAULT_ACTOR_CATALOG_PATH := "res://data/devtest/expedition_v2/actors/default_actor_catalog.tres"
const DEFAULT_PLAYER_ROSTER_PATH := "res://data/devtest/expedition_v2/players/default_player_roster.tres"
const DEFAULT_SQUAD_SCENE_PATH := "res://scenes/expedition/squad/Squad.tscn"
const DEFAULT_SELECTED_IDS := "player_observer,player_robot"
const INPUT_TEXT_CAPACITY: int = 512

@export var runtime_path: NodePath
@export var enabled_in_debug: bool = true
@export var toggle_key: Key = KEY_F9
@export var default_location_path: String = DEFAULT_LOCATION_PATH
@export var default_actor_catalog_path: String = DEFAULT_ACTOR_CATALOG_PATH
@export var default_player_roster_path: String = DEFAULT_PLAYER_ROSTER_PATH
@export var default_squad_scene_path: String = DEFAULT_SQUAD_SCENE_PATH
@export var default_selected_player_actor_ids: String = DEFAULT_SELECTED_IDS
@export var default_difficulty: int = 1
@export var default_sequence_length: int = 3
@export var default_seed: int = -1

var _runtime: Node
var _imgui: Object
var _visible: bool = true
var _last_action_message: String = "idle"

var _location_path_input: Array[String] = [DEFAULT_LOCATION_PATH]
var _actor_catalog_path_input: Array[String] = [DEFAULT_ACTOR_CATALOG_PATH]
var _player_roster_path_input: Array[String] = [DEFAULT_PLAYER_ROSTER_PATH]
var _squad_scene_path_input: Array[String] = [DEFAULT_SQUAD_SCENE_PATH]
var _selected_player_actor_ids_input: Array[String] = [DEFAULT_SELECTED_IDS]
var _difficulty_input: Array[int] = [1]
var _sequence_length_input: Array[int] = [3]
var _seed_input: Array[int] = [-1]


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

	_visible = not _visible
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not _is_enabled_for_current_build():
		return
	if not _visible:
		return
	if not _has_imgui():
		return

	_resolve_runtime_from_path()
	if _imgui.Begin("Expedition Squad Config"):
		_draw_runtime_summary()
		_draw_input_fields()
		_draw_actions()
	_imgui.End()


func _draw_runtime_summary() -> void:
	_imgui.SeparatorText("Runtime")
	if not _has_runtime():
		_imgui.Text("runtime: null or invalid")
		_imgui.Text("runtime_path: %s" % String(runtime_path))
		_imgui.Text("action: %s" % _last_action_message)
		return

	var state = _runtime.get_state()
	_imgui.Text("run_id: %s" % String(state.run_id))
	_imgui.Text("phase: %s" % String(state.phase))
	_imgui.Text("action: %s" % _last_action_message)


func _draw_input_fields() -> void:
	_imgui.SeparatorText("Start Input")
	_imgui.InputText("location_path", _location_path_input, INPUT_TEXT_CAPACITY)
	_imgui.InputText("actor_catalog_path", _actor_catalog_path_input, INPUT_TEXT_CAPACITY)
	_imgui.InputText("player_roster_path", _player_roster_path_input, INPUT_TEXT_CAPACITY)
	_imgui.InputText("squad_scene_path", _squad_scene_path_input, INPUT_TEXT_CAPACITY)
	_imgui.InputText("selected_player_actor_ids(csv)", _selected_player_actor_ids_input, INPUT_TEXT_CAPACITY)
	_imgui.DragInt("difficulty", _difficulty_input)
	_imgui.DragInt("sequence_length", _sequence_length_input)
	_imgui.DragInt("seed (-1 random)", _seed_input)


func _draw_actions() -> void:
	_imgui.SeparatorText("Actions")
	if _imgui.Button("start_new_run"):
		_handle_start_new_run()


func _handle_start_new_run() -> void:
	if not _has_runtime():
		_last_action_message = "start_new_run blocked: runtime missing"
		return

	var request = _build_start_request()
	if request == null:
		_last_action_message = "start_new_run blocked: invalid request"
		return

	var ok: bool = _runtime.start_new_run(request)
	_last_action_message = "start_new_run -> %s" % str(ok)


func _build_start_request() -> RefCounted:
	var location_path: String = _location_path_input[0].strip_edges()
	var location_res := load(location_path)
	if location_res == null or location_res.get_script() != LocationDefRef:
		return null

	var actor_catalog_path: String = _actor_catalog_path_input[0].strip_edges()
	var actor_catalog := load(actor_catalog_path)
	if actor_catalog == null or actor_catalog.get_script() != ActorCatalogRef:
		return null

	var player_roster_path: String = _player_roster_path_input[0].strip_edges()
	var player_roster := load(player_roster_path)
	if player_roster == null or player_roster.get_script() != PlayerActorRosterRef:
		return null

	var squad_scene_path: String = _squad_scene_path_input[0].strip_edges()
	var squad_scene := load(squad_scene_path)
	if squad_scene == null or not (squad_scene is PackedScene):
		return null

	var selected_player_actor_ids := _parse_selected_ids(_selected_player_actor_ids_input[0])
	if selected_player_actor_ids.is_empty():
		return null

	var request := StartRequestRef.new()
	request.location = location_res
	request.difficulty = _difficulty_input[0]
	request.options = {
		"sequence_length": maxi(_sequence_length_input[0], 1),
	}
	var seed_value: int = _seed_input[0]
	request.run_seed = 0 if seed_value < 0 else seed_value
	request.actor_catalog = actor_catalog
	request.player_roster = player_roster
	request.squad_scene = squad_scene
	request.selected_player_actor_ids = selected_player_actor_ids
	if not request.is_valid():
		return null
	return request


func _parse_selected_ids(raw_csv: String) -> Array[StringName]:
	var out: Array[StringName] = []
	var seen: Dictionary = {}
	for token in raw_csv.split(",", false):
		var cleaned := token.strip_edges()
		if cleaned.is_empty():
			continue
		var key := StringName(cleaned)
		if seen.has(key):
			continue
		seen[key] = true
		out.append(key)
	return out


func _resolve_runtime_from_path() -> void:
	if _has_runtime():
		return
	if runtime_path.is_empty():
		return
	var node := get_node_or_null(runtime_path)
	if node == null or node.get_script() != RuntimeRef:
		return
	_runtime = node


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


func _reset_inputs() -> void:
	_location_path_input[0] = default_location_path
	_actor_catalog_path_input[0] = default_actor_catalog_path
	_player_roster_path_input[0] = default_player_roster_path
	_squad_scene_path_input[0] = default_squad_scene_path
	_selected_player_actor_ids_input[0] = default_selected_player_actor_ids
	_difficulty_input[0] = default_difficulty
	_sequence_length_input[0] = default_sequence_length
	_seed_input[0] = default_seed
