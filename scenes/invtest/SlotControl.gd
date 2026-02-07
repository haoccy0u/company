extends Control
class_name SlotControl

@onready var background: TextureRect = $MarginContainer/Background
@onready var icon: TextureRect = $MarginContainer/Background/Icon
@onready var count_label: Label = $MarginContainer/Background/Icon/Count

var container: ItemContainer
var slot_index: int = -1
var session: InventorySession
var request_refresh: Callable

func _ready() -> void:
	# 不让子控件挡鼠标
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 数字黑色
	count_label.add_theme_color_override("font_color", Color.BLACK)

func bind(_container: ItemContainer, _index: int, _session: InventorySession, _request_refresh: Callable) -> void:
	container = _container
	slot_index = _index
	session = _session
	request_refresh = _request_refresh
	refresh()

func refresh() -> void:
	if container == null or slot_index < 0 or slot_index >= container.slots.size():
		icon.texture = null
		count_label.text = ""
		return

	var s := container.slots[slot_index]
	if s == null or s.is_empty():
		icon.texture = null
		count_label.text = ""
		return

	icon.texture = s.item.texture
	count_label.text = str(s.count) if s.count > 1 else ""

func _gui_input(event: InputEvent) -> void:
	if session == null or container == null:
		return

	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			session.left_click(container, slot_index)
			if request_refresh.is_valid():
				request_refresh.call()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			session.right_click(container, slot_index)
			if request_refresh.is_valid():
				request_refresh.call()
			accept_event()
