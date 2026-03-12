extends RefCounted
class_name SaveReport

const STATUS_SUCCEEDED := "succeeded"
const STATUS_PARTIAL := "partial"
const STATUS_FAILED := "failed"

const KEY_STATUS := "status"
const KEY_SUCCESS := "success"
const KEY_OK := "ok" # Deprecated compatibility alias; mirrors `success`.
const KEY_PATH := "path"
const KEY_ERRORS := "errors"
const KEY_WARNINGS := "warnings"
const KEY_SAVED_IDS := "saved_ids"
const KEY_SKIPPED_NODES := "skipped_nodes"
const KEY_LOADED_IDS := "loaded_ids"
const KEY_MISSING_IDS := "missing_ids"
const KEY_METRICS := "metrics"
const KEY_META := "meta"


static func make_save(path: String, save_slot_id: int, schema_version: int) -> Dictionary:
	return _make_report("save", path, save_slot_id, schema_version)


static func make_load(path: String, save_slot_id: int, schema_version: int) -> Dictionary:
	return _make_report("load", path, save_slot_id, schema_version)


static func set_ok(report: Dictionary, ok_value: bool) -> void:
	report[KEY_SUCCESS] = ok_value
	report[KEY_OK] = ok_value
	report[KEY_STATUS] = STATUS_SUCCEEDED if ok_value else STATUS_FAILED


static func finalize_ok_when_no_errors(report: Dictionary) -> void:
	finalize(report)


static func finalize(report: Dictionary) -> void:
	var metrics := metrics_of(report)
	metrics["saved_count"] = saved_ids_of(report).size()
	metrics["loaded_count"] = loaded_ids_of(report).size()
	metrics["missing_count"] = missing_ids_of(report).size()
	metrics["skipped_count"] = skipped_nodes_of(report).size()
	report[KEY_METRICS] = metrics

	var has_errors: bool = not errors_of(report).is_empty()
	var has_partial_flags: bool = (
		not warnings_of(report).is_empty()
		or not missing_ids_of(report).is_empty()
		or not skipped_nodes_of(report).is_empty()
	)

	var status: String = STATUS_SUCCEEDED
	var success: bool = true
	if has_errors:
		status = STATUS_FAILED
		success = false
	elif has_partial_flags:
		status = STATUS_PARTIAL

	report[KEY_STATUS] = status
	report[KEY_SUCCESS] = success
	report[KEY_OK] = success


static func add_error(
	report: Dictionary,
	code: String,
	stage: String,
	message: String = "",
	context: Dictionary = {}
) -> void:
	var errors := errors_of(report)
	errors.append(_make_issue(code, stage, message, context))
	report[KEY_ERRORS] = errors


static func add_warning(
	report: Dictionary,
	code: String,
	stage: String,
	message: String = "",
	context: Dictionary = {}
) -> void:
	var warnings := warnings_of(report)
	warnings.append(_make_issue(code, stage, message, context))
	report[KEY_WARNINGS] = warnings


static func add_saved_id(report: Dictionary, save_id: String) -> void:
	var ids := saved_ids_of(report)
	ids.append(save_id)
	report[KEY_SAVED_IDS] = ids


static func add_loaded_id(report: Dictionary, save_id: String) -> void:
	var ids := loaded_ids_of(report)
	ids.append(save_id)
	report[KEY_LOADED_IDS] = ids


static func add_missing_id(report: Dictionary, save_id: String) -> void:
	var ids := missing_ids_of(report)
	ids.append(save_id)
	report[KEY_MISSING_IDS] = ids


static func add_skipped_node(report: Dictionary, skipped: Dictionary) -> void:
	var nodes := skipped_nodes_of(report)
	nodes.append(skipped)
	report[KEY_SKIPPED_NODES] = nodes


static func errors_of(report: Dictionary) -> Array[Dictionary]:
	var value: Variant = report.get(KEY_ERRORS, [])
	var out: Array[Dictionary] = []
	if value is Array:
		for entry in value:
			if entry is Dictionary:
				out.append(entry as Dictionary)
	return out


static func warnings_of(report: Dictionary) -> Array[Dictionary]:
	var value: Variant = report.get(KEY_WARNINGS, [])
	var out: Array[Dictionary] = []
	if value is Array:
		for entry in value:
			if entry is Dictionary:
				out.append(entry as Dictionary)
	return out


static func saved_ids_of(report: Dictionary) -> Array:
	var value: Variant = report.get(KEY_SAVED_IDS, [])
	if value is Array:
		return value as Array
	return []


static func skipped_nodes_of(report: Dictionary) -> Array:
	var value: Variant = report.get(KEY_SKIPPED_NODES, [])
	if value is Array:
		return value as Array
	return []


static func loaded_ids_of(report: Dictionary) -> Array:
	var value: Variant = report.get(KEY_LOADED_IDS, [])
	if value is Array:
		return value as Array
	return []


static func missing_ids_of(report: Dictionary) -> Array:
	var value: Variant = report.get(KEY_MISSING_IDS, [])
	if value is Array:
		return value as Array
	return []


static func metrics_of(report: Dictionary) -> Dictionary:
	var value: Variant = report.get(KEY_METRICS, {})
	if value is Dictionary:
		return value as Dictionary
	return {
		"saved_count": 0,
		"loaded_count": 0,
		"missing_count": 0,
		"skipped_count": 0,
	}


static func _make_report(action: String, path: String, save_slot_id: int, schema_version: int) -> Dictionary:
	return {
		KEY_STATUS: STATUS_FAILED,
		KEY_SUCCESS: false,
		KEY_OK: false,
		KEY_PATH: path,
		KEY_ERRORS: [],
		KEY_WARNINGS: [],
		KEY_SAVED_IDS: [],
		KEY_SKIPPED_NODES: [],
		KEY_LOADED_IDS: [],
		KEY_MISSING_IDS: [],
		KEY_METRICS: {
			"saved_count": 0,
			"loaded_count": 0,
			"missing_count": 0,
			"skipped_count": 0,
		},
		KEY_META: {
			"action": action,
			"save_slot_id": save_slot_id,
			"path": path,
			"schema_version": schema_version,
			"generated_at_unix": int(Time.get_unix_time_from_system()),
		},
	}


static func _make_issue(code: String, stage: String, message: String, context: Dictionary) -> Dictionary:
	return {
		"code": code,
		"stage": stage,
		"message": message,
		"context": context.duplicate(true),
	}
