extends TestPanelBase
class_name SquadConfigTestPanel

const ActorTemplateRef = preload("res://src/expedition_system/squad/ActorTemplate.gd")
const SquadConfigRef = preload("res://src/expedition_system/squad/SquadConfig.gd")
const MemberConfigRef = preload("res://src/expedition_system/squad/MemberConfig.gd")
const SquadRuntimeFactoryRef = preload("res://src/expedition_system/squad/SquadRuntimeFactory.gd")

const CTX_SQUAD_CONFIG: StringName = &"expedition.squad_config"
const CTX_SQUAD_RUNTIME: StringName = &"expedition.squad_runtime"

const EQUIP_OPTIONS := [
	{"label": "None", "id": &""},
	{"label": "Iron Sword", "id": &"iron_sword"},
	{"label": "Wood Shield", "id": &"wood_shield"},
	{"label": "Hunter Bow", "id": &"hunter_bow"},
]

@onready var squad_id_edit: LineEdit = $HeaderRow/SquadIdEdit
@onready var build_config_button: Button = $ButtonRow/BuildConfigButton
@onready var build_runtime_button: Button = $ButtonRow/BuildRuntimeButton
@onready var reset_button: Button = $ButtonRow/ResetButton
@onready var status_label: Label = $StatusLabel
@onready var result_view: RichTextLabel = $ResultFrame/ResultView

@onready var slot1_enabled: CheckBox = $RowsFrame/RowsVBox/Slot1Row/Slot1Enabled
@onready var slot1_member_id: LineEdit = $RowsFrame/RowsVBox/Slot1Row/Slot1MemberIdEdit
@onready var slot1_template: OptionButton = $RowsFrame/RowsVBox/Slot1Row/Slot1TemplateBox
@onready var slot1_equip: OptionButton = $RowsFrame/RowsVBox/Slot1Row/Slot1EquipBox
@onready var slot1_init_hp: SpinBox = $RowsFrame/RowsVBox/Slot1Row/Slot1InitHpSpin

@onready var slot2_enabled: CheckBox = $RowsFrame/RowsVBox/Slot2Row/Slot2Enabled
@onready var slot2_member_id: LineEdit = $RowsFrame/RowsVBox/Slot2Row/Slot2MemberIdEdit
@onready var slot2_template: OptionButton = $RowsFrame/RowsVBox/Slot2Row/Slot2TemplateBox
@onready var slot2_equip: OptionButton = $RowsFrame/RowsVBox/Slot2Row/Slot2EquipBox
@onready var slot2_init_hp: SpinBox = $RowsFrame/RowsVBox/Slot2Row/Slot2InitHpSpin

@onready var slot3_enabled: CheckBox = $RowsFrame/RowsVBox/Slot3Row/Slot3Enabled
@onready var slot3_member_id: LineEdit = $RowsFrame/RowsVBox/Slot3Row/Slot3MemberIdEdit
@onready var slot3_template: OptionButton = $RowsFrame/RowsVBox/Slot3Row/Slot3TemplateBox
@onready var slot3_equip: OptionButton = $RowsFrame/RowsVBox/Slot3Row/Slot3EquipBox
@onready var slot3_init_hp: SpinBox = $RowsFrame/RowsVBox/Slot3Row/Slot3InitHpSpin

var _templates: Array[ActorTemplate] = []
var _rows: Array[Dictionary] = []
var _last_config: SquadConfig


func panel_title() -> String:
	return "Squad Config Test"


func _ready() -> void:
	_cache_rows()
	_bind_buttons()
	_build_demo_templates()
	_reset_ui_to_defaults()
	_refresh_all_option_boxes()
	_clear_result("Result output will appear here.\n")


func on_panel_activated() -> void:
	_log_templates()
	log_line("SquadConfigTestPanel ready. Configure slots and build SquadRuntime.")


func _cache_rows() -> void:
	_rows = [
		{
			"enabled": slot1_enabled,
			"member_id": slot1_member_id,
			"template": slot1_template,
			"equip": slot1_equip,
			"init_hp": slot1_init_hp,
			"default_enabled": true,
			"default_member_id": "m_1",
			"default_template_idx": 0,
			"default_equip_idx": 0,
		},
		{
			"enabled": slot2_enabled,
			"member_id": slot2_member_id,
			"template": slot2_template,
			"equip": slot2_equip,
			"init_hp": slot2_init_hp,
			"default_enabled": true,
			"default_member_id": "m_2",
			"default_template_idx": 1,
			"default_equip_idx": 0,
		},
		{
			"enabled": slot3_enabled,
			"member_id": slot3_member_id,
			"template": slot3_template,
			"equip": slot3_equip,
			"init_hp": slot3_init_hp,
			"default_enabled": false,
			"default_member_id": "m_3",
			"default_template_idx": 2,
			"default_equip_idx": 0,
		},
	]


func _bind_buttons() -> void:
	if not build_config_button.pressed.is_connected(_on_build_config_pressed):
		build_config_button.pressed.connect(_on_build_config_pressed)
	if not build_runtime_button.pressed.is_connected(_on_build_runtime_pressed):
		build_runtime_button.pressed.connect(_on_build_runtime_pressed)
	if not reset_button.pressed.is_connected(_on_reset_pressed):
		reset_button.pressed.connect(_on_reset_pressed)


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


