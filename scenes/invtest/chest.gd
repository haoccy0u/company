extends Button
class_name ChestButton

signal request_open_inventory(chest_inventory: InventoryComponent)

@export var item_blue: ItemData
@onready var inv: InventoryComponent = $InventoryComponent


func _ready() -> void:
	if item_blue != null:
		inv.try_insert(item_blue, 20)

	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	if inv == null:
		push_warning("Chest inventory component not found.")
		return
	request_open_inventory.emit(inv)
