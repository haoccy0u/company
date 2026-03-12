extends Node

signal save_finished(save_slot: int, report: Dictionary)
signal load_finished(save_slot: int, report: Dictionary)

const SAVEABLE_PROTOCOL := preload("res://src/save/Saveable.gd")
const SAVE_REPORT := preload("res://src/save/SaveReport.gd")
const SAVE_GROUP := "saveable"
const SAVE_VERSION := 2
const SAVE_DIR := "user://saves"
const SAVE_SLOT_FILE_PREFIX := "save_slot_"
const SAVE_FILE_SUFFIX := ".json"
const TMP_FILE_SUFFIX := ".tmp"
const BAK_FILE_SUFFIX := ".bak"

const STAGE_VALIDATE := "validate"
const STAGE_COLLECT := "collect"
const STAGE_SERIALIZE := "serialize"
const STAGE_WRITE := "write"
const STAGE_READ := "read"
const STAGE_PARSE := "parse"
const STAGE_APPLY := "apply"
const STAGE_ID_RULE := "id_rule"


func save_slot(save_slot_id: int = 1) -> Dictionary:
	var path: String = _save_slot_path(save_slot_id)
	var report: Dictionary = SAVE_REPORT.make_save(path, save_slot_id, SAVE_VERSION)
	if save_slot_id <= 0:
		SAVE_REPORT.add_error(
			report,
			"SAVE.VALIDATE.INVALID_SLOT_ID",
			STAGE_VALIDATE,
			"save_slot_id must be > 0",
			{"save_slot_id": save_slot_id}
		)
		SAVE_REPORT.finalize(report)
		save_finished.emit(save_slot_id, report)
		return report

	var payload_nodes: Array[Dictionary] = _collect_save_payload_nodes(report)
	if _has_errors(report):
		SAVE_REPORT.finalize(report)
		save_finished.emit(save_slot_id, report)
		return report

	var payload: Dictionary = _build_payload(payload_nodes)

	var write_result: int = _write_json_atomic(path, payload)
	if write_result != OK:
		SAVE_REPORT.add_error(
			report,
			"SAVE.WRITE.ATOMIC_WRITE_FAILED",
			STAGE_WRITE,
			error_string(write_result),
			{"path": path, "error_code": write_result}
		)
		SAVE_REPORT.finalize(report)
		save_finished.emit(save_slot_id, report)
		return report

	SAVE_REPORT.finalize(report)
	save_finished.emit(save_slot_id, report)
	return report


func load_slot(save_slot_id: int = 1) -> Dictionary:
	var report: Dictionary = _load_slot_internal(save_slot_id, {}, false)
	load_finished.emit(save_slot_id, report)
	return report


func load_slot_filtered(save_slot_id: int = 1, allowed_save_ids: Array[String] = []) -> Dictionary:
	var allowed_ids_map: Dictionary = _allowed_ids_map(allowed_save_ids)
	var report: Dictionary = _load_slot_internal(save_slot_id, allowed_ids_map, true)
	load_finished.emit(save_slot_id, report)
	return report


