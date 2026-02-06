extends Node
class_name InventoryConponent

signal changed(component: InventoryConponent)
signal slot_changed(component: InventoryConponent, index: int)
signal operation_failed(reason: StringName, context: Dictionary)

@export var inventory: BaseInventory
@export var component_id: StringName = StringName()


func _ready() -> void:
	if inventory == null:
		inventory = BaseInventory.new()


func setup(capacity: int, item_data_list: Array[BaseItemData] = []) -> void:
	if inventory == null:
		inventory = BaseInventory.new(capacity)
	inventory.capacity = capacity
	if not item_data_list.is_empty():
		inventory.configure(item_data_list)
	emit_signal("changed", self)


func register_item(item_data: BaseItemData) -> void:
	if inventory == null:
		return
	inventory.register_item(item_data)


func ensure_valid() -> bool:
	if inventory == null:
		return false
	return inventory.validate_invariants()


func get_capacity() -> int:
	if inventory == null:
		return 0
	return inventory.capacity


func get_slot(index: int) -> InventorySlot:
	if inventory == null:
		return null
	var slot := inventory.get_slot(index)
	if slot == null:
		emit_signal("operation_failed", &"INVALID_INDEX", {"index": index})
	return slot


func is_slot_empty(index: int) -> bool:
	var slot := get_slot(index)
	return slot == null or slot.is_empty()


func get_item_id(index: int) -> StringName:
	var slot := get_slot(index)
	if slot == null:
		return StringName()
	return slot.item_id


func get_count(index: int) -> int:
	var slot := get_slot(index)
	if slot == null:
		return 0
	return slot.count


func count_of(item_id: StringName) -> int:
	if inventory == null:
		return 0
	return inventory.count_of(item_id)


func capacity_for(item_id: StringName) -> int:
	if inventory == null:
		return 0
	return inventory.capacity_for(item_id)


func add_item(item_id: StringName, amount: int) -> int:
	if inventory == null:
		return 0
	var added := inventory.add(item_id, amount)
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


func clear_slot(index: int) -> bool:
	var slot := get_slot(index)
	if slot == null or slot.is_empty():
		return false
	slot.clear()
	emit_signal("slot_changed", self, index)
	emit_signal("changed", self)
	return true


func set_slot(index: int, item_id: StringName, count: int) -> bool:
	var slot := get_slot(index)
	if slot == null:
		return false

	if count <= 0:
		if slot.is_empty():
			return false
		slot.clear()
		emit_signal("slot_changed", self, index)
		emit_signal("changed", self)
		return true

	if inventory.get_max_stack(item_id) <= 0:
		emit_signal("operation_failed", &"ITEM_NOT_FOUND", {"item_id": item_id})
		return false

	var max_stack := inventory.get_max_stack(item_id)
	var clamped := mini(count, max_stack)
	if slot.item_id == item_id and slot.count == clamped:
		return false
	slot.set_stack(item_id, clamped)
	emit_signal("slot_changed", self, index)
	emit_signal("changed", self)
	return true


func move_full_to_cursor(index: int, cursor: InventorySlot) -> bool:
	var slot := get_slot(index)
	if slot == null or cursor == null:
		return false
	if not cursor.is_empty() or slot.is_empty():
		return false
	cursor.set_stack(slot.item_id, slot.count)
	slot.clear()
	emit_signal("slot_changed", self, index)
	emit_signal("changed", self)
	return true


func place_full_from_cursor(index: int, cursor: InventorySlot) -> bool:
	var slot := get_slot(index)
	if slot == null or cursor == null:
		return false
	if cursor.is_empty() or not slot.is_empty():
		return false
	slot.set_stack(cursor.item_id, cursor.count)
	cursor.clear()
	emit_signal("slot_changed", self, index)
	emit_signal("changed", self)
	return true


func merge_from_cursor(index: int, cursor: InventorySlot) -> int:
	var slot := get_slot(index)
	if slot == null or cursor == null:
		return 0
	if cursor.is_empty() or slot.is_empty() or slot.item_id != cursor.item_id:
		return 0
	var max_stack := inventory.get_max_stack(cursor.item_id)
	var moved := slot.try_add(cursor.item_id, cursor.count, max_stack)
	if moved <= 0:
		return 0
	cursor.try_remove(moved)
	emit_signal("slot_changed", self, index)
	emit_signal("changed", self)
	return moved


func place_one_from_cursor(index: int, cursor: InventorySlot) -> bool:
	var slot := get_slot(index)
	if slot == null or cursor == null or cursor.is_empty():
		return false

	var max_stack := inventory.get_max_stack(cursor.item_id)
	if max_stack <= 0:
		emit_signal("operation_failed", &"ITEM_NOT_FOUND", {"item_id": cursor.item_id})
		return false

	if slot.is_empty():
		slot.set_stack(cursor.item_id, 1)
		cursor.try_remove(1)
		emit_signal("slot_changed", self, index)
		emit_signal("changed", self)
		return true

	if slot.item_id != cursor.item_id or slot.count >= max_stack:
		return false

	slot.count += 1
	cursor.try_remove(1)
	emit_signal("slot_changed", self, index)
	emit_signal("changed", self)
	return true


func pickup_half_to_cursor(index: int, cursor: InventorySlot) -> bool:
	var slot := get_slot(index)
	if slot == null or cursor == null:
		return false
	if not cursor.is_empty() or slot.is_empty():
		return false
	var take := int(ceil(float(slot.count) / 2.0))
	cursor.set_stack(slot.item_id, take)
	slot.try_remove(take)
	emit_signal("slot_changed", self, index)
	emit_signal("changed", self)
	return true


func swap_with_cursor(index: int, cursor: InventorySlot) -> bool:
	var slot := get_slot(index)
	if slot == null or cursor == null:
		return false
	if slot.is_empty() or cursor.is_empty():
		return false

	var slot_item := slot.item_id
	var slot_count := slot.count
	slot.set_stack(cursor.item_id, cursor.count)
	cursor.set_stack(slot_item, slot_count)
	emit_signal("slot_changed", self, index)
	emit_signal("changed", self)
	return true
