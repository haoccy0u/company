extends Node

const SAVE_MANAGER_PATH := "/root/SaveManager"
const ROSTER_STATE_PATH := NodePath("PlayerRosterState")
const ITEM_VAULT_STATE_PATH := NodePath("PlayerItemVaultState")
const DEFAULT_BOOT_SLOT_ID := 1

const BOOT_STATUS_LOADED_FROM_SLOT := &"loaded_from_slot"
const BOOT_STATUS_CREATED_EMPTY := &"created_empty"
const BOOT_STATUS_LOAD_FAILED_FALLBACK_EMPTY := &"load_failed_fallback_empty"

const PROGRESS_ALLOWED_IDS: Array[String] = [
	"progress/player/roster",
	"progress/player/item_vault",
]

var boot_status: StringName = BOOT_STATUS_CREATED_EMPTY
var boot_slot_id: int = DEFAULT_BOOT_SLOT_ID
var last_boot_report: Dictionary = {}


func _ready() -> void:
	_bootstrap_progress_state()


func get_roster_state() -> Node:
	return get_node_or_null(ROSTER_STATE_PATH)


func get_item_vault_state() -> Node:
	return get_node_or_null(ITEM_VAULT_STATE_PATH)

func reset_all_to_defaults() -> bool:
	var ok: bool = true

	var roster_state: Node = get_roster_state()
	if roster_state == null:
		ok = false
	else:
		if roster_state.has_method("reset_to_empty_roster"):
			ok = bool(roster_state.call("reset_to_empty_roster")) and ok
		elif roster_state.has_method("reset_to_default_roster"):
			ok = bool(roster_state.call("reset_to_default_roster")) and ok
		else:
			ok = false

	var item_vault_state: Node = get_item_vault_state()
	if item_vault_state == null or not item_vault_state.has_method("reset_to_default_item_vault"):
		ok = false
	else:
		ok = bool(item_vault_state.call("reset_to_default_item_vault")) and ok

	return ok


func _bootstrap_progress_state() -> void:
	var save_manager: Node = get_node_or_null(SAVE_MANAGER_PATH)
	if save_manager == null:
		reset_all_to_defaults()
		boot_status = BOOT_STATUS_LOAD_FAILED_FALLBACK_EMPTY
		last_boot_report = {"error": "SAVE_MANAGER_MISSING"}
		return

	var slots_variant: Variant = save_manager.call("list_save_slots")
	var has_slot: bool = false
	if slots_variant is Array:
		var slots: Array = slots_variant
		has_slot = slots.has(boot_slot_id)

	if not has_slot:
		reset_all_to_defaults()
		last_boot_report = _dict_or_empty(save_manager.call("save_slot", boot_slot_id))
		boot_status = BOOT_STATUS_CREATED_EMPTY
		return

	var report: Dictionary = _dict_or_empty(
		save_manager.call("load_slot_filtered", boot_slot_id, PROGRESS_ALLOWED_IDS)
	)
	if bool(report.get("success", false)) and _loaded_count_of(report) > 0:
		last_boot_report = report
		boot_status = BOOT_STATUS_LOADED_FROM_SLOT
		return
	if bool(report.get("success", false)):
		reset_all_to_defaults()
		last_boot_report = report
		boot_status = BOOT_STATUS_CREATED_EMPTY
		return

	reset_all_to_defaults()
	last_boot_report = report
	boot_status = BOOT_STATUS_LOAD_FAILED_FALLBACK_EMPTY


func _dict_or_empty(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value as Dictionary
	return {}


func _loaded_count_of(report: Dictionary) -> int:
	var metrics_variant: Variant = report.get("metrics", {})
	if not (metrics_variant is Dictionary):
		return 0
	var metrics: Dictionary = metrics_variant
	return int(metrics.get("loaded_count", 0))
