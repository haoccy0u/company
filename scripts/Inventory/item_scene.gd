extends Node2D
class_name ItemScene

var item_data: BaseItemData
var texture: Texture2D 

func _init(item_data: BaseItemData) -> void:
	texture = item_data.texture
