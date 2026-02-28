extends TestPanelBase
class_name ActorRuntimeTestPanel

const ActorRuntimeTestServiceRef = preload("res://src/expedition_system/actor/test/ActorRuntimeTestService.gd")

@onready var actor_template_option: OptionButton = $ConfigFrame/ConfigVBox/ActorRow/ActorTemplateOption
@onready var target_template_option: OptionButton = $ConfigFrame/ConfigVBox/TargetRow/TargetTemplateOption
@onready var loadout_option: OptionButton = $ConfigFrame/ConfigVBox/LoadoutRow/LoadoutOption
@onready var initial_hp_spin: SpinBox = $ConfigFrame/ConfigVBox/InitialHpRow/InitialHpSpin
@onready var damage_spin: SpinBox = $ConfigFrame/ConfigVBox/ValueRow/DamageSpin
@onready var heal_spin: SpinBox = $ConfigFrame/ConfigVBox/ValueRow/HealSpin
@onready var tick_spin: SpinBox = $ConfigFrame/ConfigVBox/ValueRow/TickSpin

@onready var build_actor_button: Button = $ButtonRow/BuildActorButton
@onready var reset_actor_button: Button = $ButtonRow/ResetActorButton
@onready var apply_damage_button: Button = $ButtonRow/ApplyDamageButton
@onready var apply_heal_button: Button = $ButtonRow/ApplyHealButton
@onready var apply_weaken_button: Button = $ButtonRow/ApplyWeakenButton
@onready var tick_button: Button = $ButtonRow/TickButton
@onready var plan_button: Button = $ButtonRow/PlanButton
@onready var smoke_button: Button = $ButtonRow/SmokeButton

@onready var status_label: Label = $StatusLabel
@onready var actor_view: RichTextLabel = $BodyRow/ActorFrame/ActorVBox/ActorView
@onready var behavior_view: RichTextLabel = $BodyRow/BehaviorFrame/BehaviorVBox/BehaviorView
@onready var validation_view: RichTextLabel = $ValidationFrame/ValidationVBox/ValidationView

@onready var runtime_host: Node = $RuntimeHost

var _template_options: Array[Dictionary] = []
var _loadout_options: Array[Dictionary] = []
var _actor: ActorRuntime
var _last_plan_report: Dictionary = {}
var _last_smoke_result: Dictionary = {}


func panel_title() -> String:
	return "Actor Runtime Test"


func _ready() -> void:
	_bind_buttons()
	_populate_options()
	_reset_ui()
	_refresh_all_views()


func on_panel_activated() -> void:
	log_line("ActorRuntimeTestPanel ready.")


func on_panel_deactivated() -> void:
	ActorRuntimeTestServiceRef.clear_host(runtime_host)


func _bind_buttons() -> void:
	if not build_actor_button.pressed.is_connected(_on_build_actor_pressed):
		build_actor_button.pressed.connect(_on_build_actor_pressed)
	if not reset_actor_button.pressed.is_connected(_on_reset_actor_pressed):
		reset_actor_button.pressed.connect(_on_reset_actor_pressed)
	if not apply_damage_button.pressed.is_connected(_on_apply_damage_pressed):
		apply_damage_button.pressed.connect(_on_apply_damage_pressed)
	if not apply_heal_button.pressed.is_connected(_on_apply_heal_pressed):
		apply_heal_button.pressed.connect(_on_apply_heal_pressed)
	if not apply_weaken_button.pressed.is_connected(_on_apply_weaken_pressed):
		apply_weaken_button.pressed.connect(_on_apply_weaken_pressed)
	if not tick_button.pressed.is_connected(_on_tick_pressed):
		tick_button.pressed.connect(_on_tick_pressed)
	if not plan_button.pressed.is_connected(_on_plan_pressed):
		plan_button.pressed.connect(_on_plan_pressed)
	if not smoke_button.pressed.is_connected(_on_smoke_pressed):
		smoke_button.pressed.connect(_on_smoke_pressed)


