extends TestPanelBase
class_name SquadConfigTestPanel

const ActorTemplateRef = preload("res://src/expedition_system/actor/ActorTemplate.gd")
const AttributeSetRef = preload("res://src/attribute_framework/AttributeSet.gd")
const AttributeRef = preload("res://src/attribute_framework/Attribute.gd")
const InventoryComponentRef = preload("res://src/inventory/InventoryComponent.gd")
const InventorySessionRef = preload("res://src/inventory/InventorySession.gd")
const ItemContainerRef = preload("res://src/inventory/ItemContainer.gd")
const ItemDataRef = preload("res://src/inventory/ItemData.gd")
const ItemDataResolverRef = preload("res://src/inventory/ItemDataResolver.gd")
const CursorWithItemScene = preload("res://src/cursor/cursor_with_item.tscn")
const SquadConfigRef = preload("res://src/expedition_system/squad/SquadConfig.gd")
const MemberConfigRef = preload("res://src/expedition_system/squad/MemberConfig.gd")
const SquadRuntimeFactoryRef = preload("res://src/expedition_system/squad/SquadRuntimeFactory.gd")
const DevInventorySlotScene = preload("res://scenes/devtest/panels/DevInventorySlot.tscn")

const CTX_SQUAD_CONFIG: StringName = &"expedition.squad_config"
const CTX_SQUAD_RUNTIME: StringName = &"expedition.squad_runtime"
const DEVTEST_ACTOR_TEMPLATE_PATHS: Array[String] = [
	"res://data/devtest/expedition/actors/observer.tres",
	"res://data/devtest/expedition/actors/robot.tres",
]

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
@onready var equip_target_row_box: OptionButton = $EquipDragFrame/EquipDragVBox/EquipTargetRow/EquipTargetRowBox
@onready var fill_warehouse_button: Button = $EquipDragFrame/EquipDragVBox/EquipTargetRow/FillWarehouseButton
@onready var clear_target_equip_button: Button = $EquipDragFrame/EquipDragVBox/EquipTargetRow/ClearTargetEquipButton
@onready var warehouse_grid: GridContainer = $EquipDragFrame/EquipDragVBox/EquipGridsRow/WarehousePanel/WarehouseVBox/WarehouseGrid
@onready var member_equip_grid: GridContainer = $EquipDragFrame/EquipDragVBox/EquipGridsRow/MemberEquipPanel/MemberEquipVBox/MemberEquipGrid
@onready var member_equip_label: Label = $EquipDragFrame/EquipDragVBox/EquipGridsRow/MemberEquipPanel/MemberEquipVBox/MemberEquipLabel
@onready var cursor_state_label: Label = $EquipDragFrame/EquipDragVBox/CursorStateLabel

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
var _equip_session: InventorySession
var _warehouse_comp: InventoryComponent
var _member_equip_comps: Array = [] # InventoryComponent[]
var _placeholder_item_cache: Dictionary = {} # item_id(String) -> ItemData
var _equip_cursor_ui = null


func panel_title() -> String:
	return "Squad Config Test"


func _ready() -> void:
	_cache_rows()
	_bind_buttons()
	_build_demo_templates()
	_init_equip_drag_test()
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


func _init_equip_drag_test() -> void:
	_equip_session = InventorySessionRef.new()
	_warehouse_comp = _make_inventory_component(12, "squad_config_test_warehouse")
	_member_equip_comps.clear()
	for i in range(_rows.size()):
		_member_equip_comps.append(_make_inventory_component(6, "squad_config_member_equip_%d" % i))

	equip_target_row_box.clear()
	for i in range(_rows.size()):
		equip_target_row_box.add_item("Row %d / Slot %d" % [i + 1, i + 1])
	if equip_target_row_box.item_count > 0:
		equip_target_row_box.select(0)

	_rebuild_inventory_grid(warehouse_grid, _warehouse_comp)
	_rebuild_inventory_grid(member_equip_grid, _get_selected_member_equip_comp())
	_ensure_equip_cursor_ui()
	_refresh_equip_drag_panel()


