extends TestPanelBase
class_name SquadConfigTestPanel

const ActorTemplateRef = preload("res://src/expedition_system/squad/ActorTemplate.gd")
const SquadConfigRef = preload("res://src/expedition_system/squad/SquadConfig.gd")
const MemberConfigRef = preload("res://src/expedition_system/squad/MemberConfig.gd")
const SquadRuntimeFactoryRef = preload("res://src/expedition_system/squad/SquadRuntimeFactory.gd")

const SLOT_COUNT := 3
const EQUIP_OPTIONS := [
	{"label": "None", "id": &""},
	{"label": "Iron Sword", "id": &"iron_sword"},
	{"label": "Wood Shield", "id": &"wood_shield"},
	{"label": "Hunter Bow", "id": &"hunter_bow"},
]

var _templates: Array[ActorTemplate] = []
var _rows: Array[Dictionary] = []

var _squad_id_edit: LineEdit
var _result_view: RichTextLabel
var _status_label: Label
var _last_config: SquadConfig


func panel_title() -> String:
	return "Squad Config Test"


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	_build_demo_templates()
	_build_ui()


func on_panel_activated() -> void:
	_log_templates()
	log_line("SquadConfigTestPanel ready. Configure slots and build SquadRuntime.")


func _build_demo_templates() -> void:
	_templates.clear()
	_templates.append(_make_template(&"warrior", 140.0, [&"slash"], [&"tough_skin"], &"basic_auto"))
	_templates.append(_make_template(&"medic", 90.0, [&"heal"], [&"triage"], &"basic_auto"))
	_templates.append(_make_template(&"hunter", 100.0, [&"shoot"], [&"focus"], &"basic_auto"))


func _make_template(template_id: StringName, max_hp: float, action_ids: Array[StringName], passive_ids: Array[StringName], ai_id: StringName) -> ActorTemplate:
	var t := ActorTemplateRef.new()
	t.template_id = template_id
	t.max_hp = max_hp
	t.action_ids = action_ids
	t.passive_ids = passive_ids
	t.ai_id = ai_id
	return t


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()
	_rows.clear()

	var title := Label.new()
	title.text = "Squad Configuration (MVP)"
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)

	var tips := Label.new()
	tips.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tips.text = "Player config only selects role(template) and equipment. Actions/passives/AI are loaded from ActorTemplate."
	add_child(tips)

	var header_row := HBoxContainer.new()
	header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(header_row)

	var squad_label := Label.new()
	squad_label.text = "Squad ID"
	header_row.add_child(squad_label)

	_squad_id_edit = LineEdit.new()
	_squad_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_squad_id_edit.placeholder_text = "test_squad"
	_squad_id_edit.text = "test_squad"
	header_row.add_child(_squad_id_edit)

	var rows_frame := PanelContainer.new()
	rows_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(rows_frame)

	var rows_vbox := VBoxContainer.new()
	rows_vbox.add_theme_constant_override("separation", 6)
	rows_frame.add_child(rows_vbox)

	for slot_index in SLOT_COUNT:
		var row := _create_slot_row(slot_index)
		_rows.append(row)
		rows_vbox.add_child(row.get("root"))

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	add_child(button_row)

	_add_button(button_row, "Build Config", _on_build_config_pressed)
	_add_button(button_row, "Build Runtime", _on_build_runtime_pressed)
	_add_button(button_row, "Reset Demo", _on_reset_pressed)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.text = "Ready"
	add_child(_status_label)

	var result_frame := PanelContainer.new()
	result_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(result_frame)

	_result_view = RichTextLabel.new()
	_result_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_result_view.custom_minimum_size = Vector2(0, 220)
	_result_view.selection_enabled = true
	result_frame.add_child(_result_view)

	_result_view.clear()
	_result_view.append_text("Result output will appear here.\n")


func _create_slot_row(slot_index: int) -> Dictionary:
	var row: Dictionary = {}
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var enabled := CheckBox.new()
	enabled.text = "Slot %d" % (slot_index + 1)
	enabled.button_pressed = slot_index < 2
	root.add_child(enabled)

	var member_id_edit := LineEdit.new()
	member_id_edit.custom_minimum_size = Vector2(110, 0)
	member_id_edit.placeholder_text = "member_id"
	member_id_edit.text = "m_%d" % (slot_index + 1)
	root.add_child(member_id_edit)

	var template_box := OptionButton.new()
	template_box.custom_minimum_size = Vector2(130, 0)
	_fill_template_options(template_box)
	root.add_child(template_box)

	var equip_box := OptionButton.new()
	equip_box.custom_minimum_size = Vector2(130, 0)
	_fill_equipment_options(equip_box)
	root.add_child(equip_box)

	var init_hp := SpinBox.new()
	init_hp.custom_minimum_size = Vector2(90, 0)
	init_hp.min_value = -1.0
	init_hp.max_value = 9999.0
	init_hp.step = 1.0
	init_hp.value = -1.0
	init_hp.prefix = "HP "
	root.add_child(init_hp)

	row["root"] = root
	row["enabled"] = enabled
	row["member_id"] = member_id_edit
	row["template"] = template_box
	row["equip"] = equip_box
	row["init_hp"] = init_hp
	return row


