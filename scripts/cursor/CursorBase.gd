extends Control
class_name CursorBase

@export var offset: Vector2 = Vector2(8, 8)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	visible = false

func _process(_delta: float) -> void:
	if visible:
		global_position = get_viewport().get_mouse_position() + offset

func clear() -> void:
	visible = false

# 给 UIPanel 调用的统一入口：子类覆盖
func sync(_session: InventorySession) -> void:
	pass
