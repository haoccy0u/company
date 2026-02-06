extends Node
class_name InventoryConponent

signal changed(component: InventoryConponent)

@export var inventory: BaseInventory
@export var item_definitions: Array[BaseItemData] = []

var _max_stack_by_id: Dictionary = {}


func _ready() -> void:
	if inventory == null:
		inventory = BaseInventory.new()
	_rebuild_item_lookup()


func setup(capacity: int) -> void:
	if inventory == null:
		inventory = BaseInventory.new(capacity)
	inventory.capacity = capacity
	emit_signal("changed", self)


func get_slot(index: int) -> InventorySlot:
	if inventory == null:
		return null
	return inventory.get_slot(index)


func add_item(item_id: StringName, amount: int) -> int:
	if inventory == null:
		return 0
	var max_stack := _get_max_stack(item_id)
	var added := inventory.add(item_id, amount, max_stack)
	if added > 0:
		emit_signal("changed", self)
	return added


func remove_item(item_id: StringName, amount: int) -> int:
	if inventory == null:
		return 0
	var removed := inventory.remove(item_id, amount)
	if removed > 0:
		emit_signal("changed", self)
	return removed


func move_full_to_cursor(index: int, cursor: InventorySlot) -> bool:
	var slot := get_slot(index)
	if slot == null or cursor == null or not cursor.is_empty() or slot.is_empty():
		return false
	cursor.set_stack(slot.item_id, slot.count)
	slot.clear()
	emit_signal("changed", self)
	return true


func place_full_from_cursor(index: int, cursor: InventorySlot) -> bool:
	var slot := get_slot(index)
	if slot == null or cursor == null or cursor.is_empty() or not slot.is_empty():
		return false
	slot.set_stack(cursor.item_id, cursor.count)
	cursor.clear()
	emit_signal("changed", self)
	return true


func merge_from_cursor(index: int, cursor: InventorySlot) -> int:
	var slot := get_slot(index)
	if slot == null or cursor == null or cursor.is_empty() or slot.is_empty() or slot.item_id != cursor.item_id:
		return 0
	var moved := slot.try_add(cursor.item_id, cursor.count, _get_max_stack(cursor.item_id))
	if moved <= 0:
		return 0
	cursor.try_remove(moved)
	emit_signal("changed", self)
	return moved


func place_one_from_cursor(index: int, cursor: InventorySlot) -> bool:
	var slot := get_slot(index)
	if slot == null or cursor == null or cursor.is_empty():
		return false

	var max_stack := _get_max_stack(cursor.item_id)
	if max_stack <= 0:
		return false

	if slot.is_empty():
		slot.set_stack(cursor.item_id, 1)
		cursor.try_remove(1)
		emit_signal("changed", self)
		return true

	if slot.item_id != cursor.item_id or slot.count >= max_stack:
		return false

	slot.count += 1
	cursor.try_remove(1)
	emit_signal("changed", self)
	return true


func pickup_half_to_cursor(index: int, cursor: InventorySlot) -> bool:
	var slot := get_slot(index)
	if slot == null or cursor == null or not cursor.is_empty() or slot.is_empty():
		return false
	var take := int(ceil(float(slot.count) / 2.0))
	cursor.set_stack(slot.item_id, take)
	slot.try_remove(take)
	emit_signal("changed", self)
	return true


func swap_with_cursor(index: int, cursor: InventorySlot) -> bool:
	var slot := get_slot(index)
	if slot == null or cursor == null or slot.is_empty() or cursor.is_empty():
		return false
	var slot_item := slot.item_id
	var slot_count := slot.count
	slot.set_stack(cursor.item_id, cursor.count)
	cursor.set_stack(slot_item, slot_count)
	emit_signal("changed", self)
	return true


func _get_max_stack(item_id: StringName) -> int:
	if item_id == StringName():
		return 0
	if _max_stack_by_id.is_empty() and not item_definitions.is_empty():
		_rebuild_item_lookup()
	if _max_stack_by_id.has(item_id):
		return int(_max_stack_by_id[item_id])
	return 0


func _rebuild_item_lookup() -> void:
	_max_stack_by_id.clear()
	for item_data in item_definitions:
		if item_data == null:
			continue
		if item_data.item_id == StringName() or item_data.max_stack <= 0:
			continue
		_max_stack_by_id[item_data.item_id] = item_data.max_stack
