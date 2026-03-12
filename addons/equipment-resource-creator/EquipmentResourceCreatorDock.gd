@tool
extends VBoxContainer

const DEFAULT_ITEM_SAVE_DIR := "res://data/devtest/expedition_v2/items"
const DEFAULT_ACTOR_SAVE_DIR := "res://data/devtest/expedition_v2/actors"
const OPERATION_TYPES: Array[StringName] = [ &"add", &"sub", &"mult", &"div" ]

enum PathTarget {
	ITEM_SAVE_DIR,
	ACTOR_SAVE_DIR,
	ITEM_BROWSER_DIR,
	ACTOR_BROWSER_DIR,
}

var _editor_interface: EditorInterface
var _pending_path_target: PathTarget = PathTarget.ITEM_SAVE_DIR
var _effect_rows: Array[Dictionary] = []

@onready var _item_save_dir_input: LineEdit = %ItemSaveDirInput
@onready var _item_file_name_input: LineEdit = %ItemFileNameInput
@onready var _item_id_input: LineEdit = %ItemIdInput
@onready var _item_name_input: LineEdit = %ItemNameInput
@onready var _item_description_input: LineEdit = %ItemDescriptionInput
@onready var _item_max_stack_input: SpinBox = %ItemMaxStackInput
@onready var _item_texture_path_input: LineEdit = %ItemTexturePathInput
@onready var _item_extra_tags_input: LineEdit = %ItemExtraTagsInput

@onready var _effect_op_input: OptionButton = %EffectOpInput
@onready var _effect_attr_input: LineEdit = %EffectAttrInput
@onready var _effect_value_input: LineEdit = %EffectValueInput
@onready var _effect_list: ItemList = %EffectList

@onready var _item_browser_dir_input: LineEdit = %ItemBrowserDirInput
@onready var _item_resource_list: ItemList = %ItemResourceList
@onready var _item_resource_detail: TextEdit = %ItemResourceDetail

@onready var _actor_save_dir_input: LineEdit = %ActorSaveDirInput
@onready var _actor_file_name_input: LineEdit = %ActorFileNameInput
@onready var _actor_id_input: LineEdit = %ActorIdInput
@onready var _actor_display_name_input: LineEdit = %ActorDisplayNameInput
@onready var _actor_description_input: LineEdit = %ActorDescriptionInput
@onready var _actor_tags_input: LineEdit = %ActorTagsInput
@onready var _actor_strength_input: SpinBox = %ActorStrengthInput
@onready var _actor_constitution_input: SpinBox = %ActorConstitutionInput
@onready var _actor_dexterity_input: SpinBox = %ActorDexterityInput
@onready var _actor_perception_input: SpinBox = %ActorPerceptionInput
@onready var _actor_will_input: SpinBox = %ActorWillInput
@onready var _actor_intelligence_input: SpinBox = %ActorIntelligenceInput
@onready var _actor_luck_input: SpinBox = %ActorLuckInput
@onready var _actor_skill_ids_input: LineEdit = %ActorSkillIdsInput
@onready var _actor_passive_ids_input: LineEdit = %ActorPassiveIdsInput
@onready var _actor_ai_profile_input: LineEdit = %ActorAiProfileInput
@onready var _actor_capture_profile_input: LineEdit = %ActorCaptureProfileInput

@onready var _actor_browser_dir_input: LineEdit = %ActorBrowserDirInput
@onready var _actor_resource_list: ItemList = %ActorResourceList
@onready var _actor_resource_detail: TextEdit = %ActorResourceDetail

@onready var _dir_picker: EditorFileDialog = %DirPicker
@onready var _result_label: Label = %ResultLabel

var _item_browser_paths: Array[String] = []
var _actor_browser_paths: Array[String] = []