func _make_inventory_component(slot_count: int, container_id: String) -> InventoryComponent:
	var comp := InventoryComponentRef.new()
	comp.save_enabled = false
	comp.name = "TempInventory_%s" % container_id
	var tmpl := ItemContainerRef.new()
	tmpl.item_container_id = StringName(container_id)
	tmpl.slot_count = slot_count
	comp.container_template = tmpl
	add_child(comp)
	comp.ensure_initialized()
	if not comp.changed.is_connected(_on_drag_inventory_changed):
		comp.changed.connect(_on_drag_inventory_changed)
	return comp


func _rebuild_inventory_grid(grid: GridContainer, comp: InventoryComponent) -> void:
	for child in grid.get_children():
		child.queue_free()

	if comp == null:
		return

	for i in range(comp.get_slot_count()):
		var slot_ui = DevInventorySlotScene.instantiate()
		grid.add_child(slot_ui)
		slot_ui.bind(comp, i, _equip_session)


func _refresh_inventory_grid(grid: GridContainer) -> void:
	for child in grid.get_children():
		if child != null and child.has_method("refresh"):
			child.refresh()


func _refresh_equip_drag_panel() -> void:
	_refresh_inventory_grid(warehouse_grid)
	_refresh_inventory_grid(member_equip_grid)
	if _equip_cursor_ui != null:
		_equip_cursor_ui.sync(_equip_session)
	_refresh_cursor_state_label()
	_refresh_member_equip_label()


func _refresh_cursor_state_label() -> void:
	if _equip_session == null or _equip_session.cursor == null or _equip_session.cursor.is_empty():
		cursor_state_label.text = "Cursor: empty"
		return
	var item_name := String(_equip_session.cursor.item.item_id)
	if _equip_session.cursor.item != null and not _equip_session.cursor.item.item_name.is_empty():
		item_name = _equip_session.cursor.item.item_name
	cursor_state_label.text = "Cursor: %s x%d" % [item_name, _equip_session.cursor.count]


func _refresh_member_equip_label() -> void:
	var row_idx := _get_selected_equip_target_row_index()
	member_equip_label.text = "Member Equip (Row %d)" % (row_idx + 1)


func _get_selected_equip_target_row_index() -> int:
	if equip_target_row_box.item_count <= 0:
		return 0
	return clampi(equip_target_row_box.selected, 0, max(equip_target_row_box.item_count - 1, 0))


func _get_selected_member_equip_comp() -> InventoryComponent:
	if _member_equip_comps.is_empty():
		return null
	var idx := _get_selected_equip_target_row_index()
	if idx < 0 or idx >= _member_equip_comps.size():
		return null
	return _member_equip_comps[idx]


func _on_equip_target_row_selected(_index: int) -> void:
	_rebuild_inventory_grid(member_equip_grid, _get_selected_member_equip_comp())
	_refresh_equip_drag_panel()


func _on_drag_inventory_changed() -> void:
	_refresh_equip_drag_panel()


func _on_fill_warehouse_pressed() -> void:
	if _warehouse_comp == null:
		return
	_fill_warehouse_demo_items()
	_refresh_equip_drag_panel()
	log_line("Refilled warehouse demo items for squad equipment drag test.")


func _on_clear_target_equip_pressed() -> void:
	var comp := _get_selected_member_equip_comp()
	if comp == null:
		return
	comp.ensure_initialized()
	for i in range(comp.get_slot_count()):
		var slot: Slot = comp.get_slot(i)
		if slot != null:
			slot.clear()
	comp.notify_changed()
	log_line("Cleared target member equipment inventory.")


func _fill_warehouse_demo_items() -> void:
	_warehouse_comp.ensure_initialized()
	for i in range(_warehouse_comp.get_slot_count()):
		var slot: Slot = _warehouse_comp.get_slot(i)
		if slot != null:
			slot.clear()

	var demo_items: Array = [
		{"id": &"iron_sword", "name": "Iron Sword"},
		{"id": &"wood_shield", "name": "Wood Shield"},
		{"id": &"hunter_bow", "name": "Hunter Bow"},
		{"id": &"iron_sword", "name": "Iron Sword"},
		{"id": &"wood_shield", "name": "Wood Shield"},
	]

	for i in range(mini(demo_items.size(), _warehouse_comp.get_slot_count())):
		var slot: Slot = _warehouse_comp.get_slot(i)
		if slot == null:
			continue
		var spec: Dictionary = demo_items[i]
		var item := _get_or_make_placeholder_item(StringName(spec["id"]), str(spec["name"]))
		slot.item = item
		slot.count = 1
	_warehouse_comp.notify_changed()


