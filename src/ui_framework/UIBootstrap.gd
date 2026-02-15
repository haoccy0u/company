extends Node

const UI_CONFIG_TABLE := preload("res://src/ui_framework/UIConfigTable.gd")


func _ready() -> void:
	var ui_manager := get_node_or_null("/root/UIManager")
	if ui_manager == null:
		push_warning("UIBootstrap: UIManager not found.")
		return

	for entry in UI_CONFIG_TABLE.entries():
		_register_entry(ui_manager, entry)


func _register_entry(ui_manager: Node, entry: Dictionary) -> void:
	var ui_id: StringName = StringName(String(entry.get(UI_CONFIG_TABLE.KEY_UI_ID, "")))
	var scene_variant: Variant = entry.get(UI_CONFIG_TABLE.KEY_SCENE, null)
	var scene: PackedScene = scene_variant as PackedScene
	var layer: StringName = StringName(String(entry.get(UI_CONFIG_TABLE.KEY_LAYER, &"hud")))
	var cache_policy: StringName = StringName(String(entry.get(UI_CONFIG_TABLE.KEY_CACHE_POLICY, &"keep_alive")))

	if ui_id.is_empty():
		push_warning("UIBootstrap: skipped one UI config because ui_id is empty.")
		return
	if scene == null:
		push_warning("UIBootstrap: skipped UI config because scene is null: %s" % String(ui_id))
		return

	ui_manager.call("register_ui", ui_id, scene, layer, cache_policy)
