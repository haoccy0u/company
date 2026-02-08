extends Node
class_name InventoryComponent

signal changed

@export var container_template: ItemContainer
var container: ItemContainer

func _ready() -> void:
	ensure_initialized()

func ensure_initialized() -> void:
	if container != null:
		return
	if container_template != null:
		container = container_template.duplicate(true) as ItemContainer
	else:
		container = ItemContainer.new()
		container.slot_count = 27

func get_slot_count() -> int:
	ensure_initialized()
	return container.slots.size()

func get_slot(index: int) -> Slot:
	ensure_initialized()
	if index < 0 or index >= container.slots.size():
		return null
	return container.slots[index]

func notify_changed() -> void:
	emit_signal("changed")

func try_insert(item: ItemData, amount: int) -> int:
	ensure_initialized()
	if item == null or amount <= 0:
		return amount

	var rem := container.try_insert(item, amount)
	# 只有真的插入了才通知 changed
	if rem != amount:
		notify_changed()
	return rem
