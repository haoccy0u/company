extends CursorBase
class_name CursorWithItem

@onready var icon: TextureRect = $Icon
@onready var count_label: Label = $Icon/Count


func _ready() -> void:
	super._ready()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.add_theme_color_override("font_color", Color.BLACK)

func sync(session: InventorySession) -> void:
	if session == null or session.cursor == null or session.cursor.is_empty():
		clear()
		return

	visible = true
	icon.texture = session.cursor.item.texture
	count_label.text = str(session.cursor.count) if session.cursor.count > 1 else ""