func _fill_template_options(box: OptionButton) -> void:
	box.clear()
	for t in _templates:
		box.add_item(String(t.template_id))


func _fill_equipment_options(box: OptionButton) -> void:
	box.clear()
	for option in EQUIP_OPTIONS:
		box.add_item(str(option["label"]))


func _add_button(parent: HBoxContainer, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)


func _on_build_config_pressed() -> void:
	var config := _build_config_from_ui()
	_last_config = config
	if config == null:
		return

	_status_label.text = "Built SquadConfig with %d members" % config.members.size()
	_show_config(config)
	log_line("Built SquadConfig: %s (%d members)" % [String(config.squad_id), config.members.size()])


func _on_build_runtime_pressed() -> void:
	var config := _last_config
	if config == null:
		config = _build_config_from_ui()
		_last_config = config
	if config == null:
		return

	var runtime = SquadRuntimeFactoryRef.from_config(config)
	if runtime == null:
		_status_label.text = "Build SquadRuntime failed"
		_append_result("Build SquadRuntime failed.\n")
		log_line("Build SquadRuntime failed.")
		return

	_status_label.text = "Built SquadRuntime with %d members" % runtime.members.size()
	_show_runtime(config, runtime)
	log_line("Built SquadRuntime: %s (%d members)" % [String(runtime.source_squad_id), runtime.members.size()])


func _on_reset_pressed() -> void:
	_build_demo_templates()
	_build_ui()
	_last_config = null
	_status_label.text = "Reset demo UI"
	log_line("SquadConfigTestPanel reset.")


func _build_config_from_ui() -> SquadConfig:
	var squad := SquadConfigRef.new()
	var squad_text := _squad_id_edit.text.strip_edges()
	squad.squad_id = StringName(squad_text if not squad_text.is_empty() else "test_squad")
	squad.members = []

	for i in range(_rows.size()):
		var row: Dictionary = _rows[i]
		var enabled: CheckBox = row["enabled"]
		if not enabled.button_pressed:
			continue

		var template: ActorTemplate = _get_selected_template(row["template"])
		if template == null:
			log_line("Slot %d skipped: no template selected." % (i + 1))
			continue

		var member := MemberConfigRef.new()
		var member_id_text := (row["member_id"] as LineEdit).text.strip_edges()
		member.member_id = StringName(member_id_text if not member_id_text.is_empty() else "m_%d" % (i + 1))
		member.actor_template = template
		member.actor_template_id = template.template_id
		member.equipment_ids = _get_selected_equipment_ids(row["equip"])
		member.init_hp = float((row["init_hp"] as SpinBox).value)
		squad.members.append(member)

	if squad.members.is_empty():
		_status_label.text = "No enabled members."
		_result_view.clear()
		_result_view.append_text("No enabled members. Enable at least one slot.\n")
		log_line("Build SquadConfig skipped: no enabled members.")
		return null

	return squad


func _get_selected_template(box: OptionButton) -> ActorTemplate:
	var idx := box.selected
	if idx < 0 or idx >= _templates.size():
		return null
	return _templates[idx]


func _get_selected_equipment_ids(box: OptionButton) -> Array[StringName]:
	var idx := box.selected
	if idx < 0 or idx >= EQUIP_OPTIONS.size():
		return []

	var equip_id: StringName = EQUIP_OPTIONS[idx]["id"]
	if equip_id.is_empty():
		return []
	return [equip_id]


func _show_config(config: SquadConfig) -> void:
	_result_view.clear()
	_append_result("=== SquadConfig ===\n")
	_append_result("squad_id: %s\n" % String(config.squad_id))
	_append_result("members: %d\n" % config.members.size())

	for i in range(config.members.size()):
		var m = config.members[i] as MemberConfig
		var equip_text := _join_string_names(m.equipment_ids)
		_append_result("- [%d] member_id=%s template=%s equip=[%s] init_hp=%s\n" % [
			i,
			String(m.member_id),
			String(m.actor_template_id),
			equip_text,
			str(m.init_hp)
		])


func _show_runtime(config: SquadConfig, runtime) -> void:
	_show_config(config)
	_append_result("\n=== SquadRuntime ===\n")
	_append_result("source_squad_id: %s\n" % String(runtime.source_squad_id))
	_append_result("members: %d\n" % runtime.members.size())

	for i in range(runtime.members.size()):
		var m = runtime.members[i]
		_append_result("- [%d] member_id=%s template=%s hp=%s/%s alive=%s\n" % [
			i,
			String(m.member_id),
			String(m.actor_template_id),
			str(m.current_hp),
			str(m.max_hp),
			str(m.alive)
		])
		_append_result("    actions=[%s] passives=[%s] ai=%s equip=[%s]\n" % [
			_join_string_names(m.action_ids),
			_join_string_names(m.passive_ids),
			String(m.ai_id),
			_join_string_names(m.equipment_ids)
		])


func _append_result(text: String) -> void:
	_result_view.append_text(text)


func _join_string_names(items: Array[StringName]) -> String:
	var parts: Array[String] = []
	for item in items:
		parts.append(String(item))
	return ", ".join(parts)


func _log_templates() -> void:
	var names: Array[String] = []
	for t in _templates:
		names.append(String(t.template_id))
	log_line("Loaded demo ActorTemplate set: [%s]" % ", ".join(names))
