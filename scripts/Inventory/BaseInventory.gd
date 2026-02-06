extends Resource
class_name BaseInventory

@export var name: String
@export_range(0, 9999, 1) var capacity: int = 0:
	set(value):
		field = maxi(0, value)
		_ensure_slot_count()

@export var slots: Array[InventorySlot] = []


func _init(initial_capacity: int = 0) -> void:
	capacity = maxi(0, initial_capacity)
	_ensure_slot_count()


func validate_invariants() -> bool:
	if slots.size() != capacity:
		return false
	for slot in slots:
		if slot == null:
			return false
		if slot.count < 0:
			return false
		if slot.count == 0 and slot.item_id != StringName():
			return false
		if slot.count > 0 and slot.item_id == StringName():
			return false
	return true


func get_slot(index: int) -> InventorySlot:
	if not _is_valid_index(index):
		return null
	return slots[index]


func count_of(item_id: StringName) -> int:
	var total := 0
	for slot in slots:
		if slot.item_id == item_id:
			total += slot.count
	return total


func capacity_for(item_id: StringName, slot_capacity: int) -> int:
	# slot_capacity is the per-slot max stack, not inventory.capacity.
	if item_id == StringName() or slot_capacity <= 0:
		return 0

	var total := 0
	for slot in slots:
		if slot.is_empty():
			total += slot_capacity
		elif slot.item_id == item_id:
			total += slot.space_left(item_id, slot_capacity)
	return total


func add(item_id: StringName, amount: int, slot_capacity: int) -> int:
	if amount <= 0 or item_id == StringName() or slot_capacity <= 0:
		return 0

	var remaining := amount

	for slot in slots:
		if remaining <= 0:
			break
		if slot.item_id == item_id and slot.count < slot_capacity:
			remaining -= slot.try_add(item_id, remaining, slot_capacity)

	for slot in slots:
		if remaining <= 0:
			break
		if slot.is_empty():
			remaining -= slot.try_add(item_id, remaining, slot_capacity)

	return amount - remaining


func remove(item_id: StringName, amount: int) -> int:
	if amount <= 0 or item_id == StringName():
		return 0

	var remaining := amount
	for i in range(slots.size() - 1, -1, -1):
		if remaining <= 0:
			break
		var slot := slots[i]
		if slot.item_id == item_id:
			remaining -= slot.try_remove(remaining)

	return amount - remaining


func _ensure_slot_count() -> void:
	if slots.size() > capacity:
		slots.resize(capacity)

	while slots.size() < capacity:
		slots.push_back(InventorySlot.new())

	for i in slots.size():
		if slots[i] == null:
			slots[i] = InventorySlot.new()


func _is_valid_index(index: int) -> bool:
	return index >= 0 and index < slots.size()
