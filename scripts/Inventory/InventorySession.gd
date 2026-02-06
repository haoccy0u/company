extends RefCounted
class_name InventorySession

enum ClickButton {
	LEFT,
	RIGHT,
}

signal cursor_changed(cursor_slot: InventorySlot)
signal operation_failed(reason: StringName, context: Dictionary)

var cursor_slot: InventorySlot = InventorySlot.new()
var containers: Array[InventoryConponent] = []


func set_containers(new_containers: Array[InventoryConponent]) -> void:
	containers = new_containers.duplicate()


func click(container_id: int, slot_index: int, button: ClickButton) -> bool:
	var component := _get_component(container_id)
	if component == null:
		emit_signal("operation_failed", &"INVALID_INDEX", {"container_id": container_id})
		return false

	var slot := component.get_slot(slot_index)
	if slot == null:
		emit_signal("operation_failed", &"INVALID_INDEX", {"container_id": container_id, "slot_index": slot_index})
		return false

	var changed := false
	match button:
		ClickButton.LEFT:
			changed = _handle_left_click(component, slot_index, slot)
		ClickButton.RIGHT:
			changed = _handle_right_click(component, slot_index, slot)
		_:
			emit_signal("operation_failed", &"NO_OP", {"reason": "unsupported_button"})
			return false

	if changed:
		emit_signal("cursor_changed", cursor_slot)
	return changed


func _handle_left_click(component: InventoryConponent, slot_index: int, slot: InventorySlot) -> bool:
	if cursor_slot.is_empty() and not slot.is_empty():
		return component.move_full_to_cursor(slot_index, cursor_slot)

	if not cursor_slot.is_empty() and slot.is_empty():
		return component.place_full_from_cursor(slot_index, cursor_slot)

	if cursor_slot.is_empty() and slot.is_empty():
		return false

	if slot.item_id == cursor_slot.item_id:
		return component.merge_from_cursor(slot_index, cursor_slot) > 0

	return component.swap_with_cursor(slot_index, cursor_slot)


func _handle_right_click(component: InventoryConponent, slot_index: int, slot: InventorySlot) -> bool:
	if cursor_slot.is_empty() and not slot.is_empty():
		return component.pickup_half_to_cursor(slot_index, cursor_slot)

	if not cursor_slot.is_empty() and slot.is_empty():
		return component.place_one_from_cursor(slot_index, cursor_slot)

	if cursor_slot.is_empty() and slot.is_empty():
		return false

	if slot.item_id == cursor_slot.item_id:
		return component.place_one_from_cursor(slot_index, cursor_slot)

	return component.swap_with_cursor(slot_index, cursor_slot)


func _get_component(container_id: int) -> InventoryConponent:
	if container_id < 0 or container_id >= containers.size():
		return null
	return containers[container_id]
