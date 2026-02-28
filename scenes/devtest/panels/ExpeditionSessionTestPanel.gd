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
@onready var checkpoint_view: RichTextLabel = $CheckpointFrame/CheckpointVBox/CheckpointView
@onready var squad_state_view: RichTextLabel = $SquadStateFrame/SquadStateVBox/SquadStateView
@onready var result_view: RichTextLabel = $ResultFrame/ResultView

var _session: ExpeditionSession
var _location: ExpeditionLocationDef
var _squad_runtime: SquadRuntime
var _squad_source: String = "demo"
var _last_battle_start: BattleStart
var _last_battle_result: BattleResult
var _pre_battle_member_hp: Dictionary = {}


func panel_title() -> String:
	return "Expedition Session Test"


func _ready() -> void:
	_bind_buttons()
	_populate_hp_policy_options()
	_reset_ui_defaults()
	_reset_runtime_state()
	_refresh_checkpoint_view()
	_refresh_squad_state_view()
	_set_result_text("Build Session -> Advance -> Build BattleStart / Resolve Combat.\n")


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
	_pre_battle_member_hp = {}


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
	_refresh_checkpoint_view()
	_refresh_squad_state_view()
	log_line("session setup -> ok=%s source=%s location=%s" % [str(ok), _squad_source, String(_location.location_id)])


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
		log_line("advance -> %s" % _event_summary(event_obj))

	_show_state()
	_refresh_checkpoint_view()
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
	_capture_pre_battle_snapshot()
	status_label.text = "Built BattleStart"
	log_line("battle_start -> %s" % _battle_start_summary())
	_show_state()
	_refresh_checkpoint_view()
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
	_refresh_checkpoint_view()
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
	_capture_pre_battle_snapshot()
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
	log_line("combat resolved -> policy=%s %s complete=%s" % [
		String(hp_policy_id),
		_battle_result_summary(),
		str(completed)
	])
	_show_state()
	_refresh_checkpoint_view()
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
	_refresh_checkpoint_view()
	_refresh_squad_state_view()


func _on_reset_pressed() -> void:
	_reset_ui_defaults()
	_reset_runtime_state()
	_refresh_checkpoint_view()
	_refresh_squad_state_view()
	_set_result_text("Build Session -> Advance -> Build BattleStart / Resolve Combat.\n")
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
		_append_result("No session. Build Session first.\n")
		return

	_append_result("Session Summary\n")
	_append_result("status=%s | ended=%s | reason=%s\n" % [
		str(_session.is_started),
		str(_session.is_ended),
		String(_session.end_reason)
	])
	_append_result("step=%d | progress=%s | can_advance=%s\n" % [
		_session.step_count,
		str(_session.progress),
		str(_session.can_advance())
	])
	_append_result("event=%s | last_event=%s\n" % [
		_event_summary(_session.current_event),
		_event_summary(_session.last_event)
	])
	_append_result("hp_policy=%s | squad_source=%s\n" % [
		_get_selected_hp_policy_label(),
		_squad_source
	])

	if _location != null:
		_append_result("location=%s | enemy_groups=[%s]\n" % [
			String(_location.location_id),
			_join_string_names(_location.combat_enemy_groups)
		])

	if _last_battle_start != null:
		_append_result("\nBattle Start\n")
		_append_result("%s\n" % _battle_start_summary())

	if _last_battle_result != null:
		_append_result("\nBattle Metrics\n")
		_append_result("%s\n" % _battle_result_summary())
		_append_result("%s\n" % _battle_member_delta_summary())


func _event_summary(event_obj: RefCounted) -> String:
	if event_obj == null:
		return "null"
	if event_obj is CombatEventDef:
		var combat_event := event_obj as CombatEventDef
		return "combat(event_id=%s enemy_group=%s)" % [
			String(combat_event.event_id),
			String(combat_event.enemy_group_id)
		]
	if event_obj is NonCombatEventStub:
		var stub := event_obj as NonCombatEventStub
		return "non_combat(stub_id=%s)" % String(stub.stub_id)
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
	var metrics := _collect_battle_metrics()
	return "victory=%s | end=%s | actions=%d | value=%d | status+=%d | status-=%d | passives=%d | deaths=%d | total_heal=%s | total_damage=%s" % [
		str(_last_battle_result.victory),
		String(_last_battle_result.ended_reason),
		int(metrics.get("action_count", 0)),
		int(metrics.get("value_change_count", 0)),
		int(metrics.get("status_applied_count", 0)),
		int(metrics.get("status_removed_count", 0)),
		int(metrics.get("passive_trigger_count", 0)),
		int(metrics.get("death_count", 0)),
		str(metrics.get("total_heal_received", 0.0)),
		str(metrics.get("total_damage_taken", 0.0))
	]


