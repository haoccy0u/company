extends TestPanelBase
class_name ExpeditionSessionTestPanel

const ActorTemplateRef = preload("res://src/expedition_system/actor/ActorTemplate.gd")
const AttributeSetRef = preload("res://src/attribute_framework/AttributeSet.gd")
const AttributeRef = preload("res://src/attribute_framework/Attribute.gd")
const MemberConfigRef = preload("res://src/expedition_system/squad/MemberConfig.gd")
const SquadConfigRef = preload("res://src/expedition_system/squad/SquadConfig.gd")
const SquadRuntimeFactoryRef = preload("res://src/expedition_system/squad/SquadRuntimeFactory.gd")

const ExpeditionLocationDefRef = preload("res://src/expedition_system/expedition/ExpeditionLocationDef.gd")
const ExpeditionSessionRef = preload("res://src/expedition_system/expedition/ExpeditionSession.gd")
const BattleBuilderRef = preload("res://src/expedition_system/battle/BattleBuilder.gd")
const BattleSessionRef = preload("res://src/expedition_system/battle/BattleSession.gd")
const ResultApplierRef = preload("res://src/expedition_system/battle/ResultApplier.gd")

const CTX_SQUAD_RUNTIME: StringName = &"expedition.squad_runtime"
const HP_POLICY_IDS: Array[StringName] = [
	ResultApplierRef.CARRY_OVER_HP_POLICY_ID,
	ResultApplierRef.RESET_FULL_HP_POLICY_ID,
]
const HP_POLICY_LABELS: Array[String] = [
	"carry_over (inherit battle HP)",
	"reset_full (restore to max HP)",
]

@onready var location_id_edit: LineEdit = $ConfigFrame/ConfigVBox/LocationRow/LocationIdEdit
@onready var enemy_groups_edit: LineEdit = $ConfigFrame/ConfigVBox/EnemyGroupsRow/EnemyGroupsEdit
@onready var allow_non_combat_stub_check: CheckBox = $ConfigFrame/ConfigVBox/OptionsRow/AllowNonCombatStubCheck
@onready var hp_policy_option: OptionButton = $ConfigFrame/ConfigVBox/HpPolicyRow/HpPolicyOption

@onready var build_session_button: Button = $ButtonRow/BuildSessionButton
@onready var advance_button: Button = $ButtonRow/AdvanceButton
@onready var build_battle_start_button: Button = $ButtonRow/BuildBattleStartButton
@onready var resolve_combat_button: Button = $ButtonRow/ResolveCombatStubButton
@onready var complete_event_button: Button = $ButtonRow/CompleteEventButton
@onready var end_session_button: Button = $ButtonRow/EndSessionButton
@onready var reset_button: Button = $ButtonRow/ResetButton

@onready var status_label: Label = $StatusLabel
@onready var squad_state_view: RichTextLabel = $SquadStateFrame/SquadStateVBox/SquadStateView
@onready var result_view: RichTextLabel = $ResultFrame/ResultView

var _session: ExpeditionSession
var _location: ExpeditionLocationDef
var _squad_runtime: SquadRuntime
var _squad_source: String = "demo"
var _last_battle_start: BattleStart
var _last_battle_result: BattleResult


func panel_title() -> String:
	return "Expedition Session Test"


func _ready() -> void:
	_bind_buttons()
	_populate_hp_policy_options()
	_reset_ui_defaults()
	_reset_runtime_state()
	_refresh_squad_state_view()
	_set_result_text("Build a session, then use Advance / Complete Event to test Step 2 flow.\n")


func on_panel_activated() -> void:
	log_line("ExpeditionSessionTestPanel ready.")


func _bind_buttons() -> void:
	if not build_session_button.pressed.is_connected(_on_build_session_pressed):
		build_session_button.pressed.connect(_on_build_session_pressed)
	if not advance_button.pressed.is_connected(_on_advance_pressed):
		advance_button.pressed.connect(_on_advance_pressed)
	if not build_battle_start_button.pressed.is_connected(_on_build_battle_start_pressed):
		build_battle_start_button.pressed.connect(_on_build_battle_start_pressed)
	if not resolve_combat_button.pressed.is_connected(_on_resolve_combat_stub_pressed):
		resolve_combat_button.pressed.connect(_on_resolve_combat_stub_pressed)
	if not complete_event_button.pressed.is_connected(_on_complete_event_pressed):
		complete_event_button.pressed.connect(_on_complete_event_pressed)
	if not end_session_button.pressed.is_connected(_on_end_session_pressed):
		end_session_button.pressed.connect(_on_end_session_pressed)
	if not reset_button.pressed.is_connected(_on_reset_pressed):
		reset_button.pressed.connect(_on_reset_pressed)


