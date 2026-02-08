extends Control
class_name SlotControl

@onready var background: TextureRect = $MarginContainer/Background
@onready var icon: TextureRect = $MarginContainer/Background/Icon
@onready var count_label: Label = $MarginContainer/Background/Icon/Count

var comp: InventoryComponent
var slot_index: int = -1
var session: InventorySession
var request_refresh: Callable


func bind(_comp: InventoryComponent, _index: int, _session: InventorySession, _request_refresh: Callable) -> void:
	comp = _comp
	slot_index = _index
	session = _session
	request_refresh = _request_refresh
	refresh()

func refresh() -> void:
	if comp == null:
		icon.texture = null
		count_label.text = ""
		return

	var s := comp.get_slot(slot_index)
	if s == null or s.is_empty():
		icon.texture = null
		count_label.text = ""
		return

	icon.texture = s.item.texture
	count_label.text = str(s.count) if s.count > 1 else ""

func _gui_input(event: InputEvent) -> void:
	if session == null or comp == null:
		return

	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			session.left_click(comp, slot_index)
			if request_refresh.is_valid():
				request_refresh.call()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			session.right_click(comp, slot_index)
			if request_refresh.is_valid():
				request_refresh.call()
			accept_event()