func _battle_start_summary() -> String:
	if _last_battle_start == null:
		return "null"
	return "enemy_group=%s players=%d enemies=%d hp_policy=%s" % [
		String(_last_battle_start.enemy_group_id),
		_last_battle_start.player_entries.size(),
		_last_battle_start.enemy_entries.size(),
		String(_last_battle_start.rules.get("hp_policy_id", ResultApplierRef.DEFAULT_HP_POLICY_ID))
	]


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


func _refresh_checkpoint_view() -> void:
	checkpoint_view.clear()
	for line in _build_validation_report_lines():
		checkpoint_view.append_text("%s\n" % line)


func _collect_battle_metrics() -> Dictionary:
	var metrics := {
		"action_count": 0,
		"value_change_count": 0,
		"status_applied_count": 0,
		"status_removed_count": 0,
		"passive_trigger_count": 0,
		"death_count": 0,
		"weaken_applied_count": 0,
		"weaken_removed_count": 0,
		"bonus_damage_trigger_count": 0,
		"robot_heal_trigger_count": 0,
		"total_heal_received": 0.0,
		"total_damage_taken": 0.0,
		"member_hp_changes": {},
	}
	if _last_battle_result == null:
		return metrics

	var log_rows: Array = _last_battle_result.event_log
	for row in log_rows:
		if not (row is Dictionary):
			continue
		var event_type := str((row as Dictionary).get("type", ""))
		match event_type:
			"action":
				metrics["action_count"] += 1
			"value_change":
				metrics["value_change_count"] += 1
				var delta_hp: float = float((row as Dictionary).get("delta_hp", 0.0))
				var member_id := String((row as Dictionary).get("member_id", ""))
				var member_changes: Dictionary = metrics["member_hp_changes"]
				if not member_changes.has(member_id):
					member_changes[member_id] = {
						"damage_taken": 0.0,
						"heal_received": 0.0,
					}
				var member_entry: Dictionary = member_changes[member_id]
				if delta_hp > 0.0:
					metrics["total_heal_received"] += delta_hp
					member_entry["heal_received"] = float(member_entry.get("heal_received", 0.0)) + delta_hp
				elif delta_hp < 0.0:
					var damage_taken := absf(delta_hp)
					metrics["total_damage_taken"] += damage_taken
					member_entry["damage_taken"] = float(member_entry.get("damage_taken", 0.0)) + damage_taken
				member_changes[member_id] = member_entry
				metrics["member_hp_changes"] = member_changes
			"status_applied":
				metrics["status_applied_count"] += 1
				if String((row as Dictionary).get("status_id", "")) == "weaken":
					metrics["weaken_applied_count"] += 1
			"status_removed":
				metrics["status_removed_count"] += 1
				if String((row as Dictionary).get("status_id", "")) == "weaken":
					metrics["weaken_removed_count"] += 1
			"passive_trigger":
				metrics["passive_trigger_count"] += 1
				var effect_id := String((row as Dictionary).get("effect", ""))
				if effect_id == "bonus_damage_vs_weakened":
					metrics["bonus_damage_trigger_count"] += 1
				elif effect_id == "heal_one_ally_on_attack":
					metrics["robot_heal_trigger_count"] += 1
			"death":
				metrics["death_count"] += 1
	return metrics


func _capture_pre_battle_snapshot() -> void:
	_pre_battle_member_hp = {}
	if _squad_runtime == null:
		return
	for member in _squad_runtime.members:
		var runtime_member := member as MemberRuntime
		if runtime_member == null:
			continue
		_pre_battle_member_hp[String(runtime_member.member_id)] = runtime_member.current_hp


