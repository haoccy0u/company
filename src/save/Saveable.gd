extends RefCounted
class_name Saveable

static func _required_methods() -> Array[String]:
	return [
		"get_save_id",
		"capture_state",
		"apply_state"
	]


static func validate_node(node: Node) -> Dictionary:
	if node == null:
		return {
			"ok": false,
			"reason": "node_is_null"
		}

	for method_name in _required_methods():
		if not node.has_method(method_name):
			return {
				"ok": false,
				"reason": "missing_method:%s" % method_name
			}

	return {
		"ok": true,
		"reason": ""
	}


static func is_compatible(node: Node) -> bool:
	return bool(validate_node(node)["ok"])