func _populate_options() -> void:
	_template_options = ActorRuntimeTestServiceRef.get_template_options()
	_loadout_options = ActorRuntimeTestServiceRef.get_loadout_options()

	actor_template_option.clear()
	target_template_option.clear()
	for row in _template_options:
		actor_template_option.add_item(str(row.get("label", "Unnamed")))
		target_template_option.add_item(str(row.get("label", "Unnamed")))

	loadout_option.clear()
	for row in _loadout_options:
		loadout_option.add_item(str(row.get("label", "Unnamed")))


func _reset_ui() -> void:
	if actor_template_option.item_count > 0:
		actor_template_option.select(0)
	if target_template_option.item_count > 1:
		target_template_option.select(1)
	elif target_template_option.item_count > 0:
		target_template_option.select(0)
	if loadout_option.item_count > 0:
		loadout_option.select(0)
	initial_hp_spin.value = -1.0
	damage_spin.value = 20.0
	heal_spin.value = 15.0
	tick_spin.value = 0.5
	status_label.text = "Ready"
	_reset_runtime_state()


func _reset_runtime_state() -> void:
	ActorRuntimeTestServiceRef.clear_host(runtime_host)
	_actor = null
	_last_plan_report = {}
	_last_smoke_result = {}


func _on_build_actor_pressed() -> void:
	_reset_runtime_state()
	_actor = ActorRuntimeTestServiceRef.build_actor(runtime_host, _get_selected_template_id(actor_template_option), {
		"actor_id": "panel_actor",
		"member_id": "panel_actor",
		"camp": &"player",
		"initial_hp": float(initial_hp_spin.value),
		"loadout_id": _get_selected_loadout_id(),
	})
	if _actor == null:
		status_label.text = "Build actor failed"
		log_line("ActorRuntime build failed.")
	else:
		status_label.text = "Actor built"
		log_line("ActorRuntime built: template=%s loadout=%s" % [String(_actor.actor_template_id), String(_get_selected_loadout_id())])
	_refresh_all_views()


func _on_reset_actor_pressed() -> void:
	_reset_ui()
	log_line("ActorRuntime test reset.")


func _on_apply_damage_pressed() -> void:
	if not _ensure_actor_ready("Apply damage"):
		return
	var dealt := _actor.apply_damage(float(damage_spin.value))
	status_label.text = "Damage applied: %s" % str(dealt)
	log_line("actor.apply_damage(%s) -> %s" % [str(damage_spin.value), str(dealt)])
	_refresh_all_views()


func _on_apply_heal_pressed() -> void:
	if not _ensure_actor_ready("Apply heal"):
		return
	var healed := _actor.apply_heal(float(heal_spin.value))
	status_label.text = "Heal applied: %s" % str(healed)
	log_line("actor.apply_heal(%s) -> %s" % [str(heal_spin.value), str(healed)])
	_refresh_all_views()


func _on_apply_weaken_pressed() -> void:
	if not _ensure_actor_ready("Apply weaken"):
		return
	var ok := ActorRuntimeTestServiceRef.apply_demo_weaken(_actor)
	status_label.text = "Weaken applied: %s" % str(ok)
	log_line("apply_demo_weaken() -> %s" % str(ok))
	_refresh_all_views()


func _on_tick_pressed() -> void:
	if not _ensure_actor_ready("Tick"):
		return
	_actor.tick(float(tick_spin.value))
	status_label.text = "Ticked %s" % str(tick_spin.value)
	log_line("actor.tick(%s)" % str(tick_spin.value))
	_refresh_all_views()


func _on_plan_pressed() -> void:
	if not _ensure_actor_ready("Build turn plan"):
		return
	_last_plan_report = ActorRuntimeTestServiceRef.build_turn_plan_report(runtime_host, _actor, _get_selected_template_id(target_template_option))
	status_label.text = "Turn plan built"
	log_line("turn plan -> %s" % str(_last_plan_report))
	_refresh_all_views()


