@tool
extends Resource
class_name ItemContainer

@export var item_container_id: StringName = &""

@export var slot_count: int = 36 : set = _set_slot_count, get = _get_slot_count
@export var slots: Array[Slot] = []
var _slot_count: int = 36


func _init() -> void:
	_rebuild_slots_if_needed()


func _get_slot_count() -> int:
	return _slot_count


func _set_slot_count(v: int) -> void:
	v = max(v, 0)
	if v == _slot_count:
		return
	_slot_count = v
	_rebuild_slots_preserve()


func _rebuild_slots_if_needed() -> void:
	# Ensure slot array shape is valid when creating/loading the resource.
	if slots.size() != _slot_count:
		_rebuild_slots_preserve()
		return
	for i in range(slots.size()):
		if slots[i] == null:
			slots[i] = Slot.new()


func _rebuild_slots_preserve() -> void:
	# Preserve existing slot data as much as possible when resizing.
	var old := slots
	slots = []
	slots.resize(_slot_count)

	for i in range(_slot_count):
		if i < old.size() and old[i] != null:
			slots[i] = old[i]
		else:
			slots[i] = Slot.new()


func try_insert(insert_item: ItemData, amount: int) -> int:
	if insert_item == null or amount <= 0:
		return amount

	var remaining := amount

	# 1) Merge into existing non-full stacks of the same item first.
	for s in slots:
		if remaining <= 0:
			break
		if s != null and not s.is_empty() and s.item.item_id == insert_item.item_id:
			remaining = s.add_items(insert_item, remaining)

	# 2) Then place leftovers into empty slots.
	for s in slots:
		if remaining <= 0:
			break
		if s != null and s.is_empty():
			remaining = s.add_items(insert_item, remaining)

	return remaining
