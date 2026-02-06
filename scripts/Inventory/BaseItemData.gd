extends Resource
class_name BaseItemData

@export var item_id: StringName
@export var name: String
@export var texture: Texture2D
@export var description: String = ""
@export_range(1, 9999, 1) var max_stack: int = 64


func is_valid_definition() -> bool:
	return item_id != StringName() and max_stack >= 1
