extends RefCounted
class_name UIRegistry

func register_definition(
	definitions: Dictionary,
	ui_id: StringName,
	scene: PackedScene,
	layer: StringName,
	cache_policy: StringName
) -> void:
	if ui_id.is_empty():
		push_warning("UIRegistry.register_definition failed: ui_id is empty.")
		return
	if scene == null:
		push_warning("UIRegistry.register_definition failed: scene is null for %s." % String(ui_id))
		return

	definitions[ui_id] = {
		"scene": scene,
		"layer": layer,
		"cache_policy": cache_policy
	}


func get_definition(definitions: Dictionary, ui_id: StringName) -> Dictionary:
	var value: Variant = definitions.get(ui_id, {})
	if value is Dictionary:
		return value as Dictionary
	return {}


func has_definition(definitions: Dictionary, ui_id: StringName) -> bool:
	return definitions.has(ui_id)


func unregister_definition(definitions: Dictionary, ui_id: StringName) -> void:
	if definitions.has(ui_id):
		definitions.erase(ui_id)
