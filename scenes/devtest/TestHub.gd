extends Control
class_name DevTestHub

const TestRegistryRef = preload("res://src/devtest/TestRegistry.gd")

@onready var title_label: Label = $Root/Toolbar/TitleLabel
@onready var desc_label: Label = $Root/Toolbar/DescLabel
@onready var reload_button: Button = $Root/Toolbar/ReloadButton
@onready var clear_log_button: Button = $Root/Toolbar/ClearLogButton
@onready var test_list: ItemList = $Root/Body/LeftPane/LeftVBox/TestList
@onready var panel_host: Control = $Root/Body/RightPane/RightVBox/PanelFrame/PanelMargin/PanelHost
@onready var log_output: RichTextLabel = $Root/LogFrame/LogVBox/LogOutput

var _entries: Array[Dictionary] = []
var _current_index: int = -1
var _current_panel: Control


func _ready() -> void:
	_bind_ui()
	_entries = TestRegistryRef.get_entries()
	_populate_test_list()
	if not _entries.is_empty():
		test_list.select(0)
		_open_panel(0)
	else:
		_set_header("Dev Test Hub", "No test panels registered.")
		_log("No panels found in TestRegistry.")


func _bind_ui() -> void:
	if not test_list.item_selected.is_connected(_on_test_selected):
		test_list.item_selected.connect(_on_test_selected)
	if not reload_button.pressed.is_connected(_on_reload_pressed):
		reload_button.pressed.connect(_on_reload_pressed)
	if not clear_log_button.pressed.is_connected(_on_clear_log_pressed):
		clear_log_button.pressed.connect(_on_clear_log_pressed)


func _populate_test_list() -> void:
	test_list.clear()
	for i in range(_entries.size()):
		var entry: Dictionary = _entries[i]
		test_list.add_item(str(entry.get("label", "Unnamed")))
		test_list.set_item_metadata(i, entry.get("id", &""))


func _on_test_selected(index: int) -> void:
	_open_panel(index)


func _on_reload_pressed() -> void:
	if _current_index < 0:
		_log("Reload skipped: no selected panel.")
		return
	_open_panel(_current_index, true)


func _on_clear_log_pressed() -> void:
	log_output.clear()


func _open_panel(index: int, is_reload: bool = false) -> void:
	if index < 0 or index >= _entries.size():
		push_warning("DevTestHub._open_panel invalid index: %d" % index)
		return

	var entry: Dictionary = _entries[index]
	var scene_path: String = str(entry.get("scene_path", ""))
	if scene_path.is_empty():
		_log("Panel scene path is empty.")
		return

	var packed := load(scene_path) as PackedScene
	if packed == null:
		_log("Failed to load panel scene: %s" % scene_path)
		return

	_clear_current_panel()

	var panel_instance := packed.instantiate()
	if not (panel_instance is Control):
		_log("Panel is not Control: %s" % scene_path)
		if panel_instance != null:
			panel_instance.queue_free()
		return

	if panel_instance is TestPanelBase:
		var pending_base_panel := panel_instance as TestPanelBase
		if not pending_base_panel.log_requested.is_connected(_on_panel_log_requested):
			pending_base_panel.log_requested.connect(_on_panel_log_requested)

	_current_panel = panel_instance as Control
	_current_index = index
	_current_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_current_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_host.add_child(_current_panel)

	if _current_panel is TestPanelBase:
		var base_panel := _current_panel as TestPanelBase
		_set_header(base_panel.panel_title(), str(entry.get("description", "")))
	else:
		_set_header(str(entry.get("label", "Dev Test Hub")), str(entry.get("description", "")))

	if _current_panel.has_method("on_panel_activated"):
		_current_panel.call("on_panel_activated")

	_log("%s panel: %s" % ["Reloaded" if is_reload else "Opened", scene_path])


func _clear_current_panel() -> void:
	if _current_panel == null:
		return

	if _current_panel.has_method("on_panel_deactivated"):
		_current_panel.call("on_panel_deactivated")

	if _current_panel.get_parent() != null:
		_current_panel.get_parent().remove_child(_current_panel)
	_current_panel.queue_free()
	_current_panel = null


func _set_header(title: String, description: String) -> void:
	title_label.text = title
	desc_label.text = description


func _on_panel_log_requested(message: String) -> void:
	_log(message)


func _log(message: String) -> void:
	var line := "[%s] %s" % [Time.get_time_string_from_system(), message]
	log_output.append_text(line + "\n")
