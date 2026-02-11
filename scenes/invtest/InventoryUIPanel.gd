extends Control
class_name InventoryUIPanel

@export var slot_scene: PackedScene

@onready var backpack_grid: GridContainer = $VBoxContainer/BackpackGrid
@onready var chest_grid: GridContainer = $VBoxContainer/ChestGrid
@export var cursor_scene: PackedScene

var cursor_ui: CursorWithItem
var session: InventorySession
var backpack_comp: InventoryComponent
var chest_comp: InventoryComponent

func _ready() -> void:
	session = InventorySession.new()
	visible = false  # 默认不显示，等 open_with 再打开
	_ensure_cursor()

func open_with(_backpack: InventoryComponent, _chest: InventoryComponent) -> void:
	# 可选：解绑旧信号
	_disconnect_components()

	backpack_comp = _backpack
	chest_comp = _chest

	# 可选：监听 changed 自动刷新（即使你 SlotControl 也会手动 refresh，也没关系）
	_connect_components()

	_build_grid(backpack_grid, backpack_comp, 9)
	_build_grid(chest_grid, chest_comp, 9)

	refresh_all()
	visible = true

func _build_grid(grid: GridContainer, comp: InventoryComponent, columns: int) -> void:
	for child in grid.get_children():
		child.queue_free()

	grid.columns = columns
	var n := comp.get_slot_count()

	for i in range(n):
		var ui := slot_scene.instantiate() as SlotControl
		grid.add_child(ui) # ✅ 先入树
		ui.bind(comp, i, session, Callable(self, "refresh_all"))

func _connect_components() -> void:
	var cb := Callable(self, "refresh_all")
	if backpack_comp != null and not backpack_comp.changed.is_connected(cb):
		backpack_comp.changed.connect(cb)
	if chest_comp != null and not chest_comp.changed.is_connected(cb):
		chest_comp.changed.connect(cb)

func _disconnect_components() -> void:
	var cb := Callable(self, "refresh_all")
	if backpack_comp != null and backpack_comp.changed.is_connected(cb):
		backpack_comp.changed.disconnect(cb)
	if chest_comp != null and chest_comp.changed.is_connected(cb):
		chest_comp.changed.disconnect(cb)

func refresh_all() -> void:
	for child in backpack_grid.get_children():
		(child as SlotControl).refresh()
	for child in chest_grid.get_children():
		(child as SlotControl).refresh()
	if cursor_ui != null:
		cursor_ui.sync(session)



func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		request_close()
		accept_event()


func request_close() -> void:
	var ok := session.return_cursor_to_origin(backpack_comp)
	if not ok:
		push_warning("Can't close: cursor items couldn't be returned.")
		refresh_all()
		return

	visible = false


func _try_return_cursor_to_backpack() -> bool:
	if session == null or session.cursor == null or session.cursor.is_empty():
		return true

	if backpack_comp == null:
		return false

	# 尝试把 cursor 全部塞回背包
	var item := session.cursor.item
	var amount := session.cursor.count
	var rem := backpack_comp.try_insert(item, amount)

	if rem <= 0:
		# 全部放回成功
		session.clear_cursor()  # 或者手动 item=null,count=0
		return true

	# 还剩 rem 个塞不下：阻止关闭
	session.cursor.count = rem
	# item 不变（仍是同一个物品）
	return false

func _ensure_cursor():
	if cursor_ui != null:
		return
	if cursor_scene == null:
		return
	cursor_ui = cursor_scene.instantiate() as CursorWithItem
	add_child(cursor_ui)
	# 放到最上层
	move_child(cursor_ui, get_child_count() - 1)