func _reset_ui_to_defaults() -> void:
	_last_config = null
	squad_id_edit.text = "test_squad"
	status_label.text = "Ready"

	for row in _rows:
		(row["enabled"] as CheckBox).button_pressed = bool(row["default_enabled"])
		(row["member_id"] as LineEdit).text = str(row["default_member_id"])
		(row["init_hp"] as SpinBox).value = -1.0


func _refresh_all_option_boxes() -> void:
	for row in _rows:
		_fill_template_options(row["template"] as OptionButton)
		_fill_equipment_options(row["equip"] as OptionButton)

	for row in _rows:
		var template_box := row["template"] as OptionButton
		var equip_box := row["equip"] as OptionButton
		template_box.select(_clamp_index(int(row["default_template_idx"]), template_box.get_item_count()))
		equip_box.select(_clamp_index(int(row["default_equip_idx"]), equip_box.get_item_count()))


func _fill_template_options(box: OptionButton) -> void:
	box.clear()
	for t in _templates:
		box.add_item(String(t.template_id))


func _fill_equipment_options(box: OptionButton) -> void:
	box.clear()
	for option in EQUIP_OPTIONS:
		box.add_item(str(option["label"]))


func _clamp_index(idx: int, count: int) -> int:
	if count <= 0:
		return -1
	return clampi(idx, 0, count - 1)


func _on_build_config_pressed() -> void:
	var config := _build_config_from_ui()
	_last_config = config
	if config == null:
		return

	status_label.text = "Built SquadConfig with %d members" % config.members.size()
	_show_config(config)
	_publish_config_to_context(config)
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
		status_label.text = "Build SquadRuntime failed"
		ctx_erase(CTX_SQUAD_RUNTIME)
		_append_result("Build SquadRuntime failed.\n")
		log_line("Build SquadRuntime failed.")
		return

	status_label.text = "Built SquadRuntime with %d members" % runtime.members.size()
	_show_runtime(config, runtime)
	_publish_runtime_to_context(runtime)
	log_line("Built SquadRuntime: %s (%d members)" % [String(runtime.source_squad_id), runtime.members.size()])


func _on_reset_pressed() -> void:
	_build_demo_templates()
	_reset_ui_to_defaults()
	_refresh_all_option_boxes()
	ctx_erase(CTX_SQUAD_CONFIG)
	ctx_erase(CTX_SQUAD_RUNTIME)
	_clear_result("Result output will appear here.\n")
	log_line("SquadConfigTestPanel reset.")


func _build_config_from_ui() -> SquadConfig:
	var squad := SquadConfigRef.new()
	var squad_text := squad_id_edit.text.strip_edges()
	squad.squad_id = StringName(squad_text if not squad_text.is_empty() else "test_squad")
	squad.members = []

	for i in range(_rows.size()):
		var row: Dictionary = _rows[i]
		var enabled: CheckBox = row["enabled"]
		if not enabled.button_pressed:
			continue

		var template: ActorTemplate = _get_selected_template(row["template"] as OptionButton)
		if template == null:
			log_line("Slot %d skipped: no template selected." % (i + 1))
			continue

		var member := MemberConfigRef.new()
		var member_id_text := (row["member_id"] as LineEdit).text.strip_edges()
		member.member_id = StringName(member_id_text if not member_id_text.is_empty() else "m_%d" % (i + 1))
		member.actor_template = template
		member.actor_template_id = template.template_id
		member.equipment_ids = _get_selected_equipment_ids(row["equip"] as OptionButton)
		member.init_hp = float((row["init_hp"] as SpinBox).value)
		squad.members.append(member)

	if squad.members.is_empty():
		status_label.text = "No enabled members."
		_clear_result("No enabled members. Enable at least one slot.\n")
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
	_clear_result("")
	_append_result("=== SquadConfig ===\n")
	_append_result("squad_id: %s\n" % String(config.squad_id))
	_append_result("members: %d\n" % config.members.size())

	for i in range(config.members.size()):
		var m := config.members[i] as MemberConfig
		var equip_text := _join_string_names(m.equipment_ids)
		_append_result("- [%d] member_id=%s template=%s equip=[%s] init_hp=%s\n" % [
			i,
			String(m.member_id),
			String(m.actor_template_id),
			equip_text,
			str(m.init_hp)
		])


func _show_runtime(config: SquadConfig, runtime: SquadRuntime) -> void:
	_show_config(config)
	_append_result("\n=== SquadRuntime ===\n")
	_append_result("source_squad_id: %s\n" % String(runtime.source_squad_id))
	_append_result("members: %d\n" % runtime.members.size())

	for i in range(runtime.members.size()):
		var m := runtime.members[i] as MemberRuntime
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


func _clear_result(initial_text: String) -> void:
	result_view.clear()
	if not initial_text.is_empty():
		result_view.append_text(initial_text)


func _append_result(text: String) -> void:
	result_view.append_text(text)


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


func _publish_config_to_context(config: SquadConfig) -> void:
	if config == null:
		ctx_erase(CTX_SQUAD_CONFIG)
		return
	ctx_set(CTX_SQUAD_CONFIG, config.duplicate(true))
	ctx_erase(CTX_SQUAD_RUNTIME)
	log_line("Published SquadConfig to TestHub context.")


func _publish_runtime_to_context(runtime: SquadRuntime) -> void:
	if runtime == null:
		ctx_erase(CTX_SQUAD_RUNTIME)
		return
	ctx_set(CTX_SQUAD_RUNTIME, runtime.duplicate(true))
	log_line("Published SquadRuntime to TestHub context.")
