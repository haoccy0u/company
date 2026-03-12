extends Node
class_name PlayerRosterState

const SAVE_GROUP := "saveable"
const DEFAULT_SAVE_ID := &"progress/player/roster"

const PLAYER_PROGRESS_CODEC := preload("res://src/save/codecs/PlayerProgressCodec.gd")

@export var save_enabled: bool = true
@export var save_id: StringName = DEFAULT_SAVE_ID

var players: Array[PlayerActorData] = []


func _ready() -> void:
	if save_enabled and not is_in_group(SAVE_GROUP):
		add_to_group(SAVE_GROUP)
	_ensure_initialized()


func get_save_id() -> String:
	if not save_enabled:
		return ""
	if save_id.is_empty():
		return String(DEFAULT_SAVE_ID)
	return String(save_id)


func get_save_type() -> String:
	return "player_progress"


func capture_state() -> Dictionary:
	_ensure_initialized()
	return PLAYER_PROGRESS_CODEC.capture_roster(players)


func apply_state(data: Dictionary) -> bool:
	var decoded: Dictionary = PLAYER_PROGRESS_CODEC.apply_roster(data)
	if not bool(decoded.get("ok", false)):
		return false

	var decoded_players_variant: Variant = decoded.get("players", [])
	if not (decoded_players_variant is Array):
		return false

	var decoded_players: Array = decoded_players_variant
	var typed_players: Array[PlayerActorData] = []
	for player_variant in decoded_players:
		var player: PlayerActorData = player_variant as PlayerActorData
		if player == null:
			return false
		typed_players.append(player)

	return set_players(typed_players)


func get_players() -> Array[PlayerActorData]:
	_ensure_initialized()
	return players


func set_players(players_in: Array[PlayerActorData]) -> bool:
	var seen_ids: Dictionary = {}
	var copied: Array[PlayerActorData] = []
	for player in players_in:
		if player == null:
			return false

		var duplicated: PlayerActorData = player.duplicate(true) as PlayerActorData
		if duplicated == null:
			return false

		if duplicated.player_actor_id.is_empty():
			return false
		if seen_ids.has(duplicated.player_actor_id):
			return false
		seen_ids[duplicated.player_actor_id] = true
		copied.append(duplicated)

	players = copied
	return true


func reset_to_default_roster() -> bool:
	# Compatibility alias. Default now means an empty runtime roster template.
	return reset_to_empty_roster()


func reset_to_empty_roster() -> bool:
	players = []
	return true


func _ensure_initialized() -> void:
	if players == null:
		players = []


func find_player_actor(player_actor_id: StringName) -> PlayerActorData:
	if player_actor_id.is_empty():
		return null

	var matches: Array[PlayerActorData] = []
	for player in players:
		if player == null:
			continue
		if player.player_actor_id == player_actor_id:
			matches.append(player)

	if matches.is_empty():
		return null
	if matches.size() > 1:
		push_error("PlayerRosterState.find_player_actor failed: duplicate player_actor_id=%s" % String(player_actor_id))
		return null
	return matches[0]


func has_player_actor(player_actor_id: StringName) -> bool:
	return find_player_actor(player_actor_id) != null