func _reset_ui_defaults() -> void:
	location_id_edit.text = "forest_outpost"
	enemy_groups_edit.text = "wolves,bandits"
	allow_non_combat_stub_check.button_pressed = false
	if hp_policy_option.item_count > 0:
		hp_policy_option.select(0)
	status_label.text = "Ready"


func _reset_runtime_state() -> void:
	_session = null
	_location = null
	_squad_runtime = null
	_squad_source = "demo"
	_last_battle_start = null
	_last_battle_result = null


func _on_build_session_pressed() -> void:
	_squad_runtime = _resolve_squad_runtime_for_test()
	if _squad_runtime == null:
		status_label.text = "Build demo squad failed"
		_append_result("Failed to build SquadRuntime (context/demo).\n")
		log_line("Failed to build SquadRuntime from context or demo.")
		return

	_location = _build_location_from_ui()
	if _location == null:
		status_label.text = "Invalid location config"
		_append_result("Invalid location config.\n")
		log_line("Invalid location config.")
		return

	_session = ExpeditionSessionRef.new()
	var ok: bool = _session.setup(_location, _squad_runtime)
	status_label.text = "Session setup: %s" % str(ok)
	_show_state()
	_refresh_squad_state_view()
	log_line("ExpeditionSession.setup -> %s (squad_source=%s)" % [str(ok), _squad_source])


func _on_advance_pressed() -> void:
	if _session == null:
		status_label.text = "Build session first"
		_append_result("Build session first.\n")
		log_line("Advance skipped: session is null.")
		return

	var event_obj: RefCounted = _session.advance()
	if event_obj == null:
		status_label.text = "Advance returned null"
		log_line("advance() -> null")
	else:
		status_label.text = "Advance OK (%s)" % String(_session.get_current_event_type())
		log_line("advance() -> %s" % _event_summary(event_obj))

	_show_state()
	_refresh_squad_state_view()


func _on_build_battle_start_pressed() -> void:
	if _session == null:
		status_label.text = "Build session first"
		log_line("Build BattleStart skipped: session is null.")
		return
	if _session.current_event == null:
		status_label.text = "No current event"
		log_line("Build BattleStart skipped: no current event.")
		_show_state()
		return
	if not (_session.current_event is CombatEventDef):
		status_label.text = "Current event is not combat"
		log_line("Build BattleStart skipped: current event is not CombatEventDef.")
		_show_state()
		return
	if _squad_runtime == null:
		status_label.text = "Squad runtime is null"
		log_line("Build BattleStart skipped: squad runtime is null.")
		return

	var combat_event := _session.current_event as CombatEventDef
	_last_battle_start = BattleBuilderRef.from_combat_event(combat_event, _squad_runtime)
	if _last_battle_start == null:
		status_label.text = "Build BattleStart failed"
		log_line("BattleBuilder.from_combat_event() -> null")
		return

	_apply_selected_hp_policy_to_battle_start(_last_battle_start)
	status_label.text = "Built BattleStart"
	log_line("Built BattleStart: %s" % str(_last_battle_start.to_dict()))
	_show_state()
	_refresh_squad_state_view()


func _on_complete_event_pressed() -> void:
	if _session == null:
		status_label.text = "Build session first"
		log_line("Complete skipped: session is null.")
		return

	var ok: bool = _session.complete_current_event()
	status_label.text = "complete_current_event: %s" % str(ok)
	log_line("complete_current_event() -> %s" % str(ok))
	_show_state()
	_refresh_squad_state_view()


func _on_resolve_combat_stub_pressed() -> void:
	if _session == null:
		status_label.text = "Build session first"
		log_line("Resolve combat skipped: session is null.")
		return
	if _session.current_event == null:
		status_label.text = "No current event"
		log_line("Resolve combat skipped: no current event.")
		_show_state()
		return
	if not (_session.current_event is CombatEventDef):
		status_label.text = "Current event is not combat"
		log_line("Resolve combat skipped: current event is not CombatEventDef.")
		_show_state()
		return
	if _squad_runtime == null:
		status_label.text = "Squad runtime is null"
		log_line("Resolve combat skipped: squad runtime is null.")
		return

	var battle_session := BattleSessionRef.new()
	var combat_event := _session.current_event as CombatEventDef
	_last_battle_start = BattleBuilderRef.from_combat_event(combat_event, _squad_runtime)
	if _last_battle_start == null:
		status_label.text = "Build BattleStart failed"
		log_line("Resolve combat skipped: BattleBuilder returned null.")
		return
	_apply_selected_hp_policy_to_battle_start(_last_battle_start)
	var result := battle_session.run_stub_from_combat_event(combat_event, _squad_runtime)
	if result == null:
		status_label.text = "Stub battle failed"
		log_line("run_stub_from_combat_event() -> null")
		return

	_last_battle_result = result
	var hp_policy_id: StringName = _get_current_hp_policy_id()
	var apply_ok: bool = ResultApplierRef.apply_stub_result_to_squad_runtime(result, _squad_runtime, hp_policy_id)
	if not apply_ok:
		status_label.text = "Apply battle result failed"
		log_line("Resolve combat failed: ResultApplier.apply_stub_result_to_squad_runtime() returned false.")
		return

	if _squad_source == "hub_context":
		# Keep shared context synchronized for subsequent panels/tests.
		ctx_set(CTX_SQUAD_RUNTIME, _squad_runtime.duplicate(true))

	var completed: bool = _session.complete_current_event()
	status_label.text = "Combat stub resolved (%s), complete=%s" % [String(result.ended_reason), str(completed)]
	log_line("Resolved combat stub (hp_policy=%s): %s, complete_current_event=%s" % [
		String(hp_policy_id),
		str(result.to_dict()),
		str(completed)
	])
	_show_state()
	_refresh_squad_state_view()


