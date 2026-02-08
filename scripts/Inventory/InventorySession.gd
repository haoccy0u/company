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

	# cursor 空：拿起整堆
	if cursor.is_empty():
		if slot.is_empty():
			return
		cursor = slot.take(999999)
		cursor_origin = comp  
		comp.notify_changed()
		return

	# cursor 非空：slot 空 或 同物品 -> 放入/合并
	if slot.is_empty() or (slot.item != null and slot.item.item_id == cursor.item.item_id):
		_place_and_notify_if_changed(comp, slot, -1)
		return

	# 不同物品：交换
	slot.swap_with(cursor)
	cursor_origin = comp  
	comp.notify_changed()


func right_click(comp: InventoryComponent, index: int) -> void:
	if comp == null:
		return
	var slot := comp.get_slot(index)
	if slot == null:
		return

	# cursor 空：拿一半
	if cursor.is_empty():
		if slot.is_empty():
			return
		var half: int = (slot.count + 1) >> 1
		cursor = slot.take(half)
		cursor_origin = comp 
		comp.notify_changed()
		return

	# cursor 非空：空槽或同物品 -> 放 1
	if slot.is_empty() or (slot.item != null and slot.item.item_id == cursor.item.item_id):
		_place_and_notify_if_changed(comp, slot, 1)
		return

	# 不同物品：右键无动作


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

	# 仍然塞不下：不丢地上 -> 返回失败（阻止关闭）// 以后扩展
	cursor.count = rem
	return false




func _place_and_notify_if_changed(comp: InventoryComponent, slot: Slot, amount: int) -> void:
	var before_item := slot.item
	var before_slot_count := slot.count
	var before_cursor_count := cursor.count

	slot.place_from(cursor, amount)

	if slot.item != before_item or slot.count != before_slot_count or cursor.count != before_cursor_count:
		comp.notify_changed()

	# 放完了就不需要 origin 了
	if cursor.is_empty():
		cursor_origin = null
