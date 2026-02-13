extends Node

signal save_finished(save_slot: int, report: Dictionary)
signal load_finished(save_slot: int, report: Dictionary)

const SAVEABLE_PROTOCOL := preload("res://src/save/Saveable.gd")
const SAVE_REPORT := preload("res://src/save/SaveReport.gd")
const SAVE_GROUP := "saveable"
const SAVE_VERSION := 1
const SAVE_DIR := "user://saves"
const SAVE_SLOT_FILE_PREFIX := "save_slot_"
const SAVE_FILE_SUFFIX := ".json"


func save_slot(save_slot_id: int = 1) -> Dictionary:
	var path: String = _save_slot_path(save_slot_id)
	var report: Dictionary = SAVE_REPORT.make_save(path)
	if save_slot_id <= 0:
		SAVE_REPORT.add_error(report, "invalid_save_slot")
		save_finished.emit(save_slot_id, report)
		return report

	var payload_nodes: Array[Dictionary] = _collect_save_payload_nodes(report)

	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"saved_at_unix": Time.get_unix_time_from_system(),
		"nodes": payload_nodes
	}

	var write_result: int = _write_json(path, payload)
	if write_result != OK:
		SAVE_REPORT.add_error(report, "write_failed:%s" % error_string(write_result))
		save_finished.emit(save_slot_id, report)
		return report

	SAVE_REPORT.set_ok(report, true)
	save_finished.emit(save_slot_id, report)
	return report


func load_slot(save_slot_id: int = 1) -> Dictionary:
	var path: String = _save_slot_path(save_slot_id)
	var report: Dictionary = SAVE_REPORT.make_load(path)
	if save_slot_id <= 0:
		SAVE_REPORT.add_error(report, "invalid_save_slot")
		load_finished.emit(save_slot_id, report)
		return report
	if not FileAccess.file_exists(path):
		SAVE_REPORT.add_error(report, "save_file_not_found")
		load_finished.emit(save_slot_id, report)
		return report

	var parse: Dictionary = _read_json(path)
	if not bool(parse["ok"]):
		SAVE_REPORT.add_error(report, String(parse["error"]))
		load_finished.emit(save_slot_id, report)
		return report

	var payload_variant: Variant = parse.get("data", {})
	if not (payload_variant is Dictionary):
		SAVE_REPORT.add_error(report, "invalid_payload")
		load_finished.emit(save_slot_id, report)
		return report
	var payload: Dictionary = payload_variant

	var nodes_variant: Variant = payload.get("nodes", [])
	if not (nodes_variant is Array):
		SAVE_REPORT.add_error(report, "invalid_nodes_field")
		load_finished.emit(save_slot_id, report)
		return report
	var entries: Array = nodes_variant

	var saveable_map: Dictionary = _build_saveable_map()
	_apply_load_entries(entries, saveable_map, report)

	SAVE_REPORT.finalize_ok_when_no_errors(report)
	load_finished.emit(save_slot_id, report)
	return report


func delete_slot(save_slot_id: int = 1) -> bool:
	if save_slot_id <= 0:
		return false
	var path: String = _save_slot_path(save_slot_id)
	if not FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK


func list_save_slots() -> Array[int]:
	var save_slots: Array[int] = []
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir == null:
		return save_slots

	dir.list_dir_begin()
	while true:
		var file_name: String = dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir():
			continue
		if not file_name.begins_with(SAVE_SLOT_FILE_PREFIX):
			continue
		if not file_name.ends_with(SAVE_FILE_SUFFIX):
			continue

		var raw_slot: String = file_name.trim_prefix(SAVE_SLOT_FILE_PREFIX).trim_suffix(SAVE_FILE_SUFFIX)
		var slot_id: int = int(raw_slot)
		if slot_id > 0:
			save_slots.append(slot_id)
	dir.list_dir_end()

	save_slots.sort()
	return save_slots


