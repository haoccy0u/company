extends BaseInventoryUIPanel
class_name InventoryUIPanel

const INVENTORY_RESULT := preload("res://src/inventory/InventoryResult.gd")

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


func _ui_open(payload: Dictionary) -> void:
	var backpack_variant: Variant = payload.get("player_inv", null)
	var chest_variant: Variant = payload.get("chest_inv", null)
	var backpack: InventoryComponent = backpack_variant as InventoryComponent
	var chest: InventoryComponent = chest_variant as InventoryComponent
	if backpack == null or chest == null:
		push_warning("InventoryUIPanel._ui_open missing player_inv/chest_inv.")
		return
	open_with(backpack, chest)


func _ui_close(_reason: StringName = &"manual") -> bool:
	return request_close()
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
		ui.bind(
			comp,
			i,
			session,
			Callable(self, "_on_shift_left_click_slot"),
			Callable(self, "_on_shift_right_click_slot")
		)


func _on_shift_left_click_slot(source_comp: InventoryComponent, index: int) -> void:
	_transfer_by_shift(source_comp, index, -1)


func _on_shift_right_click_slot(source_comp: InventoryComponent, index: int) -> void:
	_transfer_by_shift(source_comp, index, 1)


func _transfer_by_shift(source_comp: InventoryComponent, index: int, amount: int) -> void:
	if source_comp == null:
		return
	if session == null:
		return
	if not session.cursor.is_empty():
		return

	var target_comp := _get_opposite_component(source_comp)
	if target_comp == null:
		return

	var picked := ItemStack.new()
	var take_result := source_comp.take_to_cursor(index, picked, amount)
	if not INVENTORY_RESULT.changed_of(take_result):
		return

	var insert_result := target_comp.try_insert_result(picked.item, picked.count)
	picked.count = INVENTORY_RESULT.remainder_of(insert_result)
	if picked.count <= 0:
		picked.clear()
		return

	var put_back_result := source_comp.place_from_cursor(index, picked, -1)
	if INVENTORY_RESULT.changed_of(put_back_result):
		return

	var fallback_result := source_comp.try_insert_result(picked.item, picked.count)
	picked.count = INVENTORY_RESULT.remainder_of(fallback_result)
	if picked.count > 0:
		session.cursor.item = picked.item
		session.cursor.count = picked.count
		push_warning("Shift transfer remainder moved to cursor (source and target are full).")
		refresh_all()
	picked.clear()


func _get_opposite_component(source_comp: InventoryComponent) -> InventoryComponent:
	if source_comp == backpack_comp:
		return chest_comp
	if source_comp == chest_comp:
		return backpack_comp
	return null
#endregion
