extends RefCounted
class_name InventorySession

var cursor: ItemStack = ItemStack.new()
var cursor_origin: InventoryComponent = null


func left_click(comp: InventoryComponent, index: int) -> void:
	if comp == null:
		return
	var slot := comp.get_slot(index)
	if slot == null:
		return

	# cursor empty: pick full stack.
	if cursor.is_empty():
		if slot.is_empty():
			return
		cursor = slot.take(slot.count)
		cursor_origin = comp
		comp.notify_changed()
		return

	# cursor has item: place/merge into empty or same-item slot.
	if slot.is_empty() or (slot.item != null and slot.item.item_id == cursor.item.item_id):
		_place_and_notify_if_changed(comp, slot, -1)
		return

	# Different item: swap.
	slot.swap_with(cursor)
	cursor_origin = comp
	comp.notify_changed()


func right_click(comp: InventoryComponent, index: int) -> void:
	if comp == null:
		return
	var slot := comp.get_slot(index)
	if slot == null:
		return

	# cursor empty: pick half.
	if cursor.is_empty():
		if slot.is_empty():
			return
		var half: int = (slot.count + 1) >> 1
		cursor = slot.take(half)
		cursor_origin = comp
		comp.notify_changed()
		return

	# cursor has item: place one into empty or same-item slot.
	if slot.is_empty() or (slot.item != null and slot.item.item_id == cursor.item.item_id):
		_place_and_notify_if_changed(comp, slot, 1)
		return

	# Different item on right click: no-op.


func clear_cursor() -> void:
	cursor.item = null
	cursor.count = 0
	cursor_origin = null


func return_cursor_to_origin(fallback: InventoryComponent = null) -> bool:
	if cursor == null or cursor.is_empty():
		cursor_origin = null
		return true

	var target := cursor_origin if cursor_origin != null else fallback
	if target == null:
		return false

	var rem := target.try_insert(cursor.item, cursor.count)
	if rem <= 0:
		clear_cursor()
		return true

	# Still cannot fully return: keep remaining cursor stack and block close.
	cursor.count = rem
	return false


func _place_and_notify_if_changed(comp: InventoryComponent, slot: Slot, amount: int) -> void:
	var before_item := slot.item
	var before_slot_count := slot.count
	var before_cursor_count := cursor.count

	slot.place_from(cursor, amount)

	if slot.item != before_item or slot.count != before_slot_count or cursor.count != before_cursor_count:
		comp.notify_changed()

	if cursor.is_empty():
		cursor_origin = null