func _on_smoke_pressed() -> void:
	_last_smoke_result = ActorRuntimeTestServiceRef.run_smoke_suite(runtime_host)
	_actor = null
	status_label.text = "Smoke suite: %s pass / %s fail" % [
		str(_last_smoke_result.get("pass_count", 0)),
		str(_last_smoke_result.get("fail_count", 0))
	]
	log_line("ActorRuntime smoke -> %s" % str(_last_smoke_result))
	_refresh_all_views()


func _refresh_all_views() -> void:
	_refresh_actor_view()
	_refresh_behavior_view()
	_refresh_validation_view()


func _refresh_actor_view() -> void:
	actor_view.clear()
	if _actor == null:
		actor_view.append_text("actor: null\n")
		return

	var snapshot := ActorRuntimeTestServiceRef.collect_actor_snapshot(_actor)
	actor_view.append_text("Actor Summary\n")
	actor_view.append_text("actor_id=%s template=%s camp=%s\n" % [
		String(snapshot.get("actor_id", "")),
		String(snapshot.get("template_id", "")),
		String(snapshot.get("camp", "")),
	])
	actor_view.append_text("hp=%s/%s alive=%s cooldown=%s/%s\n" % [
		str(snapshot.get("hp", 0.0)),
		str(snapshot.get("hp_max", 0.0)),
		str(snapshot.get("alive", false)),
		str(snapshot.get("cooldown_remaining", 0.0)),
		str(snapshot.get("cooldown_total", 0.0)),
	])
	actor_view.append_text("actions=%s passives=%s equip=%s\n\n" % [
		str(snapshot.get("action_ids", [])),
		str(snapshot.get("passive_ids", [])),
		str(snapshot.get("equipment_ids", [])),
	])

	actor_view.append_text("Attr Snapshot\n")
	for attr_name in snapshot.get("attr", {}).keys():
		var row: Dictionary = snapshot["attr"][attr_name]
		actor_view.append_text("- %s: base=%s value=%s\n" % [
			attr_name,
			str(row.get("base", 0.0)),
			str(row.get("value", 0.0)),
		])

	actor_view.append_text("\nBuff Snapshot\n")
	var buff_rows: Dictionary = snapshot.get("buffs", {})
	if buff_rows.is_empty():
		actor_view.append_text("- none\n")
	else:
		for attr_name in buff_rows.keys():
			actor_view.append_text("- %s: %s\n" % [attr_name, str(buff_rows[attr_name])])


func _refresh_behavior_view() -> void:
	behavior_view.clear()
	behavior_view.append_text("Turn Plan Preview\n")
	if _last_plan_report.is_empty():
		behavior_view.append_text("plan: not built\n")
	else:
		behavior_view.append_text("ready=%s action=%s target=%s\n" % [
			str(_last_plan_report.get("plan_ready", false)),
			String(_last_plan_report.get("selected_action", "")),
			String(_last_plan_report.get("target_actor_id", "")),
		])
		behavior_view.append_text("damage=%s -> %s\n" % [
			str(_last_plan_report.get("damage_pre_passive", 0.0)),
			str(_last_plan_report.get("damage_final", 0.0)),
		])
		behavior_view.append_text("triggered_effects=%s\n" % str(_last_plan_report.get("triggered_effect_ids", [])))
		behavior_view.append_text("follow_up_effects=%s\n\n" % str(_last_plan_report.get("follow_up_effects", [])))

	behavior_view.append_text("Smoke Result\n")
	if _last_smoke_result.is_empty():
		behavior_view.append_text("smoke: not run\n")
	else:
		behavior_view.append_text("pass=%s fail=%s\n" % [
			str(_last_smoke_result.get("pass_count", 0)),
			str(_last_smoke_result.get("fail_count", 0)),
		])
		for row in _last_smoke_result.get("tests", []):
			if not (row is Dictionary):
				continue
			behavior_view.append_text("- [%s] %s :: %s\n" % [
				"PASS" if bool(row.get("pass", false)) else "FAIL",
				String(row.get("id", "")),
				str(row.get("detail", "")),
			])


