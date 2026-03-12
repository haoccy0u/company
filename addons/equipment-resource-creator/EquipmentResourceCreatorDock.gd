@tool
extends VBoxContainer

const DEFAULT_SAVE_DIR := "res://data/devtest/expedition_v2/items"
const OPERATION_TYPES: Array[StringName] = [ &"add", &"sub", &"mult", &"div" ]

var _editor_interface: EditorInterface

var _save_dir_input: LineEdit
var _file_name_input: LineEdit
var _item_id_input: LineEdit
var _item_name_input: LineEdit
var _description_input: LineEdit
var _max_stack_input: SpinBox
var _texture_path_input: LineEdit
var _extra_tags_input: LineEdit

var _effect_op_input: OptionButton
var _effect_attr_input: LineEdit
var _effect_value_input: LineEdit
var _effect_list: ItemList

var _result_label: Label

var _effect_rows: Array[Dictionary] = []


func setup(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface


func _ready() -> void:
	_build_ui()
	_reset_form()


func _build_ui() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	add_theme_constant_override("separation", 8)
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL

	var title := Label.new()
	title.text = "Equipment Resource Creator"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var form := GridContainer.new()
	form.columns = 2
	form.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(form)

	_save_dir_input = _add_labeled_line_edit(form, "save_dir", DEFAULT_SAVE_DIR)
	_file_name_input = _add_labeled_line_edit(form, "file_name", "")
	_item_id_input = _add_labeled_line_edit(form, "item_id", "")
	_item_name_input = _add_labeled_line_edit(form, "item_name", "")
	_description_input = _add_labeled_line_edit(form, "description", "")
	_texture_path_input = _add_labeled_line_edit(form, "texture_path(optional)", "")
	_extra_tags_input = _add_labeled_line_edit(form, "extra_tags(csv)", "")

	var max_stack_label := Label.new()
	max_stack_label.text = "max_stack"
	form.add_child(max_stack_label)
	_max_stack_input = SpinBox.new()
	_max_stack_input.min_value = 1
	_max_stack_input.max_value = 9999
	_max_stack_input.step = 1
	_max_stack_input.value = 1
	_max_stack_input.size_flags_horizontal = SIZE_EXPAND_FILL
	form.add_child(_max_stack_input)

	var sep := HSeparator.new()
	add_child(sep)

	var effect_title := Label.new()
	effect_title.text = "equip_effect editor"
	add_child(effect_title)

	var effect_form := HBoxContainer.new()
	effect_form.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(effect_form)

	_effect_op_input = OptionButton.new()
	for op in OPERATION_TYPES:
		_effect_op_input.add_item(String(op))
	effect_form.add_child(_effect_op_input)

	_effect_attr_input = LineEdit.new()
	_effect_attr_input.placeholder_text = "attr (e.g. strength)"
	_effect_attr_input.size_flags_horizontal = SIZE_EXPAND_FILL
	effect_form.add_child(_effect_attr_input)

	_effect_value_input = LineEdit.new()
	_effect_value_input.placeholder_text = "value (float)"
	_effect_value_input.custom_minimum_size.x = 120
	effect_form.add_child(_effect_value_input)

	var add_effect_btn := Button.new()
	add_effect_btn.text = "Add Effect"
	add_effect_btn.pressed.connect(_on_add_effect_pressed)
	effect_form.add_child(add_effect_btn)

	_effect_list = ItemList.new()
	_effect_list.size_flags_horizontal = SIZE_EXPAND_FILL
	_effect_list.size_flags_vertical = SIZE_EXPAND_FILL
	_effect_list.custom_minimum_size.y = 150
	add_child(_effect_list)

	var effect_actions := HBoxContainer.new()
	add_child(effect_actions)

	var remove_effect_btn := Button.new()
	remove_effect_btn.text = "Remove Selected"
	remove_effect_btn.pressed.connect(_on_remove_selected_effect_pressed)
	effect_actions.add_child(remove_effect_btn)

	var clear_effect_btn := Button.new()
	clear_effect_btn.text = "Clear Effects"
	clear_effect_btn.pressed.connect(_on_clear_effects_pressed)
	effect_actions.add_child(clear_effect_btn)

	var actions := HBoxContainer.new()
	add_child(actions)

	var create_btn := Button.new()
	create_btn.text = "Create Item Resource"
	create_btn.pressed.connect(_on_create_pressed)
	actions.add_child(create_btn)

	var reset_btn := Button.new()
	reset_btn.text = "Reset"
	reset_btn.pressed.connect(_reset_form)
	actions.add_child(reset_btn)

	_result_label = Label.new()
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_result_label)


func _add_labeled_line_edit(parent: GridContainer, label_text: String, default_text: String) -> LineEdit:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)

	var input := LineEdit.new()
	input.text = default_text
	input.size_flags_horizontal = SIZE_EXPAND_FILL
	parent.add_child(input)
	return input


