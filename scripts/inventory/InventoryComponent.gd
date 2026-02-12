extends Node
class_name InventoryComponent

signal changed

@export var container_template: ItemContainer
var container: ItemContainer

#region Public
func _ready() -> void:
	ensure_initialized()

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

# Single source of truth for inventory data-change notifications.
func notify_changed() -> void:
	changed.emit()

func try_insert(item: ItemData, amount: int) -> int:
	var outcome := try_insert_result(item, amount)
	if bool(outcome["changed"]):
		notify_changed()
	return int(outcome["remainder"])

func try_insert_result(item: ItemData, amount: int) -> Dictionary:
	ensure_initialized()
	return container.try_insert_result(item, amount)

func place_from_cursor(index: int, cursor_stack: ItemStack, amount: int = -1) -> Dictionary:
	ensure_initialized()
	if cursor_stack == null or cursor_stack.is_empty():
		return {
			"changed": false,
			"moved": 0,
			"remainder": 0,
			"reason": &"invalid_input"
		}

	var slot := get_slot(index)
	if slot == null:
		return {
			"changed": false,
			"moved": 0,
			"remainder": cursor_stack.count,
			"reason": &"invalid_index"
		}

	var before_cursor_count := cursor_stack.count
	slot.place_from(cursor_stack, amount)
	var moved := maxi(before_cursor_count - cursor_stack.count, 0)
	var did_change := moved > 0
	var reason: StringName = &"ok"
	if not did_change:
		reason = &"no_space_or_incompatible"

	if did_change:
		notify_changed()

	return {
		"changed": did_change,
		"moved": moved,
		"remainder": cursor_stack.count,
		"reason": reason
	}
#endregion
