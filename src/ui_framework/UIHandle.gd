extends RefCounted
class_name UIHandle

var _manager: Node = null
var _ui_id: StringName = &""


func _init(manager: Node, ui_id: StringName) -> void:
	_manager = manager
	_ui_id = ui_id


func close(reason: StringName = &"manual") -> bool:
	if _manager == null or not is_instance_valid(_manager):
		return false
	if not _manager.has_method("hide_ui"):
		return false
	return bool(_manager.call("hide_ui", _ui_id, reason))


func is_open() -> bool:
	if _manager == null or not is_instance_valid(_manager):
		return false
	if not _manager.has_method("is_open"):
		return false
	return bool(_manager.call("is_open", _ui_id))


func get_view() -> Node:
	if _manager == null or not is_instance_valid(_manager):
		return null
	if not _manager.has_method("get_ui_node"):
		return null
	var node_variant: Variant = _manager.call("get_ui_node", _ui_id)
	return node_variant as Node