func _on_end_session_pressed() -> void:
	if _session == null:
		status_label.text = "Build session first"
		log_line("End skipped: session is null.")
		return

	_session.end_session(&"manual_test_end")
	status_label.text = "Session ended"
	log_line("end_session(manual_test_end)")
	_show_state()
	_refresh_squad_state_view()


func _on_reset_pressed() -> void:
	_reset_ui_defaults()
	_reset_runtime_state()
	_refresh_squad_state_view()
	_set_result_text("Build a session, then use Advance / Complete Event to test Step 2 flow.\n")
	log_line("ExpeditionSessionTestPanel reset.")


func _build_location_from_ui() -> ExpeditionLocationDef:
	var location_id_text := location_id_edit.text.strip_edges()
	if location_id_text.is_empty():
		return null

	var location := ExpeditionLocationDefRef.new()
	location.location_id = StringName(location_id_text)
	location.allow_non_combat_stub = allow_non_combat_stub_check.button_pressed
	location.combat_enemy_groups = _parse_enemy_groups(enemy_groups_edit.text)
	return location


func _parse_enemy_groups(text: String) -> Array[StringName]:
	var groups: Array[StringName] = []
	for raw_part in text.split(","):
		var part := raw_part.strip_edges()
		if part.is_empty():
			continue
		groups.append(StringName(part))
	return groups


func _build_demo_squad_runtime() -> SquadRuntime:
	var squad_cfg := SquadConfigRef.new()
	squad_cfg.squad_id = &"demo_squad"
	squad_cfg.members = []

	var warrior_template := _make_template(&"warrior", 140.0, [&"slash"], [&"tough_skin"], &"basic_auto")
	var medic_template := _make_template(&"medic", 90.0, [&"heal"], [&"triage"], &"basic_auto")

	var m1 := MemberConfigRef.new()
	m1.member_id = &"m_1"
	m1.actor_template_id = warrior_template.template_id
	m1.actor_template = warrior_template
	m1.equipment_ids = [&"iron_sword"]
	m1.init_hp = -1.0
	squad_cfg.members.append(m1)

	var m2 := MemberConfigRef.new()
	m2.member_id = &"m_2"
	m2.actor_template_id = medic_template.template_id
	m2.actor_template = medic_template
	m2.equipment_ids = [&"wood_shield"]
	m2.init_hp = -1.0
	squad_cfg.members.append(m2)

	return SquadRuntimeFactoryRef.from_config(squad_cfg)


func _make_template(template_id: StringName, max_hp: float, action_ids: Array[StringName], passive_ids: Array[StringName], ai_id: StringName) -> ActorTemplate:
	var t := ActorTemplateRef.new()
	t.template_id = template_id
	t.base_attr_set = _make_base_attr_set(max_hp)
	t.action_ids = action_ids
	t.passive_ids = passive_ids
	t.ai_id = ai_id
	return t


