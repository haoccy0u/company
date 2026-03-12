@tool
extends EditorPlugin

const DOCK_SCENE := preload("res://addons/equipment-resource-creator/EquipmentResourceCreatorDock.tscn")

var _dock_instance: Control


func _enter_tree() -> void:
	_dock_instance = DOCK_SCENE.instantiate() as Control
	if _dock_instance == null:
		return
	_dock_instance.name = "ResourceCreator"
	if _dock_instance.has_method("setup"):
		_dock_instance.call("setup", get_editor_interface())
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock_instance)


func _exit_tree() -> void:
	if _dock_instance == null:
		return
	remove_control_from_docks(_dock_instance)
	_dock_instance.queue_free()
	_dock_instance = null