func _get_or_make_placeholder_item(item_id: StringName, item_name: String = "") -> ItemData:
	var key := String(item_id)
	if _placeholder_item_cache.has(key):
		return _placeholder_item_cache[key]
	var item := ItemDataResolverRef.resolve(item_id)
	if item == null:
		item = ItemDataRef.new()
		item.item_id = item_id
		item.item_name = item_name if not item_name.is_empty() else key
		item.max_stack = 1
	_placeholder_item_cache[key] = item
	return item


func _ensure_equip_cursor_ui() -> void:
	if _equip_cursor_ui != null:
		return
	if CursorWithItemScene == null:
		return
	var ui = CursorWithItemScene.instantiate()
	if ui == null:
		return
	_equip_cursor_ui = ui
	add_child(_equip_cursor_ui)
	move_child(_equip_cursor_ui, get_child_count() - 1)


func _bind_buttons() -> void:
	if not build_config_button.pressed.is_connected(_on_build_config_pressed):
		build_config_button.pressed.connect(_on_build_config_pressed)
	if not build_runtime_button.pressed.is_connected(_on_build_runtime_pressed):
		build_runtime_button.pressed.connect(_on_build_runtime_pressed)
	if not reset_button.pressed.is_connected(_on_reset_pressed):
		reset_button.pressed.connect(_on_reset_pressed)
	if not fill_warehouse_button.pressed.is_connected(_on_fill_warehouse_pressed):
		fill_warehouse_button.pressed.connect(_on_fill_warehouse_pressed)
	if not clear_target_equip_button.pressed.is_connected(_on_clear_target_equip_pressed):
		clear_target_equip_button.pressed.connect(_on_clear_target_equip_pressed)
	if not equip_target_row_box.item_selected.is_connected(_on_equip_target_row_selected):
		equip_target_row_box.item_selected.connect(_on_equip_target_row_selected)


func _build_demo_templates() -> void:
	_templates.clear()
	_templates.append_array(_load_devtest_templates_from_resources())
	if _templates.is_empty():
		_templates.append(_make_template(&"observer", "Observer", 110.0, 14.0, 6.0, 1.1, [&"basic_attack"], [&"crush_joints"], &"basic_auto"))
		_templates.append(_make_template(&"robot", "Robot", 160.0, 10.0, 10.0, 0.9, [&"basic_attack"], [&"attack_heal_ally"], &"basic_auto"))
		_templates.append(_make_template(&"hunter", "Hunter", 100.0, 12.0, 4.0, 1.2, [&"shoot"], [&"focus"], &"basic_auto"))
		log_line("ActorTemplate resources not found, using built-in demo templates.")
	else:
		log_line("Loaded ActorTemplate resources from data/devtest/expedition/actors.")


func _load_devtest_templates_from_resources() -> Array[ActorTemplate]:
	var loaded: Array[ActorTemplate] = []
	for path in DEVTEST_ACTOR_TEMPLATE_PATHS:
		var res := load(path)
		if res is ActorTemplate:
			loaded.append(res)
		else:
			push_warning("SquadConfigTestPanel: failed to load ActorTemplate resource: %s" % path)
	return loaded


func _make_template(
	template_id: StringName,
	display_name: String,
	max_hp: float,
	atk: float,
	def: float,
	spd: float,
	action_ids: Array[StringName],
	passive_ids: Array[StringName],
	ai_id: StringName
) -> ActorTemplate:
	var t := ActorTemplateRef.new()
	t.template_id = template_id
	t.display_name = display_name
	t.base_attr_set = _make_base_attr_set(max_hp, atk, def, spd)
	t.action_ids = action_ids
	t.passive_ids = passive_ids
	t.ai_id = ai_id
	return t