func _make_base_attr_set(hp_max: float) -> AttributeSet:
	var attr_set := AttributeSetRef.new()
	attr_set.attributes = [
		_make_attr("hp_max", hp_max),
		_make_attr("atk", 10.0),
		_make_attr("def", 0.0),
		_make_attr("spd", 1.0),
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


func _show_state() -> void:
	_set_result_text("")
	if _session == null:
		_append_result("session: null\n")
		return

	_append_result("=== ExpeditionSession ===\n")
	_append_result("started=%s ended=%s end_reason=%s\n" % [
		str(_session.is_started),
		str(_session.is_ended),
		String(_session.end_reason)
	])
	_append_result("step_count=%d progress=%s can_advance=%s\n" % [
		_session.step_count,
		str(_session.progress),
		str(_session.can_advance())
	])

	if _location != null:
		_append_result("location=%s enemy_groups=[%s] allow_non_combat_stub=%s\n" % [
			String(_location.location_id),
			_join_string_names(_location.combat_enemy_groups),
			str(_location.allow_non_combat_stub)
		])

	if _squad_runtime != null:
		_append_result("squad=%s living=%s members=%d source=%s\n" % [
			String(_squad_runtime.source_squad_id),
			str(_squad_runtime.has_living_members()),
			_squad_runtime.members.size(),
			_squad_source
		])

	_append_result("\ncurrent_event: %s\n" % _event_summary(_session.current_event))
	_append_result("last_event: %s\n" % _event_summary(_session.last_event))
	_append_result("last_battle_start: %s\n" % _battle_start_summary())
	_append_result("last_battle_result: %s\n" % _battle_result_summary())
	_append_result("selected_hp_policy: %s\n" % _get_selected_hp_policy_label())


func _event_summary(event_obj: RefCounted) -> String:
	if event_obj == null:
		return "null"
	if event_obj.has_method("to_dict"):
		var d: Dictionary = event_obj.call("to_dict")
		return str(d)
	return str(event_obj)


func _set_result_text(text: String) -> void:
	result_view.clear()
	if not text.is_empty():
		result_view.append_text(text)


func _append_result(text: String) -> void:
	result_view.append_text(text)


func _join_string_names(items: Array[StringName]) -> String:
	var parts: Array[String] = []
	for item in items:
		parts.append(String(item))
	return ", ".join(parts)


func _resolve_squad_runtime_for_test() -> SquadRuntime:
	var from_context = ctx_get(CTX_SQUAD_RUNTIME, null)
	if from_context is SquadRuntime:
		_squad_source = "hub_context"
		return (from_context as SquadRuntime).duplicate(true) as SquadRuntime

	_squad_source = "demo"
	return _build_demo_squad_runtime()


func _battle_result_summary() -> String:
	if _last_battle_result == null:
		return "null"
	return str(_last_battle_result.to_dict())


func _battle_start_summary() -> String:
	if _last_battle_start == null:
		return "null"
	return str(_last_battle_start.to_dict())


func _get_current_hp_policy_id() -> StringName:
	if _last_battle_start == null:
		return _get_selected_hp_policy_id()

	var policy_value: Variant = _last_battle_start.rules.get("hp_policy_id", ResultApplierRef.DEFAULT_HP_POLICY_ID)
	if policy_value is StringName:
		return policy_value
	return StringName(str(policy_value))


func _refresh_squad_state_view() -> void:
	squad_state_view.clear()

	if _squad_runtime == null:
		squad_state_view.append_text("squad_runtime: null\n")
		return

	squad_state_view.append_text("source_squad_id: %s\n" % String(_squad_runtime.source_squad_id))
	squad_state_view.append_text("source: %s\n" % _squad_source)
	squad_state_view.append_text("has_living_members: %s\n" % str(_squad_runtime.has_living_members()))
	squad_state_view.append_text("members: %d\n\n" % _squad_runtime.members.size())

	for i in range(_squad_runtime.members.size()):
		var m := _squad_runtime.members[i] as MemberRuntime
		if m == null:
			squad_state_view.append_text("- [%d] <null>\n" % i)
			continue

		squad_state_view.append_text("- [%d] %s (%s)\n" % [
			i,
			String(m.member_id),
			String(m.actor_template_id)
		])
		squad_state_view.append_text("    HP: %s / %s | alive=%s\n" % [
			str(m.current_hp),
			str(m.max_hp),
			str(m.alive)
		])
		squad_state_view.append_text("    equip=[%s]\n" % _join_string_names(m.equipment_ids))


func _populate_hp_policy_options() -> void:
	hp_policy_option.clear()
	for i in range(min(HP_POLICY_IDS.size(), HP_POLICY_LABELS.size())):
		hp_policy_option.add_item(HP_POLICY_LABELS[i], i)


func _get_selected_hp_policy_id() -> StringName:
	var idx := hp_policy_option.selected
	if idx < 0 or idx >= HP_POLICY_IDS.size():
		return ResultApplierRef.DEFAULT_HP_POLICY_ID
	return HP_POLICY_IDS[idx]


func _get_selected_hp_policy_label() -> String:
	var idx := hp_policy_option.selected
	if idx < 0 or idx >= HP_POLICY_LABELS.size():
		return String(ResultApplierRef.DEFAULT_HP_POLICY_ID)
	return HP_POLICY_LABELS[idx]


func _apply_selected_hp_policy_to_battle_start(start: BattleStart) -> void:
	if start == null:
		return
	start.rules["hp_policy_id"] = _get_selected_hp_policy_id()
