extends BaseInventoryUIPanel
class_name InventoryUIPanel

@export var slot_scene: PackedScene

@onready var backpack_grid: GridContainer = $VBoxContainer/BackpackGrid
@onready var chest_grid: GridContainer = $VBoxContainer/ChestGrid

var backpack_comp: InventoryComponent
var chest_comp: InventoryComponent


#region Public
func open_with(backpack: InventoryComponent, chest: InventoryComponent) -> void:
	backpack_comp = backpack
	chest_comp = chest
	open_with_components([backpack_comp, chest_comp])
#endregion


#region Protected
func _on_open_components(_components: Array[InventoryComponent]) -> void:
	_build_grid(backpack_grid, backpack_comp, 9)
	_build_grid(chest_grid, chest_comp, 9)

func _refresh_views() -> void:
	for child in backpack_grid.get_children():
		(child as SlotControl).refresh()
	for child in chest_grid.get_children():
		(child as SlotControl).refresh()

func _get_default_close_target() -> InventoryComponent:
	return backpack_comp
#endregion


#region Private
func _build_grid(grid: GridContainer, comp: InventoryComponent, columns: int) -> void:
	for child in grid.get_children():
		child.queue_free()

	grid.columns = columns
	if comp == null:
		return

	var n := comp.get_slot_count()
	for i in range(n):
		var ui := slot_scene.instantiate() as SlotControl
		grid.add_child(ui)
		ui.bind(comp, i, session)
#endregion
