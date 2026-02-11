extends Node2D
class_name PlayerPlaceholder

@export var item_red: ItemData
@export var item_blue: ItemData

@onready var inv: InventoryComponent = $PlayerInv



func _ready() -> void:
	add_to_group("player")

	# 播种测试物品（可选）
	if item_red != null:
		inv.try_insert(item_red, 70)
	# 你也可以在玩家背包里再放点别的
	if item_blue != null:
		inv.try_insert(item_blue, 5)