func _build_validation_report_lines() -> Array[String]:
	var lines: Array[String] = []
	lines.append(_validation_wait_line(_session != null, "session built", "press Build Session"))
	lines.append(_validation_wait_line(_session != null and _session.current_event is CombatEventDef, "current event is combat", "press Advance on a combat event"))
	lines.append(_validation_wait_line(_last_battle_start != null, "battle start built", "press Build BattleStart or Resolve Combat"))
	lines.append(_validation_wait_line(_last_battle_result != null, "battle result built", "press Resolve Combat"))

	if _last_battle_result == null:
		return lines

	var metrics := _collect_battle_metrics()
	lines.append(_validation_result_line(int(metrics.get("action_count", 0)) > 0, "combat produced actions", "expected at least one action event"))
	lines.append(_validation_result_line(int(metrics.get("value_change_count", 0)) > 0, "combat changed HP values", "expected HP changes"))
	lines.append(_validation_result_line(int(metrics.get("weaken_applied_count", 0)) > 0, "observer applied weaken", "observer passive did not apply weaken"))
	lines.append(_validation_result_line(int(metrics.get("weaken_removed_count", 0)) > 0, "weaken expired and was removed", "weaken never expired before combat end"))
	lines.append(_validation_result_line(int(metrics.get("bonus_damage_trigger_count", 0)) > 0, "observer bonus damage triggered", "observer never hit a weakened target"))
	lines.append(_validation_result_line(float(metrics.get("total_heal_received", 0.0)) > 0.0, "robot produced real healing", "no positive healing value reached allies"))
	lines.append(_validation_result_line(_validate_hp_policy_result(), "hp policy applied to squad runtime", "ResultApplier or hp policy mismatch"))
	lines.append(_validation_result_line(_session != null and _session.current_event == null, "combat event completed", "current event was not consumed after resolve"))
	return lines


func _validation_wait_line(ok: bool, pass_label: String, wait_label: String) -> String:
	if ok:
		return "[PASS] %s" % pass_label
	return "[WAIT] %s" % wait_label


func _validation_result_line(ok: bool, pass_label: String, fail_label: String) -> String:
	if ok:
		return "[PASS] %s" % pass_label
	return "[FAIL] %s" % fail_label


func _validate_hp_policy_result() -> bool:
	if _squad_runtime == null or _last_battle_result == null:
		return false

	var hp_policy_id := _get_current_hp_policy_id()
	match hp_policy_id:
		ResultApplierRef.CARRY_OVER_HP_POLICY_ID:
			var result_by_member := {}
			for row in _last_battle_result.player_results:
				if not (row is Dictionary):
					continue
				result_by_member[String((row as Dictionary).get("member_id", ""))] = float((row as Dictionary).get("hp_after", -1.0))
			for member in _squad_runtime.members:
				var runtime_member := member as MemberRuntime
				if runtime_member == null:
					continue
				var expected_hp: float = float(result_by_member.get(String(runtime_member.member_id), -1.0))
				if expected_hp < 0.0:
					return false
				if not is_equal_approx(runtime_member.current_hp, expected_hp):
					return false
			return true
		ResultApplierRef.RESET_FULL_HP_POLICY_ID:
			for member in _squad_runtime.members:
				var runtime_member := member as MemberRuntime
				if runtime_member == null:
					continue
				if runtime_member.alive and not is_equal_approx(runtime_member.current_hp, runtime_member.max_hp):
					return false
			return true
	return false


func _battle_member_delta_summary() -> String:
	if _squad_runtime == null or _last_battle_result == null:
		return "member_hp_delta: unavailable"
	var metrics := _collect_battle_metrics()
	var member_changes: Dictionary = metrics.get("member_hp_changes", {})
	var parts: Array[String] = []
	for member in _squad_runtime.members:
		var runtime_member := member as MemberRuntime
		if runtime_member == null:
			continue
		var before_hp: float = float(_pre_battle_member_hp.get(String(runtime_member.member_id), runtime_member.current_hp))
		var change_row: Dictionary = member_changes.get(String(runtime_member.member_id), {
			"damage_taken": 0.0,
			"heal_received": 0.0,
		})
		parts.append("%s:%s->%s dmg=%s heal=%s" % [
			String(runtime_member.member_id),
			str(before_hp),
			str(runtime_member.current_hp),
			str(change_row.get("damage_taken", 0.0)),
			str(change_row.get("heal_received", 0.0))
		])
	return "member_hp_delta=%s" % ", ".join(parts)


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
