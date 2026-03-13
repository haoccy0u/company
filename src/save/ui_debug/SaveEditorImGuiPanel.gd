extends Node
class_name SaveEditorImGuiPanel

const ACTOR_CATALOG_REF := preload("res://src/actor_system/ActorCatalog.gd")
const PLAYER_ACTOR_DATA_REF := preload("res://src/actor_system/PlayerActorData.gd")

const PLAYER_PROGRESS_ROOT_PATH := "/root/PlayerProgressRoot"
const SAVE_MANAGER_PATH := "/root/SaveManager"

const DEFAULT_ACTOR_CATALOG_PATH := "res://data/devtest/expedition_v2/actors/default_actor_catalog.tres"
const INPUT_TEXT_CAPACITY: int = 512
const DEFAULT_SAVE_SLOT: int = 1

const PROGRESS_ALLOWED_IDS: Array[String] = [
	"progress/player/roster",
	"progress/player/item_vault",
]

@export var enabled_in_debug: bool = true
@export var toggle_key: Key = KEY_F8
@export var default_actor_catalog_path: String = DEFAULT_ACTOR_CATALOG_PATH
@export var default_save_slot_id: int = DEFAULT_SAVE_SLOT

var _imgui: Object
var _visible: bool = true
var _last_action_message: String = "idle"
var _last_report: Dictionary = {}

var _actor_catalog_path_input: Array[String] = [DEFAULT_ACTOR_CATALOG_PATH]
var _actor_id_input: Array[String] = [""]
var _save_slot_input: Array[int] = [DEFAULT_SAVE_SLOT]


func _ready() -> void:
	_actor_catalog_path_input[0] = default_actor_catalog_path
	_save_slot_input[0] = maxi(default_save_slot_id, 1)
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

	_draw_panel()


func _draw_panel() -> void:
	if _imgui.Begin("Save Editor"):
		_draw_summary()
		_draw_inputs()
		_draw_actions()
		_draw_roster_preview()
	_imgui.End()


func _draw_summary() -> void:
	_imgui.SeparatorText("Status")
	_imgui.Text("action: %s" % _last_action_message)
	if _last_report.is_empty():
		return
	_imgui.Text("report: %s" % _report_summary(_last_report))


func _draw_inputs() -> void:
	_imgui.SeparatorText("Input")
	_imgui.InputText("actor_catalog_path", _actor_catalog_path_input, INPUT_TEXT_CAPACITY)
	_imgui.InputText("actor_id_to_add", _actor_id_input, INPUT_TEXT_CAPACITY)
	_imgui.DragInt("save_slot_id", _save_slot_input)

	var actor_ids: PackedStringArray = _get_catalog_actor_ids(_actor_catalog_path_input[0])
	if actor_ids.is_empty():
		_imgui.Text("catalog actor_ids: (none)")
	else:
		_imgui.Text("catalog actor_ids: %s" % ", ".join(actor_ids))


func _draw_actions() -> void:
	_imgui.SeparatorText("Actions")
	if _imgui.Button("add_actor_to_roster"):
		_handle_add_actor_to_roster()
	if _imgui.Button("save_slot"):
		_handle_save_slot()
	if _imgui.Button("load_slot_filtered"):
		_handle_load_slot_filtered()


func _draw_roster_preview() -> void:
	_imgui.SeparatorText("Player Roster")
	var roster_state: Node = _resolve_player_roster_state()
	if not _is_valid_player_roster_state(roster_state):
		_imgui.Text("roster_state: invalid")
		return

	var extract_result: Dictionary = _extract_players(roster_state)
	if not bool(extract_result.get("ok", false)):
		_imgui.Text("roster read failed: %s" % String(extract_result.get("reason", "unknown")))
		return

	var players: Array[PlayerActorData] = _players_from_extract_result(extract_result)
	_imgui.Text("total players: %d" % players.size())
	for i in range(players.size()):
		var player: PlayerActorData = players[i]
		_imgui.Text("%d) %s | actor=%s | level=%d" % [
			i + 1,
			String(player.player_actor_id),
			String(player.actor_id),
			player.level,
		])


