extends CanvasLayer
class_name HUD

@export var inventory_ui_scene: PackedScene  # 拖 InventoryUIPanel.tscn
var inventory_ui: InventoryUIPanel

func _ready() -> void:
	add_to_group("hud")

func open_inventory(player_inv: InventoryComponent, chest_inv: InventoryComponent) -> void:
	if inventory_ui == null:
		inventory_ui = inventory_ui_scene.instantiate() as InventoryUIPanel
		add_child(inventory_ui)

	inventory_ui.open_with(player_inv, chest_inv)
