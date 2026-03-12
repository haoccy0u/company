extends RefCounted
class_name PlayerProgressCodec

const CODEC_UTILS := preload("res://src/save/codecs/SaveCodecUtils.gd")
const PLAYER_ACTOR_DATA_SCRIPT := preload("res://src/actor_system/PlayerActorData.gd")

const SCHEMA_VERSION := 1


static func capture_roster(players: Array[PlayerActorData]) -> Dictionary:
	var players_data: Array[Dictionary] = []
	for player in players:
		if player == null:
			continue
		players_data.append(_capture_player(player))

	return {
		"schema_version": SCHEMA_VERSION,
		"roster": {
			"players": players_data,
		},
	}


static func apply_roster(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return CODEC_UTILS.fail(
			"SAVE.CODEC.PLAYER_PROGRESS.EMPTY_DATA",
			"validate",
			"data is empty"
		)

	var schema_version: int = int(data.get("schema_version", -1))
	if schema_version != SCHEMA_VERSION:
		return CODEC_UTILS.fail(
			"SAVE.CODEC.PLAYER_PROGRESS.UNSUPPORTED_SCHEMA_VERSION",
			"validate",
			"unsupported schema version",
			{"expected": SCHEMA_VERSION, "actual": schema_version}
		)

	var roster_variant: Variant = data.get("roster", null)
	if not (roster_variant is Dictionary):
		return CODEC_UTILS.fail(
			"SAVE.CODEC.PLAYER_PROGRESS.MISSING_ROSTER",
			"validate",
			"roster must be Dictionary"
		)
	var roster_data: Dictionary = roster_variant

	var players_variant: Variant = roster_data.get("players", null)
	if not (players_variant is Array):
		return CODEC_UTILS.fail(
			"SAVE.CODEC.PLAYER_PROGRESS.INVALID_PLAYERS",
			"validate",
			"roster.players must be Array"
		)

	var seen_ids: Dictionary = {}
	var players_data: Array = players_variant
	var restored_players: Array[PlayerActorData] = []
	for i in range(players_data.size()):
		var row_variant: Variant = players_data[i]
		if not (row_variant is Dictionary):
			return CODEC_UTILS.fail(
				"SAVE.CODEC.PLAYER_PROGRESS.INVALID_PLAYER_ROW",
				"validate",
				"player row must be Dictionary",
				{"index": i}
			)
		var row: Dictionary = row_variant
		var decoded: Dictionary = _decode_player(row, seen_ids, i)
		if not bool(decoded.get("ok", false)):
			return decoded
		var player_res: PlayerActorData = decoded.get("player", null) as PlayerActorData
		if player_res == null:
			return CODEC_UTILS.fail(
				"SAVE.CODEC.PLAYER_PROGRESS.INVALID_DECODE_RESULT",
				"validate",
				"decoded player is null",
				{"index": i}
			)
		restored_players.append(player_res)

	return CODEC_UTILS.ok({"players": restored_players})


static func _capture_player(player: PlayerActorData) -> Dictionary:
	var equipment_out: Array[String] = []
	var equipment_variant: Variant = player.equipment_ids
	if equipment_variant is Array:
		var equipment: Array = equipment_variant
		for equipment_id_variant in equipment:
			var equipment_id: String = String(equipment_id_variant)
			if equipment_id.is_empty():
				continue
			equipment_out.append(equipment_id)

	var progression_variant: Variant = player.progression_states
	var progression_states: Dictionary = {}
	if progression_variant is Dictionary:
		progression_states = (progression_variant as Dictionary).duplicate(true)

	return {
		"player_actor_id": String(player.player_actor_id),
		"actor_id": String(player.actor_id),
		"level": maxi(player.level, 1),
		"progression_states": progression_states,
		"equipment_ids": equipment_out,
	}


static func _decode_player(row: Dictionary, seen_ids: Dictionary, index: int) -> Dictionary:
	var player_actor_id: String = String(row.get("player_actor_id", "")).strip_edges()
	if player_actor_id.is_empty():
		return CODEC_UTILS.fail(
			"SAVE.CODEC.PLAYER_PROGRESS.EMPTY_PLAYER_ACTOR_ID",
			"validate",
			"player_actor_id is required",
			{"index": index}
		)
	if seen_ids.has(player_actor_id):
		return CODEC_UTILS.fail(
			"SAVE.CODEC.PLAYER_PROGRESS.DUPLICATE_PLAYER_ACTOR_ID",
			"validate",
			"duplicate player_actor_id",
			{"index": index, "player_actor_id": player_actor_id}
		)
	seen_ids[player_actor_id] = true

	var actor_id: String = String(row.get("actor_id", "")).strip_edges()
	if actor_id.is_empty():
		return CODEC_UTILS.fail(
			"SAVE.CODEC.PLAYER_PROGRESS.EMPTY_ACTOR_ID",
			"validate",
			"actor_id is required",
			{"index": index, "player_actor_id": player_actor_id}
		)

	var level: int = int(row.get("level", 1))
	if level < 1:
		return CODEC_UTILS.fail(
			"SAVE.CODEC.PLAYER_PROGRESS.INVALID_LEVEL",
			"validate",
			"level must be >= 1",
			{"index": index, "player_actor_id": player_actor_id, "level": level}
		)

	var progression_states: Dictionary = CODEC_UTILS.dict_or_empty(row.get("progression_states", {}))

	var equipment_ids: Array[StringName] = []
	var equipment_variant: Variant = row.get("equipment_ids", [])
	if equipment_variant is Array:
		var equipment_data: Array = equipment_variant
		for raw_equipment_id in equipment_data:
			var equipment_id: String = String(raw_equipment_id).strip_edges()
			if equipment_id.is_empty():
				continue
			equipment_ids.append(StringName(equipment_id))

	var player: PlayerActorData = PLAYER_ACTOR_DATA_SCRIPT.new() as PlayerActorData
	if player == null:
		return CODEC_UTILS.fail(
			"SAVE.CODEC.PLAYER_PROGRESS.PLAYER_ACTOR_ALLOC_FAILED",
			"validate",
			"failed to instantiate PlayerActorData",
			{"index": index}
		)
	player.player_actor_id = StringName(player_actor_id)
	player.actor_id = StringName(actor_id)
	player.level = level
	player.progression_states = progression_states.duplicate(true)
	player.equipment_ids = equipment_ids

	return CODEC_UTILS.ok({"player": player})
