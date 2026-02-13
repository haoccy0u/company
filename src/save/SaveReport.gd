extends RefCounted
class_name SaveReport

const KEY_OK := "ok"
const KEY_PATH := "path"
const KEY_ERRORS := "errors"
const KEY_SAVED_IDS := "saved_ids"
const KEY_SKIPPED_NODES := "skipped_nodes"
const KEY_LOADED_IDS := "loaded_ids"
const KEY_MISSING_IDS := "missing_ids"


static func make_save(path: String) -> Dictionary:
	return {
		KEY_OK: false,
		KEY_PATH: path,
		KEY_SAVED_IDS: [],
		KEY_SKIPPED_NODES: [],
		KEY_ERRORS: []
	}


static func make_load(path: String) -> Dictionary:
	return {
		KEY_OK: false,
		KEY_PATH: path,
		KEY_LOADED_IDS: [],
		KEY_MISSING_IDS: [],
		KEY_ERRORS: []
	}


static func set_ok(report: Dictionary, ok_value: bool) -> void:
	report[KEY_OK] = ok_value


static func finalize_ok_when_no_errors(report: Dictionary) -> void:
	report[KEY_OK] = errors_of(report).is_empty()


static func add_error(report: Dictionary, error_code: String) -> void:
	var errors := errors_of(report)
	errors.append(error_code)
	report[KEY_ERRORS] = errors


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


static func errors_of(report: Dictionary) -> Array:
	var value: Variant = report.get(KEY_ERRORS, [])
	if value is Array:
		return value as Array
	return []


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
