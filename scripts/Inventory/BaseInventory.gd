extends Resource
class_name BaseInventory

@export var name: String
@export var size: int
@export var slots: Array[InventorySlot]


func get_item_qty(item: String) ->int:
	for slot in slots:
		if slot.item
