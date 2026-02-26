class_name TestPanelBase extends VBoxContainer

signal log_requested(message: String)

var _test_context: Dictionary = {}


func panel_title() -> String:
	return name


func set_test_context(context: Dictionary) -> void:
	_test_context = context


func on_panel_activated() -> void:
	pass


func on_panel_deactivated() -> void:
	pass


func log_line(message: String) -> void:
	log_requested.emit(message)


func ctx_has(key: StringName) -> bool:
	return _test_context.has(key)


func ctx_get(key: StringName, default_value: Variant = null) -> Variant:
	return _test_context.get(key, default_value)


func ctx_set(key: StringName, value: Variant) -> void:
	_test_context[key] = value


func ctx_erase(key: StringName) -> void:
	if _test_context.has(key):
		_test_context.erase(key)