func _load_slot_internal(save_slot_id: int, allowed_ids_map: Dictionary, filter_enabled: bool) -> Dictionary:
	var path: String = _save_slot_path(save_slot_id)
	var report: Dictionary = SAVE_REPORT.make_load(path, save_slot_id, SAVE_VERSION)
	if save_slot_id <= 0:
		SAVE_REPORT.add_error(
			report,
			"SAVE.VALIDATE.INVALID_SLOT_ID",
			STAGE_VALIDATE,
			"save_slot_id must be > 0",
			{"save_slot_id": save_slot_id}
		)
		SAVE_REPORT.finalize(report)
		return report
	if filter_enabled and allowed_ids_map.is_empty():
		SAVE_REPORT.add_error(
			report,
			"SAVE.VALIDATE.EMPTY_ALLOWED_SAVE_IDS",
			STAGE_VALIDATE,
			"allowed_save_ids must contain at least one non-empty id when using load_slot_filtered"
		)
		SAVE_REPORT.finalize(report)
		return report
	if not FileAccess.file_exists(path):
		SAVE_REPORT.add_error(
			report,
			"SAVE.READ.FILE_NOT_FOUND",
			STAGE_READ,
			"save file not found",
			{"path": path}
		)
		SAVE_REPORT.finalize(report)
		return report

	var read_result: Dictionary = _read_text(path)
	if not bool(read_result.get("ok", false)):
		SAVE_REPORT.add_error(
			report,
			String(read_result.get("error_code", "SAVE.READ.OPEN_FAILED")),
			STAGE_READ,
			String(read_result.get("error_message", "open failed")),
			{"path": path}
		)
		SAVE_REPORT.finalize(report)
		return report

	var parse_result: Dictionary = _parse_json_text(String(read_result.get("text", "")))
	if not bool(parse_result.get("ok", false)):
		SAVE_REPORT.add_error(
			report,
			String(parse_result.get("error_code", "SAVE.PARSE.JSON_PARSE_FAILED")),
			STAGE_PARSE,
			String(parse_result.get("error_message", "json parse failed")),
			{
				"path": path,
				"line": int(parse_result.get("error_line", -1))
			}
		)
		SAVE_REPORT.finalize(report)
		return report

	var payload_variant: Variant = parse_result.get("data", {})
	if not (payload_variant is Dictionary):
		SAVE_REPORT.add_error(
			report,
			"SAVE.PARSE.INVALID_PAYLOAD",
			STAGE_PARSE,
			"root payload must be Dictionary",
			{"path": path}
		)
		SAVE_REPORT.finalize(report)
		return report
	var payload: Dictionary = payload_variant

	_validate_payload_schema(payload, report)
	if _has_errors(report):
		SAVE_REPORT.finalize(report)
		return report

	var entries_variant: Variant = payload.get("scene_nodes", [])
	var entries: Array = entries_variant as Array

	var saveable_map: Dictionary = _build_saveable_map(report)
	if _has_errors(report):
		SAVE_REPORT.finalize(report)
		return report
	var filtered_out_count: int = _apply_load_entries(entries, saveable_map, report, allowed_ids_map, filter_enabled)
	if filter_enabled:
		var metrics: Dictionary = SAVE_REPORT.metrics_of(report)
		metrics["filtered_out_count"] = filtered_out_count
		report["metrics"] = metrics

	SAVE_REPORT.finalize(report)
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


func _allowed_ids_map(allowed_save_ids: Array[String]) -> Dictionary:
	var out: Dictionary = {}
	for allowed_id in allowed_save_ids:
		var normalized: String = String(allowed_id).strip_edges()
		if normalized.is_empty():
			continue
		out[normalized] = true
	return out


func _collect_save_payload_nodes(report: Dictionary) -> Array[Dictionary]:
	var payload_nodes: Array[Dictionary] = []
	var seen_ids: Dictionary = {}

	for node_variant in get_tree().get_nodes_in_group(SAVE_GROUP):
		var node: Node = node_variant as Node
		var validation: Dictionary = SAVEABLE_PROTOCOL.validate_node(node)
		if not bool(validation["ok"]):
			var node_path: String = str(node.get_path()) if node != null else "<null>"
			SAVE_REPORT.add_warning(
				report,
				"SAVE.COLLECT.INVALID_SAVEABLE_NODE",
				STAGE_COLLECT,
				String(validation["reason"]),
				{"path": node_path}
			)
			SAVE_REPORT.add_skipped_node(report, {
				"path": node_path,
				"reason": validation["reason"]
			})
			continue

		var save_id: String = String(node.call("get_save_id"))
		if save_id.is_empty():
			SAVE_REPORT.add_warning(
				report,
				"SAVE.COLLECT.EMPTY_SAVE_ID",
				STAGE_COLLECT,
				"save_id is empty",
				{"path": str(node.get_path())}
			)
			SAVE_REPORT.add_skipped_node(report, {
				"path": str(node.get_path()),
				"reason": "empty_save_id"
			})
			continue
		if seen_ids.has(save_id):
			SAVE_REPORT.add_error(
				report,
				"SAVE.COLLECT.DUPLICATE_SAVE_ID",
				STAGE_COLLECT,
				"duplicate save_id found while collecting scene nodes",
				{"save_id": save_id, "path": str(node.get_path())}
			)
			continue

		if not _is_standard_save_id(save_id):
			SAVE_REPORT.add_warning(
				report,
				"SAVE.COLLECT.NON_STANDARD_SAVE_ID",
				STAGE_ID_RULE,
				"save_id should match <system>/<object>/<instance> (2 or 3 segments, lowercase a-z0-9_)",
				{"save_id": save_id, "path": str(node.get_path())}
			)

		var state_variant: Variant = node.call("capture_state")
		if not (state_variant is Dictionary):
			SAVE_REPORT.add_warning(
				report,
				"SAVE.COLLECT.INVALID_CAPTURE_STATE",
				STAGE_COLLECT,
				"capture_state must return Dictionary",
				{"save_id": save_id}
			)
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