func _handle_add_actor_to_roster() -> void:
	var actor_id_text: String = _actor_id_input[0].strip_edges()
	if actor_id_text.is_empty():
		_last_action_message = "add blocked: actor_id_to_add is empty"
		return
	var actor_id: StringName = StringName(actor_id_text)

	var roster_state: Node = _resolve_player_roster_state()
	if not _is_valid_player_roster_state(roster_state):
		_last_action_message = "add blocked: roster state invalid"
		return

	var catalog: ActorCatalog = _load_actor_catalog(_actor_catalog_path_input[0])
	if catalog == null:
		_last_action_message = "add blocked: actor catalog invalid"
		return
	if not catalog.has_actor(actor_id):
		_last_action_message = "add blocked: actor_id not found in catalog (%s)" % String(actor_id)
		return

	var extract_result: Dictionary = _extract_players(roster_state)
	if not bool(extract_result.get("ok", false)):
		_last_action_message = "add blocked: %s" % String(extract_result.get("reason", "roster read failed"))
		return
	var players: Array[PlayerActorData] = _players_from_extract_result(extract_result)
	if _has_actor_id(players, actor_id):
		_last_action_message = "add blocked: duplicate actor_id (%s)" % String(actor_id)
		return

	var new_player: PlayerActorData = PLAYER_ACTOR_DATA_REF.new() as PlayerActorData
	if new_player == null:
		_last_action_message = "add blocked: failed to instantiate PlayerActorData"
		return
	new_player.player_actor_id = _generate_player_actor_id(actor_id, players)
	new_player.actor_id = actor_id
	new_player.level = 1
	new_player.progression_states = {}

	var next_players: Array[PlayerActorData] = []
	for player in players:
		next_players.append(player)
	next_players.append(new_player)
	var ok: bool = bool(roster_state.call("set_players", next_players))
	if not ok:
		_last_action_message = "add failed: roster_state.set_players returned false"
		return

	_last_action_message = "added actor_id=%s as player_actor_id=%s (level=1)" % [
		String(new_player.actor_id),
		String(new_player.player_actor_id),
	]
	_actor_id_input[0] = ""


func _handle_save_slot() -> void:
	var save_manager: Node = _resolve_save_manager()
	if save_manager == null:
		_last_action_message = "save blocked: SaveManager missing"
		return

	var slot_id: int = maxi(_save_slot_input[0], 1)
	_save_slot_input[0] = slot_id
	_last_report = _dict_or_empty(save_manager.call("save_slot", slot_id))
	_last_action_message = "save_slot(%d) -> %s" % [slot_id, _report_summary(_last_report)]


func _handle_load_slot_filtered() -> void:
	var save_manager: Node = _resolve_save_manager()
	if save_manager == null:
		_last_action_message = "load blocked: SaveManager missing"
		return

	var slot_id: int = maxi(_save_slot_input[0], 1)
	_save_slot_input[0] = slot_id
	_last_report = _dict_or_empty(save_manager.call("load_slot_filtered", slot_id, PROGRESS_ALLOWED_IDS))
	_last_action_message = "load_slot_filtered(%d) -> %s" % [slot_id, _report_summary(_last_report)]


func _resolve_player_roster_state() -> Node:
	var progress_root: Node = get_node_or_null(PLAYER_PROGRESS_ROOT_PATH)
	if progress_root == null:
		return null
	if not progress_root.has_method("get_roster_state"):
		return null
	var roster_variant: Variant = progress_root.call("get_roster_state")
	return roster_variant as Node


func _is_valid_player_roster_state(roster_state: Node) -> bool:
	return roster_state != null and roster_state.has_method("get_players") and roster_state.has_method("set_players")


func _resolve_save_manager() -> Node:
	return get_node_or_null(SAVE_MANAGER_PATH)


