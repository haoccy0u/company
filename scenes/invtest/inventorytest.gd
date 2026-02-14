extends Node2D
class_name InventoryTestCoordinator

const INVENTORY_UI_ID: StringName = &"inventory_panel"

@onready var chest: ChestButton = $Chest
@onready var player: PlayerPlaceholder = $player


func _ready() -> void:
	if chest == null:
		push_warning("Chest node not found.")
		return
	if not chest.request_open_inventory.is_connected(_on_request_open_inventory):
		chest.request_open_inventory.connect(_on_request_open_inventory)


func _on_request_open_inventory(chest_inventory: InventoryComponent) -> void:
	if chest_inventory == null:
		push_warning("Chest inventory is null.")
		return
	if player == null:
		push_warning("Player node not found.")
		return

	var player_inventory: InventoryComponent = player.get_inventory_component()
	if player_inventory == null:
		push_warning("Player inventory component not found.")
		return

	var ui_manager := get_node_or_null("/root/UIManager")
	if ui_manager == null:
		push_warning("UIManager not found.")
		return

	ui_manager.call("show_ui", INVENTORY_UI_ID, {
		"player_inv": player_inventory,
		"chest_inv": chest_inventory
	})
