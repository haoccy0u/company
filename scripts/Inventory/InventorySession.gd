extends RefCounted
class_name InventorySession

var cursor: ItemStack = ItemStack.new()

func left_click(container: ItemContainer, index: int) -> void:
	if container == null:
		return
	if index < 0 or index >= container.slots.size():
		return

	var slot := container.slots[index]
	if slot == null:
		return

	# cursor 空：拿起整堆
	if cursor.is_empty():
		if slot.is_empty():
			return
		cursor = slot.take(999999)
		return

	# cursor 非空：
	# slot 空 或 同物品 -> 放入/合并（即使合并失败，比如已满，也不交换）
	if slot.is_empty() or (slot.item != null and slot.item.item_id == cursor.item.item_id):
		slot.place_from(cursor, -1)
		return

	# 不同物品 -> 交换
	slot.swap_with(cursor)

func right_click(container: ItemContainer, index: int) -> void:
	if container == null:
		return
	if index < 0 or index >= container.slots.size():
		return

	var slot := container.slots[index]
	if slot == null:
		return

	# cursor 空：拿一半
	if cursor.is_empty():
		if slot.is_empty():
			return
		var half: int = (slot.count + 1) >> 1  # ceil(count/2)
		cursor = slot.take(half)
		return

	# cursor 非空：只放 1 个（空槽 or 同物品）
	if slot.is_empty() or (slot.item != null and slot.item.item_id == cursor.item.item_id):
		slot.place_from(cursor, 1)
		return

	# 不同物品：右键不交换，什么都不做
