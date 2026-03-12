extends Node
class_name PlayerItemVaultState

const SAVE_GROUP := "saveable"
const DEFAULT_SAVE_ID := &"progress/player/item_vault"
const SCHEMA_VERSION := 1

@export var save_enabled: bool = true
@export var save_id: StringName = DEFAULT_SAVE_ID


func _ready() -> void:
	if save_enabled and not is_in_group(SAVE_GROUP):
		add_to_group(SAVE_GROUP)


func get_save_id() -> String:
	if not save_enabled:
		return ""
	if save_id.is_empty():
		return String(DEFAULT_SAVE_ID)
	return String(save_id)


func get_save_type() -> String:
	return "player_progress"


func capture_state() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"item_vault": {},
	}


func apply_state(data: Dictionary) -> bool:
	if data.is_empty():
		return true

	var schema_version: int = int(data.get("schema_version", -1))
	if schema_version != SCHEMA_VERSION:
		return false

	var item_vault_variant: Variant = data.get("item_vault", {})
	return item_vault_variant is Dictionary


func reset_to_default_item_vault() -> bool:
	return true