func setup(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface


func _ready() -> void:
	_bind_signals()
	_prepare_effect_options()
	_reset_item_form()
	_reset_actor_form()


func _bind_signals() -> void:
	%ItemSaveDirBrowseButton.pressed.connect(_open_dir_picker.bind(PathTarget.ITEM_SAVE_DIR))
	%ActorSaveDirBrowseButton.pressed.connect(_open_dir_picker.bind(PathTarget.ACTOR_SAVE_DIR))
	%ItemBrowserDirBrowseButton.pressed.connect(_open_dir_picker.bind(PathTarget.ITEM_BROWSER_DIR))
	%ActorBrowserDirBrowseButton.pressed.connect(_open_dir_picker.bind(PathTarget.ACTOR_BROWSER_DIR))
	%AddEffectButton.pressed.connect(_on_add_effect_pressed)
	%RemoveSelectedEffectButton.pressed.connect(_on_remove_selected_effect_pressed)
	%ClearEffectsButton.pressed.connect(_on_clear_effects_pressed)
	%CreateItemButton.pressed.connect(_on_create_item_pressed)
	%ResetItemButton.pressed.connect(_reset_item_form)
	%CreateActorButton.pressed.connect(_on_create_actor_pressed)
	%ResetActorButton.pressed.connect(_reset_actor_form)
	%RefreshItemBrowserButton.pressed.connect(_refresh_item_browser)
	%RefreshActorBrowserButton.pressed.connect(_refresh_actor_browser)
	_item_resource_list.item_selected.connect(_on_item_resource_selected)
	_actor_resource_list.item_selected.connect(_on_actor_resource_selected)
	_dir_picker.dir_selected.connect(_on_dir_selected)


func _prepare_effect_options() -> void:
	if _effect_op_input.item_count > 0:
		return
	for op in OPERATION_TYPES:
		_effect_op_input.add_item(String(op))


func _open_dir_picker(target: PathTarget) -> void:
	_pending_path_target = target
	_dir_picker.popup_centered_ratio(0.7)


func _on_dir_selected(path: String) -> void:
	var localized := _to_res_path(path)
	if localized.is_empty():
		_set_result("selected path is outside project: %s" % path, true)
		return
	match _pending_path_target:
		PathTarget.ITEM_SAVE_DIR:
			_item_save_dir_input.text = localized
		PathTarget.ACTOR_SAVE_DIR:
			_actor_save_dir_input.text = localized
		PathTarget.ITEM_BROWSER_DIR:
			_item_browser_dir_input.text = localized
			_refresh_item_browser()
		PathTarget.ACTOR_BROWSER_DIR:
			_actor_browser_dir_input.text = localized
			_refresh_actor_browser()


func _to_res_path(path: String) -> String:
	var trimmed := path.strip_edges()
	if trimmed.begins_with("res://"):
		return trimmed
	var localized := ProjectSettings.localize_path(trimmed)
	if localized.begins_with("res://"):
		return localized
	return ""


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


func _on_create_item_pressed() -> void:
	var save_dir := _item_save_dir_input.text.strip_edges()
	var file_name := _item_file_name_input.text.strip_edges()
	var item_id_text := _item_id_input.text.strip_edges()
	var item_name := _item_name_input.text.strip_edges()
	var description := _item_description_input.text.strip_edges()
	var texture_path := _item_texture_path_input.text.strip_edges()
	var extra_tags_csv := _item_extra_tags_input.text.strip_edges()
	var max_stack_value := int(_item_max_stack_input.value)

	if save_dir.is_empty() or not save_dir.begins_with("res://"):
		_set_result("item save_dir must start with res://", true)
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

	if not _ensure_directory(save_dir):
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
		_set_result("failed to save item (%d): %s" % [save_err, save_path], true)
		return

	_refresh_filesystem()
	_refresh_item_browser()
	_set_result("item created: %s" % save_path, false)


func _on_create_actor_pressed() -> void:
	var save_dir := _actor_save_dir_input.text.strip_edges()
	var file_name := _actor_file_name_input.text.strip_edges()
	var actor_id_text := _actor_id_input.text.strip_edges()
	var display_name := _actor_display_name_input.text.strip_edges()
	var description := _actor_description_input.text.strip_edges()

	if save_dir.is_empty() or not save_dir.begins_with("res://"):
		_set_result("actor save_dir must start with res://", true)
		return
	if actor_id_text.is_empty():
		_set_result("actor_id is empty", true)
		return
	if display_name.is_empty():
		_set_result("display_name is empty", true)
		return

	if file_name.is_empty():
		file_name = actor_id_text
	if not file_name.ends_with(".tres"):
		file_name += ".tres"

	if not _ensure_directory(save_dir):
		return
	var save_path := save_dir.path_join(file_name)
	if ResourceLoader.exists(save_path):
		_set_result("file already exists: %s" % save_path, true)
		return

	var actor := ActorDefinition.new()
	actor.actor_id = StringName(actor_id_text)
	actor.display_name = display_name
	actor.description = description
	actor.tags = _parse_csv_to_string_name_array(_actor_tags_input.text)
	actor.strength = float(_actor_strength_input.value)
	actor.constitution = float(_actor_constitution_input.value)
	actor.dexterity = float(_actor_dexterity_input.value)
	actor.perception = float(_actor_perception_input.value)
	actor.will = float(_actor_will_input.value)
	actor.intelligence = float(_actor_intelligence_input.value)
	actor.luck = float(_actor_luck_input.value)
	actor.skill_ids = _parse_csv_to_string_name_array(_actor_skill_ids_input.text)
	actor.passive_ids = _parse_csv_to_string_name_array(_actor_passive_ids_input.text)
	actor.ai_profile_id = StringName(_actor_ai_profile_input.text.strip_edges())
	actor.capture_profile_id = StringName(_actor_capture_profile_input.text.strip_edges())

	var save_err := ResourceSaver.save(actor, save_path)
	if save_err != OK:
		_set_result("failed to save actor (%d): %s" % [save_err, save_path], true)
		return

	_refresh_filesystem()
	_refresh_actor_browser()
	_set_result("actor created: %s" % save_path, false)


func _refresh_item_browser() -> void:
	_item_resource_list.clear()
	_item_browser_paths.clear()
	_item_resource_detail.text = ""

	var dir_path := _item_browser_dir_input.text.strip_edges()
	if dir_path.is_empty() or not dir_path.begins_with("res://"):
		return

	for path in _collect_resource_files(dir_path):
		var res := load(path)
		if not (res is ItemData):
			continue
		var item := res as ItemData
		_item_browser_paths.append(path)
		_item_resource_list.add_item("%s (%s)" % [path.get_file(), String(item.item_id)])


func _refresh_actor_browser() -> void:
	_actor_resource_list.clear()
	_actor_browser_paths.clear()
	_actor_resource_detail.text = ""

	var dir_path := _actor_browser_dir_input.text.strip_edges()
	if dir_path.is_empty() or not dir_path.begins_with("res://"):
		return

	for path in _collect_resource_files(dir_path):
		var res := load(path)
		if not (res is ActorDefinition):
			continue
		var actor := res as ActorDefinition
		_actor_browser_paths.append(path)
		_actor_resource_list.add_item("%s (%s)" % [path.get_file(), String(actor.actor_id)])


func _on_item_resource_selected(index: int) -> void:
	if index < 0 or index >= _item_browser_paths.size():
		return
	var path := _item_browser_paths[index]
	var res := load(path)
	if not (res is ItemData):
		_item_resource_detail.text = "invalid item resource: %s" % path
		return
	var item := res as ItemData
	var lines: PackedStringArray = []
	lines.append("path: %s" % path)
	lines.append("item_id: %s" % String(item.item_id))
	lines.append("item_name: %s" % item.item_name)
	lines.append("description: %s" % item.description)
	lines.append("max_stack: %d" % item.max_stack)
	lines.append("tags: %s" % _join_string_names(item.tags))
	lines.append("texture: %s" % (item.texture.resource_path if item.texture != null else ""))
	_item_resource_detail.text = "\n".join(lines)


func _on_actor_resource_selected(index: int) -> void:
	if index < 0 or index >= _actor_browser_paths.size():
		return
	var path := _actor_browser_paths[index]
	var res := load(path)
	if not (res is ActorDefinition):
		_actor_resource_detail.text = "invalid actor resource: %s" % path
		return
	var actor := res as ActorDefinition
	var lines: PackedStringArray = []
	lines.append("path: %s" % path)
	lines.append("actor_id: %s" % String(actor.actor_id))
	lines.append("display_name: %s" % actor.display_name)
	lines.append("description: %s" % actor.description)
	lines.append("tags: %s" % _join_string_names(actor.tags))
	lines.append("strength: %s" % _format_float(actor.strength))
	lines.append("constitution: %s" % _format_float(actor.constitution))
	lines.append("dexterity: %s" % _format_float(actor.dexterity))
	lines.append("perception: %s" % _format_float(actor.perception))
	lines.append("will: %s" % _format_float(actor.will))
	lines.append("intelligence: %s" % _format_float(actor.intelligence))
	lines.append("luck: %s" % _format_float(actor.luck))
	lines.append("skill_ids: %s" % _join_string_names(actor.skill_ids))
	lines.append("passive_ids: %s" % _join_string_names(actor.passive_ids))
	lines.append("ai_profile_id: %s" % String(actor.ai_profile_id))
	lines.append("capture_profile_id: %s" % String(actor.capture_profile_id))
	_actor_resource_detail.text = "\n".join(lines)


func _collect_resource_files(root_dir: String) -> Array[String]:
	var out: Array[String] = []
	_collect_resource_files_recursive(root_dir, out)
	out.sort()
	return out


func _collect_resource_files_recursive(current_dir: String, out: Array[String]) -> void:
	var dir := DirAccess.open(current_dir)
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name.is_empty():
			break
		if name.begins_with("."):
			continue

		var path := current_dir.path_join(name)
		if dir.current_is_dir():
			_collect_resource_files_recursive(path, out)
		elif name.ends_with(".tres") or name.ends_with(".res"):
			out.append(path)
	dir.list_dir_end()


func _ensure_directory(res_dir: String) -> bool:
	var make_dir_err := DirAccess.make_dir_recursive_absolute(res_dir)
	if make_dir_err != OK and make_dir_err != ERR_ALREADY_EXISTS:
		_set_result("failed to create dir: %s" % res_dir, true)
		return false
	return true


func _refresh_filesystem() -> void:
	if _editor_interface != null and _editor_interface.get_resource_filesystem() != null:
		_editor_interface.get_resource_filesystem().scan()


func _build_tags(extra_tags_csv: String) -> Array[StringName]:
	var out := _parse_csv_to_string_name_array(extra_tags_csv)
	var seen: Dictionary = {}
	for tag in out:
		seen[tag] = true
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


func _parse_csv_to_string_name_array(csv_text: String) -> Array[StringName]:
	var out: Array[StringName] = []
	var seen: Dictionary = {}
	for token in csv_text.split(",", false):
		var cleaned := token.strip_edges()
		if cleaned.is_empty():
			continue
		var key := StringName(cleaned)
		if seen.has(key):
			continue
		seen[key] = true
		out.append(key)
	return out


func _join_string_names(values: Array[StringName]) -> String:
	if values.is_empty():
		return ""
	var out: PackedStringArray = []
	for v in values:
		out.append(String(v))
	return ",".join(out)


func _format_float(value: float) -> String:
	return String.num(value)


func _reset_item_form() -> void:
	_item_save_dir_input.text = DEFAULT_ITEM_SAVE_DIR
	_item_file_name_input.text = ""
	_item_id_input.text = ""
	_item_name_input.text = ""
	_item_description_input.text = ""
	_item_texture_path_input.text = ""
	_item_extra_tags_input.text = ""
	_item_max_stack_input.value = 1
	_effect_rows.clear()
	_refresh_effect_list()
	_item_browser_dir_input.text = DEFAULT_ITEM_SAVE_DIR
	_refresh_item_browser()
	_set_result("item form ready", false)


func _reset_actor_form() -> void:
	_actor_save_dir_input.text = DEFAULT_ACTOR_SAVE_DIR
	_actor_file_name_input.text = ""
	_actor_id_input.text = ""
	_actor_display_name_input.text = ""
	_actor_description_input.text = ""
	_actor_tags_input.text = ""
	_actor_strength_input.value = 0.0
	_actor_constitution_input.value = 0.0
	_actor_dexterity_input.value = 0.0
	_actor_perception_input.value = 0.0
	_actor_will_input.value = 0.0
	_actor_intelligence_input.value = 0.0
	_actor_luck_input.value = 0.0
	_actor_skill_ids_input.text = ""
	_actor_passive_ids_input.text = ""
	_actor_ai_profile_input.text = ""
	_actor_capture_profile_input.text = ""
	_actor_browser_dir_input.text = DEFAULT_ACTOR_SAVE_DIR
	_refresh_actor_browser()
	_set_result("actor form ready", false)


func _set_result(message: String, is_error: bool) -> void:
	_result_label.text = message
	_result_label.modulate = Color(1.0, 0.45, 0.45, 1.0) if is_error else Color(0.65, 1.0, 0.7, 1.0)
