extends CanvasLayer
class_name HUD

@export var inventory_ui_scene: PackedScene
@export var test_save_slot: int = 1
var inventory_ui: InventoryUIPanel

func _ready() -> void:
	add_to_group("hud")
	_build_save_test_panel()

func open_inventory(player_inv: InventoryComponent, chest_inv: InventoryComponent) -> void:
	if inventory_ui == null:
		inventory_ui = inventory_ui_scene.instantiate() as InventoryUIPanel
		add_child(inventory_ui)

	inventory_ui.open_with(player_inv, chest_inv)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F5:
				_on_save_pressed()
				get_viewport().set_input_as_handled()
			KEY_F9:
				_on_load_pressed()
				get_viewport().set_input_as_handled()

func _build_save_test_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "SaveTestPanel"
	panel.offset_left = 16
	panel.offset_top = 16
	panel.offset_right = 300
	panel.offset_bottom = 220
	add_child(panel)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(box)

	var title := Label.new()
	title.text = "Save Test (save_slot %d)" % test_save_slot
	box.add_child(title)

	_add_test_button(box, "Save (F5)", Callable(self, "_on_save_pressed"))
	_add_test_button(box, "Load Apply (F9)", Callable(self, "_on_load_pressed"))

	var tips := Label.new()
	tips.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tips.text = "Flow: Save to save_slot with F5, then load from save_slot with F9."
	box.add_child(tips)

func _add_test_button(parent: VBoxContainer, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)

func _on_save_pressed() -> void:
	var manager := _get_save_manager()
	if manager == null:
		push_warning("SaveManager not found.")
		return
	var report_variant: Variant = manager.call("save_slot", test_save_slot)
	if report_variant is Dictionary:
		_print_report("save_slot", report_variant)
	else:
		push_warning("save_slot did not return Dictionary.")

func _on_load_pressed() -> void:
	var manager := _get_save_manager()
	if manager == null:
		push_warning("SaveManager not found.")
		return
	var report_variant: Variant = manager.call("load_slot", test_save_slot)
	if report_variant is Dictionary:
		_print_report("load_slot", report_variant)
	else:
		push_warning("load_slot did not return Dictionary.")

func _print_report(action: String, report: Dictionary) -> void:
	print("[save-test] ", action, " -> ", report)

func _get_save_manager() -> Node:
	return get_node_or_null("/root/SaveManager")