func _apply_load_entries(
	entries: Array,
	saveable_map: Dictionary,
	report: Dictionary,
	allowed_ids_map: Dictionary = {},
	filter_enabled: bool = false
) -> int:
	var filtered_out_count: int = 0
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			SAVE_REPORT.add_error(
				report,
				"SAVE.APPLY.INVALID_NODE_ENTRY",
				STAGE_APPLY,
				"scene_nodes entry must be Dictionary"
			)
			continue
		var entry: Dictionary = entry_variant

		var save_id: String = String(entry.get("id", ""))
		if save_id.is_empty():
			SAVE_REPORT.add_error(
				report,
				"SAVE.APPLY.MISSING_NODE_ID",
				STAGE_APPLY,
				"scene_nodes entry missing id"
			)
			continue
		if filter_enabled and not allowed_ids_map.has(save_id):
			filtered_out_count += 1
			continue
		if not saveable_map.has(save_id):
			SAVE_REPORT.add_warning(
				report,
				"SAVE.APPLY.NODE_MISSING_IN_SCENE",
				STAGE_APPLY,
				"save_id not found in current scene",
				{"save_id": save_id}
			)
			SAVE_REPORT.add_missing_id(report, save_id)
			continue

		var state_variant: Variant = entry.get("state", {})
		if not (state_variant is Dictionary):
			SAVE_REPORT.add_error(
				report,
				"SAVE.APPLY.INVALID_STATE",
				STAGE_APPLY,
				"entry.state must be Dictionary",
				{"save_id": save_id}
			)
			continue
		var state: Dictionary = state_variant

		var node_variant: Variant = saveable_map[save_id]
		var node: Node = node_variant as Node
		if node == null:
			SAVE_REPORT.add_error(
				report,
				"SAVE.APPLY.INVALID_RUNTIME_NODE",
				STAGE_APPLY,
				"saveable map contains null node",
				{"save_id": save_id}
			)
			continue

		var apply_result: Variant = node.call("apply_state", state)
		if apply_result is bool and not apply_result:
			SAVE_REPORT.add_error(
				report,
				"SAVE.APPLY.APPLY_STATE_REJECTED",
				STAGE_APPLY,
				"apply_state returned false",
				{"save_id": save_id}
			)
			continue

		SAVE_REPORT.add_loaded_id(report, save_id)

	return filtered_out_count


func _save_slot_path(save_slot_id: int) -> String:
	return "%s/%s%d%s" % [SAVE_DIR, SAVE_SLOT_FILE_PREFIX, save_slot_id, SAVE_FILE_SUFFIX]


func _ensure_save_dir() -> int:
	return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))


func _write_json_atomic(path: String, payload: Dictionary) -> int:
	var dir_result: int = _ensure_save_dir()
	if dir_result != OK and dir_result != ERR_ALREADY_EXISTS:
		return dir_result

	var tmp_path: String = "%s%s" % [path, TMP_FILE_SUFFIX]
	var write_tmp_result: int = _write_json_file(tmp_path, payload)
	if write_tmp_result != OK:
		return write_tmp_result

	var final_abs: String = ProjectSettings.globalize_path(path)
	var tmp_abs: String = ProjectSettings.globalize_path(tmp_path)
	var bak_abs: String = "%s%s" % [final_abs, BAK_FILE_SUFFIX]

	if FileAccess.file_exists(bak_abs):
		DirAccess.remove_absolute(bak_abs)

	if FileAccess.file_exists(path):
		var backup_result: int = DirAccess.rename_absolute(final_abs, bak_abs)
		if backup_result != OK:
			DirAccess.remove_absolute(tmp_abs)
			return backup_result

	var commit_result: int = DirAccess.rename_absolute(tmp_abs, final_abs)
	if commit_result != OK:
		if FileAccess.file_exists(bak_abs):
			DirAccess.rename_absolute(bak_abs, final_abs)
		return commit_result

	if FileAccess.file_exists(bak_abs):
		DirAccess.remove_absolute(bak_abs)

	return OK