func _on_add_effect_pressed() -> void:
	var attr_name := _effect_attr_input.text.strip_edges()
	if attr_name.is_empty():
		_set_result("effect attr is empty", true)
		return

	var value_text := _effect_value_input.text.strip_edges()
	if not value_text.is_valid_float():
		_set_result("effect value is not a float", true)
		return

	var op := StringName(_effect_op_input.get_item_text(_effect_op_input.selected).to_lower())
	if not OPERATION_TYPES.has(op):
		_set_result("effect op is invalid", true)
		return

	_effect_rows.append({
		"op": op,
		"attr": StringName(attr_name),
		"value": float(value_text),
	})
	_refresh_effect_list()
	_effect_attr_input.clear()
	_effect_value_input.clear()
	_set_result("effect added", false)


func _on_remove_selected_effect_pressed() -> void:
	var selected := _effect_list.get_selected_items()
	if selected.is_empty():
		return

	var idx: int = int(selected[0])
	if idx < 0 or idx >= _effect_rows.size():
		return
	_effect_rows.remove_at(idx)
	_refresh_effect_list()
	_set_result("effect removed", false)


func _on_clear_effects_pressed() -> void:
	_effect_rows.clear()
	_refresh_effect_list()
	_set_result("effects cleared", false)


func _refresh_effect_list() -> void:
	_effect_list.clear()
	for row in _effect_rows:
		var op := String(row.get("op", ""))
		var attr := String(row.get("attr", ""))
		var value := float(row.get("value", 0.0))
		_effect_list.add_item("%s | %s | %s" % [op, attr, _format_float(value)])


func _on_create_pressed() -> void:
	var save_dir := _save_dir_input.text.strip_edges()
	var file_name := _file_name_input.text.strip_edges()
	var item_id_text := _item_id_input.text.strip_edges()
	var item_name := _item_name_input.text.strip_edges()
	var description := _description_input.text.strip_edges()
	var texture_path := _texture_path_input.text.strip_edges()
	var extra_tags_csv := _extra_tags_input.text.strip_edges()
	var max_stack_value := int(_max_stack_input.value)

	if save_dir.is_empty() or not save_dir.begins_with("res://"):
		_set_result("save_dir must start with res://", true)
		return
	if item_id_text.is_empty():
		_set_result("item_id is empty", true)
		return
	if item_name.is_empty():
		_set_result("item_name is empty", true)
		return
	if max_stack_value <= 0:
		_set_result("max_stack must be > 0", true)
		return

	if file_name.is_empty():
		file_name = item_id_text
	if not file_name.ends_with(".tres"):
		file_name += ".tres"

	var make_dir_err := DirAccess.make_dir_recursive_absolute(save_dir)
	if make_dir_err != OK and make_dir_err != ERR_ALREADY_EXISTS:
		_set_result("failed to create save_dir: %s" % save_dir, true)
		return

	var save_path := save_dir.path_join(file_name)
	if ResourceLoader.exists(save_path):
		_set_result("file already exists: %s" % save_path, true)
		return

	var item := ItemData.new()
	item.item_id = StringName(item_id_text)
	item.item_name = item_name
	item.description = description
	item.max_stack = max_stack_value
	item.tags = _build_tags(extra_tags_csv)

	if not texture_path.is_empty():
		var loaded_texture := load(texture_path)
		if not (loaded_texture is Texture2D):
			_set_result("texture_path is invalid texture: %s" % texture_path, true)
			return
		item.texture = loaded_texture as Texture2D

	var save_err := ResourceSaver.save(item, save_path)
	if save_err != OK:
		_set_result("failed to save resource (%d): %s" % [save_err, save_path], true)
		return

	if _editor_interface != null and _editor_interface.get_resource_filesystem() != null:
		_editor_interface.get_resource_filesystem().scan()
	_set_result("created: %s" % save_path, false)


func _build_tags(extra_tags_csv: String) -> Array[StringName]:
	var out: Array[StringName] = []
	var seen: Dictionary = {}

	for token in extra_tags_csv.split(",", false):
		var cleaned := token.strip_edges()
		if cleaned.is_empty():
			continue
		var tag := StringName(cleaned)
		if seen.has(tag):
			continue
		seen[tag] = true
		out.append(tag)

	for row in _effect_rows:
		var op := String(row.get("op", ""))
		var attr := String(row.get("attr", ""))
		var value := float(row.get("value", 0.0))
		var effect_tag := StringName("equip_effect:%s:%s:%s" % [op, attr, _format_float(value)])
		if seen.has(effect_tag):
			continue
		seen[effect_tag] = true
		out.append(effect_tag)

	return out


func _format_float(value: float) -> String:
	return String.num(value)


func _reset_form() -> void:
	if _save_dir_input == null:
		return
	_save_dir_input.text = DEFAULT_SAVE_DIR
	_file_name_input.text = ""
	_item_id_input.text = ""
	_item_name_input.text = ""
	_description_input.text = ""
	_texture_path_input.text = ""
	_extra_tags_input.text = ""
	_max_stack_input.value = 1
	_effect_rows.clear()
	_refresh_effect_list()
	_set_result("ready", false)


func _set_result(message: String, is_error: bool) -> void:
	if _result_label == null:
		return
	_result_label.text = message
	_result_label.modulate = Color(1.0, 0.45, 0.45, 1.0) if is_error else Color(0.65, 1.0, 0.7, 1.0)