func _make_base_attr_set(hp_max: float, atk: float, def: float, spd: float) -> AttributeSet:
	var attr_set := AttributeSetRef.new()
	attr_set.attributes = [
		_make_attr("hp_max", hp_max),
		_make_attr("atk", atk),
		_make_attr("def", def),
		_make_attr("spd", spd),
		_make_attr("dmg_out_mul", 1.0),
		_make_attr("dmg_in_mul", 1.0),
		_make_attr("heal_out_mul", 1.0),
		_make_attr("heal_in_mul", 1.0),
	]
	return attr_set


func _make_attr(attr_name: String, base_value: float) -> Attribute:
	var attr := AttributeRef.new()
	attr.attribute_name = attr_name
	attr.base_value = base_value
	return attr


func _reset_ui_to_defaults() -> void:
	_last_config = null
	squad_id_edit.text = "test_squad"
	status_label.text = "Ready"

	for row in _rows:
		(row["enabled"] as CheckBox).button_pressed = bool(row["default_enabled"])
		(row["member_id"] as LineEdit).text = str(row["default_member_id"])
		(row["init_hp"] as SpinBox).value = -1.0

	if equip_target_row_box != null and equip_target_row_box.item_count > 0:
		equip_target_row_box.select(0)
	if _equip_session != null:
		_equip_session.clear_cursor()
	for comp in _member_equip_comps:
		if comp == null:
			continue
		comp.ensure_initialized()
		for i in range(comp.get_slot_count()):
			var slot: Slot = comp.get_slot(i)
			if slot != null:
				slot.clear()
		comp.notify_changed()
	if _warehouse_comp != null:
		_fill_warehouse_demo_items()


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
		var label := String(t.template_id)
		if not t.display_name.is_empty():
			label = "%s (%s)" % [t.display_name, String(t.template_id)]
		box.add_item(label)


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
		var equip_comp := _get_member_equip_comp_by_row_index(i)
		if equip_comp != null and equip_comp.has_method("get_container_snapshot"):
			member.equipment_container = equip_comp.get_container_snapshot()
		member.equipment_ids = _collect_equipment_ids_for_row(i, row["equip"] as OptionButton)
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


func _get_member_equip_comp_by_row_index(row_index: int) -> InventoryComponent:
	if row_index < 0 or row_index >= _member_equip_comps.size():
		return null
	return _member_equip_comps[row_index]


func _collect_equipment_ids_for_row(row_index: int, fallback_box: OptionButton) -> Array[StringName]:
	var comp := _get_member_equip_comp_by_row_index(row_index)
	if comp != null and comp.has_method("collect_equipped_item_ids"):
		var ids_variant: Variant = comp.call("collect_equipped_item_ids")
		if ids_variant is Array:
			var raw_ids: Array = ids_variant
			if raw_ids.is_empty():
				return _get_selected_equipment_ids(fallback_box)
			var out: Array[StringName] = []
			for item in raw_ids:
				out.append(StringName(str(item)))
			return out
	return _get_selected_equipment_ids(fallback_box)


func _show_config(config: SquadConfig) -> void:
	_clear_result("")
	_append_result("=== SquadConfig ===\n")
	_append_result("squad_id: %s\n" % String(config.squad_id))
	_append_result("members: %d\n" % config.members.size())

	for i in range(config.members.size()):
		var m := config.members[i] as MemberConfig
		var equip_text := _join_string_names(m.equipment_ids)
		_append_result("- [%d] member_id=%s template=%s equip=[%s] has_equip_container=%s init_hp=%s\n" % [
			i,
			String(m.member_id),
			String(m.actor_template_id),
			equip_text,
			str(m.equipment_container != null),
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
		_append_result("    actions=[%s] passives=[%s] ai=%s equip=[%s] has_equip_container=%s\n" % [
			_join_string_names(m.action_ids),
			_join_string_names(m.passive_ids),
			String(m.ai_id),
			_join_string_names(m.equipment_ids),
			str(m.equipment_container != null)
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
		if not t.display_name.is_empty():
			names.append("%s(%s)" % [t.display_name, String(t.template_id)])
		else:
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