func _write_json_file(path: String, payload: Dictionary) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()

	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	return OK


func _read_text(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"ok": false,
			"error_code": "SAVE.READ.OPEN_FAILED",
			"error_message": error_string(FileAccess.get_open_error()),
			"text": ""
		}

	return {
		"ok": true,
		"error_code": "",
		"error_message": "",
		"text": file.get_as_text()
	}


func _parse_json_text(text: String) -> Dictionary:
	var json := JSON.new()
	var parse_result: int = json.parse(text)
	if parse_result != OK:
		return {
			"ok": false,
			"error_code": "SAVE.PARSE.JSON_PARSE_FAILED",
			"error_message": json.get_error_message(),
			"error_line": json.get_error_line(),
			"data": {}
		}

	return {
		"ok": true,
		"error_code": "",
		"error_message": "",
		"error_line": -1,
		"data": json.data
	}


func _build_saveable_map(report: Dictionary) -> Dictionary:
	var map: Dictionary = {}

	for node_variant in get_tree().get_nodes_in_group(SAVE_GROUP):
		var node: Node = node_variant as Node
		var validation: Dictionary = SAVEABLE_PROTOCOL.validate_node(node)
		if not bool(validation["ok"]):
			SAVE_REPORT.add_warning(
				report,
				"SAVE.APPLY.INVALID_SAVEABLE_NODE",
				STAGE_APPLY,
				String(validation["reason"]),
				{"path": str(node.get_path()) if node != null else "<null>"}
			)
			continue

		var save_id: String = String(node.call("get_save_id"))
		if save_id.is_empty():
			continue
		if map.has(save_id):
			SAVE_REPORT.add_error(
				report,
				"SAVE.APPLY.DUPLICATE_RUNTIME_SAVE_ID",
				STAGE_APPLY,
				"duplicate save_id detected in runtime scene",
				{"save_id": save_id}
			)
			continue

		map[save_id] = node

	return map


func _build_payload(scene_nodes: Array[Dictionary]) -> Dictionary:
	return {
		"meta": {
			"version": SAVE_VERSION,
			"saved_at_unix": int(Time.get_unix_time_from_system()),
		},
		"domains": {},
		"scene_nodes": scene_nodes,
	}


func _validate_payload_schema(payload: Dictionary, report: Dictionary) -> void:
	var meta_variant: Variant = payload.get("meta", null)
	if not (meta_variant is Dictionary):
		SAVE_REPORT.add_error(
			report,
			"SAVE.VALIDATE.INVALID_META",
			STAGE_VALIDATE,
			"payload.meta must be Dictionary"
		)
		return
	var meta: Dictionary = meta_variant

	var version: int = int(meta.get("version", -1))
	if version != SAVE_VERSION:
		SAVE_REPORT.add_error(
			report,
			"SAVE.VALIDATE.UNSUPPORTED_VERSION",
			STAGE_VALIDATE,
			"unsupported save version",
			{"expected": SAVE_VERSION, "actual": version}
		)

	var domains_variant: Variant = payload.get("domains", {})
	if not (domains_variant is Dictionary):
		SAVE_REPORT.add_error(
			report,
			"SAVE.VALIDATE.INVALID_DOMAINS",
			STAGE_VALIDATE,
			"payload.domains must be Dictionary"
		)

	var scene_nodes_variant: Variant = payload.get("scene_nodes", null)
	if not (scene_nodes_variant is Array):
		SAVE_REPORT.add_error(
			report,
			"SAVE.VALIDATE.INVALID_SCENE_NODES",
			STAGE_VALIDATE,
			"payload.scene_nodes must be Array"
		)


func _has_errors(report: Dictionary) -> bool:
	return not SAVE_REPORT.errors_of(report).is_empty()


func _is_standard_save_id(save_id: String) -> bool:
	if save_id.is_empty():
		return false

	var segments: PackedStringArray = save_id.split("/", false)
	if segments.size() < 2 or segments.size() > 3:
		return false

	for segment in segments:
		if segment.is_empty():
			return false
		for i in segment.length():
			var ch: int = segment.unicode_at(i)
			var is_lower: bool = ch >= 97 and ch <= 122
			var is_digit: bool = ch >= 48 and ch <= 57
			var is_underscore: bool = ch == 95
			if not (is_lower or is_digit or is_underscore):
				return false

	return true