func _refresh_validation_view() -> void:
	validation_view.clear()
	for line in _build_validation_lines():
		validation_view.append_text("%s\n" % line)


func _build_validation_lines() -> Array[String]:
	var lines: Array[String] = []
	lines.append(_validation_wait_line(_actor != null, "actor built", "press Build Actor"))
	if _actor == null:
		if _last_smoke_result.is_empty():
			lines.append("[WAIT] run smoke suite for automated checks")
		else:
			lines.append(_validation_result_line(int(_last_smoke_result.get("fail_count", 0)) == 0, "smoke suite passed", "smoke suite has failing checks"))
		return lines

	var snapshot := ActorRuntimeTestServiceRef.collect_actor_snapshot(_actor)
	var attr_rows: Dictionary = snapshot.get("attr", {})
	lines.append(_validation_result_line(attr_rows.has("hp"), "runtime hp attribute exists", "runtime hp attribute missing"))
	lines.append(_validation_result_line(attr_rows.has("damage"), "runtime damage attribute exists", "runtime damage attribute missing"))
	lines.append(_validation_result_line(attr_rows.has("heal"), "runtime heal attribute exists", "runtime heal attribute missing"))
	lines.append(_validation_result_line(attr_rows.has("cooldown_total"), "runtime cooldown_total attribute exists", "runtime cooldown_total attribute missing"))

	if not _last_plan_report.is_empty():
		lines.append(_validation_result_line(bool(_last_plan_report.get("plan_ready", false)), "turn plan built", "turn plan is empty"))
		if _actor.actor_template_id == &"observer":
			lines.append(_validation_result_line(_report_has_follow_up_status(&"weaken"), "observer emits weaken apply intent", "observer weaken follow-up not found"))
		elif _actor.actor_template_id == &"robot":
			lines.append(_validation_result_line(_report_has_follow_up_heal(), "robot emits heal follow-up", "robot heal follow-up not found"))

	if _last_smoke_result.is_empty():
		lines.append("[WAIT] run smoke suite for automated checks")
	else:
		lines.append(_validation_result_line(int(_last_smoke_result.get("fail_count", 0)) == 0, "smoke suite passed", "smoke suite has failing checks"))
	return lines


func _report_has_follow_up_status(status_id: StringName) -> bool:
	for row in _last_plan_report.get("follow_up_effects", []):
		if row.get("status_id", &"") == status_id:
			return true
	return false


func _report_has_follow_up_heal() -> bool:
	for row in _last_plan_report.get("follow_up_effects", []):
		if row.get("type", &"") == &"heal" and float(row.get("amount", 0.0)) > 0.0:
			return true
	return false


func _validation_wait_line(ok: bool, pass_label: String, wait_label: String) -> String:
	if ok:
		return "[PASS] %s" % pass_label
	return "[WAIT] %s" % wait_label


func _validation_result_line(ok: bool, pass_label: String, fail_label: String) -> String:
	if ok:
		return "[PASS] %s" % pass_label
	return "[FAIL] %s" % fail_label


func _get_selected_template_id(box: OptionButton) -> StringName:
	var idx := box.selected
	if idx < 0 or idx >= _template_options.size():
		return &""
	return _template_options[idx].get("id", &"")


func _get_selected_loadout_id() -> StringName:
	var idx := loadout_option.selected
	if idx < 0 or idx >= _loadout_options.size():
		return &"none"
	return _loadout_options[idx].get("id", &"none")


func _ensure_actor_ready(action_name: String) -> bool:
	if _actor != null:
		return true
	status_label.text = "%s: build actor first" % action_name
	log_line("%s skipped: actor is null." % action_name)
	return false
