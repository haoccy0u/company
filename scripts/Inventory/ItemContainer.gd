@tool
extends Resource
class_name ItemContainer

@export var item_container_id: StringName = &""

@export var slot_count: int = 36 : set = _set_slot_count, get = _get_slot_count
@export var slots: Array[Slot] = []  # 自动生成用，不建议手动编辑

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
	# 资源第一次创建 / 或者从磁盘加载时，确保 slots 数量正确且没有 null
	if slots.size() != _slot_count:
		_rebuild_slots_preserve()
		return
	for i in range(slots.size()):
		if slots[i] == null:
			slots[i] = Slot.new()

func _rebuild_slots_preserve() -> void:
	# 尽量保留已有内容（比如你缩放格子数量时）
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
	var changed_any := false

	# 1) 先合并到同类未满的格子
	for s in slots:
		if remaining <= 0:
			break
		if s != null and not s.is_empty() and s.item.item_id == insert_item.item_id:
			var before := remaining
			remaining = s.add_items(insert_item, remaining)
			if remaining != before:
				changed_any = true

	# 2) 再找空格放
	for s in slots:
		if remaining <= 0:
			break
		if s != null and s.is_empty():
			var before2 := remaining
			remaining = s.add_items(insert_item, remaining)
			if remaining != before2:
				changed_any = true

	if changed_any:
		emit_changed() # 让后续 UI/监听者能刷新:contentReference[oaicite:2]{index=2}

	return remaining
