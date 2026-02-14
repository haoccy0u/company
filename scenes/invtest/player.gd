extends Node2D
class_name PlayerPlaceholder

@export var item_red: ItemData
@export var item_blue: ItemData

@onready var inv: InventoryComponent = $PlayerInv


func _ready() -> void:
	add_to_group("player")

	if item_red != null:
		inv.try_insert(item_red, 70)
	if item_blue != null:
		inv.try_insert(item_blue, 5)


func get_inventory_component() -> InventoryComponent:
	return inv
