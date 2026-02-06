extends Resource
class_name BaseInventory

@export var name: String
@export_range(0, 9999, 1) var capacity: int = 0:
	set(value):
		capacity = maxi(0, value)
		_ensure_slot_count()

@export var slots: Array[InventorySlot] = []

var _item_max_stack_by_id: Dictionary = {}


func _init(initial_capacity: int = 0) -> void:
	capacity = maxi(0, initial_capacity)
	_ensure_slot_count()


func configure(item_data_list: Array[BaseItemData]) -> void:
	_item_max_stack_by_id.clear()
	for item_data in item_data_list:
		if item_data == null or not item_data.is_valid_definition():
			continue
		_item_max_stack_by_id[item_data.item_id] = item_data.max_stack


func register_item(item_data: BaseItemData) -> void:
	if item_data == null or not item_data.is_valid_definition():
		return
	_item_max_stack_by_id[item_data.item_id] = item_data.max_stack


func get_max_stack(item_id: StringName) -> int:
	if item_id == StringName():
		return 0
	if not _item_max_stack_by_id.has(item_id):
		return 0
	return int(_item_max_stack_by_id[item_id])


func has_item_definition(item_id: StringName) -> bool:
	return get_max_stack(item_id) > 0


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
		if slot.count > 0:
			if slot.item_id == StringName():
				return false
			var max_stack := get_max_stack(slot.item_id)
			if max_stack <= 0 or slot.count > max_stack:
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


func find_indices_with_item(item_id: StringName) -> Array[int]:
	var result: Array[int] = []
	for i in slots.size():
		if slots[i].item_id == item_id:
			result.push_back(i)
	return result


func find_empty_indices() -> Array[int]:
	var result: Array[int] = []
	for i in slots.size():
		if slots[i].is_empty():
			result.push_back(i)
	return result


func capacity_for(item_id: StringName) -> int:
	var max_stack := get_max_stack(item_id)
	if max_stack <= 0:
		return 0

	var total := 0
	for slot in slots:
		if slot.is_empty():
			total += max_stack
		elif slot.item_id == item_id:
			total += slot.space_left(item_id, max_stack)
	return total


func add(item_id: StringName, amount: int) -> int:
	if amount <= 0:
		return 0
	var max_stack := get_max_stack(item_id)
	if max_stack <= 0:
		push_error("BaseInventory.add: item not registered: %s" % item_id)
		return 0

	var remaining := amount

	for slot in slots:
		if remaining <= 0:
			break
		if slot.item_id == item_id and slot.count < max_stack:
			remaining -= slot.try_add(item_id, remaining, max_stack)

	for slot in slots:
		if remaining <= 0:
			break
		if slot.is_empty():
			remaining -= slot.try_add(item_id, remaining, max_stack)

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
	if capacity < 0:
		capacity = 0
	if slots.is_empty() and capacity == 0:
		return

	if slots.size() > capacity:
		slots.resize(capacity)

	while slots.size() < capacity:
		slots.push_back(InventorySlot.new())

	for i in slots.size():
		if slots[i] == null:
			slots[i] = InventorySlot.new()


func _is_valid_index(index: int) -> bool:
	return index >= 0 and index < slots.size()
