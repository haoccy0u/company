extends Control
class_name BaseInventorySlot

var comp: InventoryComponent
var slot_index: int = -1
var session: InventorySession
var on_shift_left_click: Callable
var on_shift_right_click: Callable


#region Public
func bind(
	_comp: InventoryComponent,
	_index: int,
	_session: InventorySession,
	_on_shift_left_click: Callable = Callable(),
	_on_shift_right_click: Callable = Callable()
) -> void:
	comp = _comp
	slot_index = _index
	session = _session
	on_shift_left_click = _on_shift_left_click
	on_shift_right_click = _on_shift_right_click
	refresh()

func refresh() -> void:
	if comp == null:
		_apply_empty_view()
		return

	var slot := comp.get_slot(slot_index)
	if slot == null or slot.is_empty():
		_apply_empty_view()
		return

	_apply_stack_view(slot)
#endregion


#region Protected
func _apply_empty_view() -> void:
	pass

func _apply_stack_view(_slot: Slot) -> void:
	pass
#endregion


#region Private
func _gui_input(event: InputEvent) -> void:
	if session == null or comp == null:
		return

	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.shift_pressed and on_shift_left_click.is_valid():
				on_shift_left_click.call(comp, slot_index)
			else:
				session.left_click(comp, slot_index)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.shift_pressed and on_shift_right_click.is_valid():
				on_shift_right_click.call(comp, slot_index)
			else:
				session.right_click(comp, slot_index)
			accept_event()
#endregion
