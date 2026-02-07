extends Control
class_name InventoryUIPanel

@export var slot_scene: PackedScene
@export var item_red: ItemData
@export var item_blue: ItemData

@onready var backpack_grid: GridContainer = $VBoxContainer/BackpackGrid
@onready var chest_grid: GridContainer = $VBoxContainer/ChestGrid



var session: InventorySession
var backpack: ItemContainer
var chest: ItemContainer

func _ready() -> void:
	session = InventorySession.new()

	# 创建两个容器（数据层）
	backpack = _make_backpack_container()
	chest = _make_chest_container()

	# 构建两边 UI
	_build_grid(backpack_grid, backpack, 9)
	_build_grid(chest_grid, chest, 9)

	refresh_all()


func _build_grid(grid: GridContainer, container: ItemContainer, columns: int) -> void:
	for child in grid.get_children():
		child.queue_free()

	grid.columns = columns

	for i in range(container.slots.size()):
		var ui := slot_scene.instantiate() as SlotControl
		grid.add_child(ui)  # ✅ 先进树，@onready 才会生效
		ui.bind(container, i, session, Callable(self, "refresh_all"))


func refresh_all() -> void:
	for child in backpack_grid.get_children():
		(child as SlotControl).refresh()
	for child in chest_grid.get_children():
		(child as SlotControl).refresh()
	# 下一步我们会在这里同步 cursor UI（跟随鼠标）


# ------------------- demo containers -------------------

func _make_backpack_container() -> ItemContainer:
	var c := ItemContainer.new()
	c.slot_count = 27

	# 背包默认塞红方块
	if item_red != null:
		c.try_insert(item_red, 70)

	return c


func _make_chest_container() -> ItemContainer:
	var c := ItemContainer.new()
	c.slot_count = 27

	# 箱子默认塞蓝方块
	if item_blue != null:
		c.try_insert(item_blue, 20)

	return c
