extends RefCounted
class_name InventorySession

var cursor: ItemStack = ItemStack.new()
var cursor_origin: InventoryComponent = null


#region Public
func left_click(comp: InventoryComponent, index: int) -> void:
	var slot := _get_slot_or_null(comp, index)
	if slot == null:
		return

	# cursor empty: pick full stack.
	if cursor.is_empty():
		if slot.is_empty():
			return
		var take_result := comp.take_to_cursor(index, cursor, -1)
		if bool(take_result["changed"]):
			cursor_origin = comp
		return

	# cursor has item: place/merge into empty or same-item slot.
	if slot.is_empty() or (slot.item != null and slot.item.item_id == cursor.item.item_id):
		_place_and_notify_if_changed(comp, index, -1)
		return

	# Different item: swap.
	var swap_result := comp.swap_with_cursor(index, cursor)
	if bool(swap_result["changed"]):
		cursor_origin = comp


func right_click(comp: InventoryComponent, index: int) -> void:
	var slot := _get_slot_or_null(comp, index)
	if slot == null:
		return

	# cursor empty: pick half.
	if cursor.is_empty():
		if slot.is_empty():
			return
		var half: int = slot.count >> 1
		var take_result := comp.take_to_cursor(index, cursor, half)
		if bool(take_result["changed"]):
			cursor_origin = comp
		return

	# cursor has item: place one into empty or same-item slot.
	if slot.is_empty() or (slot.item != null and slot.item.item_id == cursor.item.item_id):
		_place_and_notify_if_changed(comp, index, 1)
		return

	# Different item on right click: no-op.


func clear_cursor() -> void:
	cursor.clear()
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
#endregion


#region Private
func _place_and_notify_if_changed(comp: InventoryComponent, index: int, amount: int) -> void:
	comp.place_from_cursor(index, cursor, amount)
	if cursor.is_empty():
		cursor_origin = null

func _get_slot_or_null(comp: InventoryComponent, index: int) -> Slot:
	if comp == null:
		return null
	return comp.get_slot(index)
#endregion
