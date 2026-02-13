extends Node
class_name InventoryComponent

signal changed

const SAVE_GROUP := "saveable"
const INVENTORY_SAVE_CODEC := preload("res://src/save/codecs/InventorySaveCodec.gd")

@export var save_enabled: bool = true
@export var save_id: StringName = &""
@export var container_template: ItemContainer
var container: ItemContainer

#region Public
func _ready() -> void:
	ensure_initialized()
	if save_enabled and not is_in_group(SAVE_GROUP):
		add_to_group(SAVE_GROUP)

func ensure_initialized() -> void:
	if container != null:
		return
	if container_template != null:
		container = container_template.duplicate(true) as ItemContainer
	else:
		container = ItemContainer.new()
		container.slot_count = 27

func get_slot_count() -> int:
	ensure_initialized()
	return container.slots.size()

func get_slot(index: int) -> Slot:
	ensure_initialized()
	if index < 0 or index >= container.slots.size():
		return null
	return container.slots[index]

func get_save_id() -> String:
	if not save_enabled:
		return ""
	if not save_id.is_empty():
		return String(save_id)
	var node_path_id := String(get_path())
	if not node_path_id.is_empty():
		return node_path_id
	if container_template != null and not container_template.item_container_id.is_empty():
		return String(container_template.item_container_id)
	ensure_initialized()
	if container != null and not container.item_container_id.is_empty():
		return String(container.item_container_id)
	return ""

func get_save_type() -> String:
	return "inventory"

func capture_state() -> Dictionary:
	ensure_initialized()
	return INVENTORY_SAVE_CODEC.capture(self)

func apply_state(data: Dictionary) -> bool:
	ensure_initialized()
	var applied: bool = bool(INVENTORY_SAVE_CODEC.apply(self, data))
	if applied:
		notify_changed()
	return applied

# Single source of truth for inventory data-change notifications.
func notify_changed() -> void:
	changed.emit()

func try_insert(item: ItemData, amount: int) -> int:
	return int(try_insert_result(item, amount)["remainder"])

func try_insert_result(item: ItemData, amount: int) -> Dictionary:
	ensure_initialized()
	var result := container.try_insert_result(item, amount)
	if bool(result["changed"]):
		notify_changed()
	return result

func place_from_cursor(index: int, cursor_stack: ItemStack, amount: int = -1) -> Dictionary:
	ensure_initialized()
	if cursor_stack == null or cursor_stack.is_empty():
		return _make_result(false, 0, 0, &"invalid_input")

	var slot := get_slot(index)
	if slot == null:
		return _make_result(false, 0, cursor_stack.count, &"invalid_index")

	var before_cursor_count := cursor_stack.count
	slot.place_from(cursor_stack, amount)
	var moved := maxi(before_cursor_count - cursor_stack.count, 0)
	var did_change := moved > 0
	var reason: StringName = &"ok"
	if not did_change:
		reason = &"no_space_or_incompatible"

	if did_change:
		notify_changed()

	return _make_result(did_change, moved, cursor_stack.count, reason)

func take_to_cursor(index: int, cursor_stack: ItemStack, amount: int = -1) -> Dictionary:
	ensure_initialized()
	if cursor_stack == null:
		return _make_result(false, 0, 0, &"invalid_input")
	if not cursor_stack.is_empty():
		return _make_result(false, 0, cursor_stack.count, &"cursor_not_empty")

	var slot := get_slot(index)
	if slot == null:
		return _make_result(false, 0, 0, &"invalid_index")
	if slot.is_empty():
		return _make_result(false, 0, 0, &"empty_slot")

	var take_amount := slot.count if amount < 0 else amount
	var picked := slot.take(take_amount)
	if picked.is_empty():
		return _make_result(false, 0, 0, &"empty_slot")

	cursor_stack.item = picked.item
	cursor_stack.count = picked.count
	notify_changed()
	return _make_result(true, picked.count, cursor_stack.count, &"ok")

func swap_with_cursor(index: int, cursor_stack: ItemStack) -> Dictionary:
	ensure_initialized()
	if cursor_stack == null:
		return _make_result(false, 0, 0, &"invalid_input")

	var slot := get_slot(index)
	if slot == null:
		return _make_result(false, 0, cursor_stack.count, &"invalid_index")

	var before_slot_item := slot.item
	var before_slot_count := slot.count
	var before_cursor_item := cursor_stack.item
	var before_cursor_count := cursor_stack.count

	slot.swap_with(cursor_stack)

	var did_change := (
		slot.item != before_slot_item
		or slot.count != before_slot_count
		or cursor_stack.item != before_cursor_item
		or cursor_stack.count != before_cursor_count
	)
	if did_change:
		notify_changed()

	return _make_result(
		did_change,
		before_slot_count + before_cursor_count if did_change else 0,
		cursor_stack.count,
		&"ok" if did_change else &"no_change"
	)
#endregion

#region Private
func _make_result(did_change: bool, moved: int, remainder: int, reason: StringName, meta: Dictionary = {}) -> Dictionary:
	return {
		"changed": did_change,
		"moved": moved,
		"remainder": remainder,
		"reason": reason,
		"meta": meta
	}
#endregion
