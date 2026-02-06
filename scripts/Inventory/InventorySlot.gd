extends Resource
class_name InventorySlot

var item_id: StringName = StringName()
var count: int = 0


func is_empty() -> bool:
	return count == 0


func clear() -> void:
	item_id = StringName()
	count = 0


func set_stack(new_item_id: StringName, new_count: int) -> void:
	if new_count <= 0:
		clear()
		return
	item_id = new_item_id
	count = new_count


func space_left(target_item_id: StringName, max_stack: int) -> int:
	if max_stack <= 0:
		return 0
	if is_empty():
		return max_stack
	if item_id != target_item_id:
		return 0
	return maxi(0, max_stack - count)


func try_add(target_item_id: StringName, amount: int, max_stack: int) -> int:
	if amount <= 0 or target_item_id == StringName() or max_stack <= 0:
		return 0

	if is_empty():
		var added := mini(amount, max_stack)
		set_stack(target_item_id, added)
		return added

	if item_id != target_item_id:
		return 0

	var added_same := mini(amount, maxi(0, max_stack - count))
	count += added_same
	return added_same


func try_remove(amount: int) -> int:
	if amount <= 0 or is_empty():
		return 0

	var removed := mini(amount, count)
	count -= removed
	if count == 0:
		clear()
	return removed


func clone_slot() -> InventorySlot:
	var cloned := InventorySlot.new()
	cloned.item_id = item_id
	cloned.count = count
	return cloned