func _collect_save_payload_nodes(report: Dictionary) -> Array[Dictionary]:
	var payload_nodes: Array[Dictionary] = []
	var seen_ids: Dictionary = {}

	for node_variant in get_tree().get_nodes_in_group(SAVE_GROUP):
		var node: Node = node_variant as Node
		var validation: Dictionary = SAVEABLE_PROTOCOL.validate_node(node)
		if not bool(validation["ok"]):
			SAVE_REPORT.add_skipped_node(report, {
				"path": str(node.get_path()) if node != null else "<null>",
				"reason": validation["reason"]
			})
			continue

		var save_id: String = String(node.call("get_save_id"))
		if save_id.is_empty():
			SAVE_REPORT.add_skipped_node(report, {
				"path": str(node.get_path()),
				"reason": "empty_save_id"
			})
			continue
		if seen_ids.has(save_id):
			SAVE_REPORT.add_error(report, "duplicate_save_id:%s" % save_id)
			continue

		var state_variant: Variant = node.call("capture_state")
		if not (state_variant is Dictionary):
			SAVE_REPORT.add_skipped_node(report, {
				"id": save_id,
				"reason": "capture_state_not_dictionary"
			})
			continue

		var state: Dictionary = state_variant
		seen_ids[save_id] = true
		var save_type: String = String(node.call("get_save_type")) if node.has_method("get_save_type") else String(node.get_class())
		payload_nodes.append({
			"id": save_id,
			"type": save_type,
			"state": state
		})
		SAVE_REPORT.add_saved_id(report, save_id)

	return payload_nodes


func _apply_load_entries(entries: Array, saveable_map: Dictionary, report: Dictionary) -> void:
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			SAVE_REPORT.add_error(report, "invalid_node_entry")
			continue
		var entry: Dictionary = entry_variant

		var save_id: String = String(entry.get("id", ""))
		if save_id.is_empty():
			SAVE_REPORT.add_error(report, "missing_node_id")
			continue
		if not saveable_map.has(save_id):
			SAVE_REPORT.add_missing_id(report, save_id)
			continue

		var state_variant: Variant = entry.get("state", {})
		if not (state_variant is Dictionary):
			SAVE_REPORT.add_error(report, "invalid_state:%s" % save_id)
			continue
		var state: Dictionary = state_variant

		var node_variant: Variant = saveable_map[save_id]
		var node: Node = node_variant as Node
		if node == null:
			SAVE_REPORT.add_error(report, "invalid_saveable_node:%s" % save_id)
			continue

		var apply_result: Variant = node.call("apply_state", state)
		if apply_result is bool and not apply_result:
			SAVE_REPORT.add_error(report, "apply_state_rejected:%s" % save_id)
			continue

		SAVE_REPORT.add_loaded_id(report, save_id)


func _save_slot_path(save_slot_id: int) -> String:
	return "%s/%s%d%s" % [SAVE_DIR, SAVE_SLOT_FILE_PREFIX, save_slot_id, SAVE_FILE_SUFFIX]


func _ensure_save_dir() -> int:
	return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))


func _write_json(path: String, payload: Dictionary) -> int:
	var dir_result: int = _ensure_save_dir()
	if dir_result != OK and dir_result != ERR_ALREADY_EXISTS:
		return dir_result

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()

	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	return OK


func _read_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"ok": false,
			"error": "open_failed:%s" % error_string(FileAccess.get_open_error()),
			"data": {}
		}

	var text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {
			"ok": false,
			"error": "json_parse_failed",
			"data": {}
		}

	return {
		"ok": true,
		"error": "",
		"data": parsed
	}


func _build_saveable_map() -> Dictionary:
	var map: Dictionary = {}

	for node_variant in get_tree().get_nodes_in_group(SAVE_GROUP):
		var node: Node = node_variant as Node
		var validation: Dictionary = SAVEABLE_PROTOCOL.validate_node(node)
		if not bool(validation["ok"]):
			continue

		var save_id: String = String(node.call("get_save_id"))
		if save_id.is_empty():
			continue
		if map.has(save_id):
			push_warning("Duplicate save_id detected in scene: %s" % save_id)
			continue

		map[save_id] = node

	return map