func _load_actor_catalog(path_text: String) -> ActorCatalog:
	var clean_path: String = path_text.strip_edges()
	if clean_path.is_empty():
		return null
	var loaded: Resource = load(clean_path)
	if loaded == null:
		return null
	if loaded.get_script() != ACTOR_CATALOG_REF:
		return null
	return loaded as ActorCatalog


func _extract_players(roster_state: Node) -> Dictionary:
	var players_variant: Variant = roster_state.call("get_players")
	if not (players_variant is Array):
		return {"ok": false, "reason": "get_players is not Array", "players": []}

	var raw_players: Array = players_variant
	var out: Array[PlayerActorData] = []
	for i in range(raw_players.size()):
		var player: PlayerActorData = raw_players[i] as PlayerActorData
		if player == null:
			return {
				"ok": false,
				"reason": "player row is not PlayerActorData at index=%d" % i,
				"players": [],
			}
		out.append(player)

	return {"ok": true, "players": out}


func _has_actor_id(players: Array[PlayerActorData], actor_id: StringName) -> bool:
	for player in players:
		if player != null and player.actor_id == actor_id:
			return true
	return false


func _has_player_actor_id(players: Array[PlayerActorData], player_actor_id: StringName) -> bool:
	for player in players:
		if player != null and player.player_actor_id == player_actor_id:
			return true
	return false


func _generate_player_actor_id(actor_id: StringName, players: Array[PlayerActorData]) -> StringName:
	var actor_token: String = _sanitize_id_token(String(actor_id))
	if actor_token.is_empty():
		actor_token = "actor"

	var base: String = "player_%s" % actor_token
	var candidate: String = base
	var index: int = 1
	while _has_player_actor_id(players, StringName(candidate)):
		index += 1
		candidate = "%s_%d" % [base, index]
	return StringName(candidate)


func _sanitize_id_token(text: String) -> String:
	var lowered: String = text.to_lower()
	var out := ""
	for i in lowered.length():
		var ch: int = lowered.unicode_at(i)
		var is_lower: bool = ch >= 97 and ch <= 122
		var is_digit: bool = ch >= 48 and ch <= 57
		var is_underscore: bool = ch == 95
		out += String.chr(ch) if (is_lower or is_digit or is_underscore) else "_"
	out = out.strip_edges()
	while out.contains("__"):
		out = out.replace("__", "_")
	return out.trim_prefix("_").trim_suffix("_")


func _get_catalog_actor_ids(path_text: String) -> PackedStringArray:
	var catalog: ActorCatalog = _load_actor_catalog(path_text)
	if catalog == null:
		return PackedStringArray()
	var ids := PackedStringArray()
	for actor in catalog.actors:
		if actor == null:
			continue
		if actor.actor_id.is_empty():
			continue
		ids.append(String(actor.actor_id))
	return ids


func _report_summary(report: Dictionary) -> String:
	if report.is_empty():
		return "no report"
	var status: String = String(report.get("status", "unknown"))
	var success: bool = bool(report.get("success", false))
	var metrics_variant: Variant = report.get("metrics", {})
	var loaded_count: int = 0
	var saved_count: int = 0
	if metrics_variant is Dictionary:
		var metrics: Dictionary = metrics_variant
		loaded_count = int(metrics.get("loaded_count", 0))
		saved_count = int(metrics.get("saved_count", 0))
	return "status=%s success=%s saved=%d loaded=%d" % [status, str(success), saved_count, loaded_count]


func _dict_or_empty(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value as Dictionary
	return {}


func _players_from_extract_result(extract_result: Dictionary) -> Array[PlayerActorData]:
	var players_variant: Variant = extract_result.get("players", [])
	if not (players_variant is Array):
		return []

	var raw_players: Array = players_variant
	var typed_players: Array[PlayerActorData] = []
	for row in raw_players:
		var player: PlayerActorData = row as PlayerActorData
		if player == null:
			continue
		typed_players.append(player)
	return typed_players


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
