extends TestPanelBase
class_name SingleBattleExpeditionTestPanel

const ActorTemplateRef = preload("res://src/expedition_system/actor/ActorTemplate.gd")
const ActorTemplateResolverRef = preload("res://src/expedition_system/actor/ActorTemplateResolver.gd")
const MemberConfigRef = preload("res://src/expedition_system/squad/MemberConfig.gd")
const SquadConfigRef = preload("res://src/expedition_system/squad/SquadConfig.gd")
const SquadRuntimeFactoryRef = preload("res://src/expedition_system/squad/SquadRuntimeFactory.gd")
const ExpeditionLocationDefRef = preload("res://src/expedition_system/expedition/ExpeditionLocationDef.gd")
const ExpeditionSessionRef = preload("res://src/expedition_system/expedition/ExpeditionSession.gd")
const ExpeditionEventRouterRef = preload("res://src/expedition_system/expedition/handler/ExpeditionEventRouter.gd")
const BattleResultRef = preload("res://src/expedition_system/battle/BattleResult.gd")
const CombatEngineRef = preload("res://src/expedition_system/battle/CombatEngine.gd")
const ResultApplierRef = preload("res://src/expedition_system/battle/ResultApplier.gd")

const OBSERVER_TEMPLATE_PATH := "res://data/devtest/expedition/actors/observer.tres"
const ROBOT_TEMPLATE_PATH := "res://data/devtest/expedition/actors/robot.tres"

const LOCATION_ID: StringName = &"single_battle_test"
const ENEMY_GROUP_ID: StringName = &"training_dummy"

const ENEMY_COOLDOWN_SEC: float = 6.0
const COMBAT_STEP_DELTA: float = 0.2
const COMBAT_MAX_TICKS: int = 200

const LOADOUT_PRESETS := {
	&"none": [],
	&"sword": [&"iron_sword"],
	&"shield": [&"wood_shield"],
	&"bow": [&"hunter_bow"],
	&"sword_shield": [&"iron_sword", &"wood_shield"],
}

const LOADOUT_OPTIONS: Array[Dictionary] = [
	{"id": &"none", "label": "None"},
	{"id": &"sword", "label": "Iron Sword"},
	{"id": &"shield", "label": "Wood Shield"},
	{"id": &"bow", "label": "Hunter Bow"},
	{"id": &"sword_shield", "label": "Sword + Shield"},
]

@onready var observer_enabled_check: CheckBox = $ConfigFrame/ConfigVBox/ObserverRow/ObserverEnabledCheck
@onready var observer_loadout_option: OptionButton = $ConfigFrame/ConfigVBox/ObserverRow/ObserverLoadoutOption
@onready var observer_hp_spin: SpinBox = $ConfigFrame/ConfigVBox/ObserverRow/ObserverHpSpin

@onready var robot_enabled_check: CheckBox = $ConfigFrame/ConfigVBox/RobotRow/RobotEnabledCheck
@onready var robot_loadout_option: OptionButton = $ConfigFrame/ConfigVBox/RobotRow/RobotLoadoutOption
@onready var robot_hp_spin: SpinBox = $ConfigFrame/ConfigVBox/RobotRow/RobotHpSpin

@onready var build_squad_button: Button = $ButtonRow/BuildSquadButton
@onready var start_expedition_button: Button = $ButtonRow/StartExpeditionButton
@onready var resolve_combat_button: Button = $ButtonRow/ResolveCombatButton
@onready var reset_button: Button = $ButtonRow/ResetButton

@onready var status_label: Label = $StatusLabel
@onready var squad_view: RichTextLabel = $BodyRow/SquadFrame/SquadVBox/SquadView
@onready var expedition_view: RichTextLabel = $BodyRow/ExpeditionFrame/ExpeditionVBox/ExpeditionView
@onready var runtime_view: RichTextLabel = $BodyRow/RuntimeFrame/RuntimeVBox/RuntimeView
@onready var result_view: RichTextLabel = $ResultFrame/ResultVBox/ResultView
@onready var validation_view: RichTextLabel = $ValidationFrame/ValidationVBox/ValidationView
@onready var runtime_host: Node = $RuntimeHost

var _templates: Dictionary = {}
var _squad_runtime = null
var _session = null
var _location = null
var _last_battle_start = null
var _last_battle_result = null
var _combat_engine = null
var _combat_auto_running: bool = false
var _combat_step_accumulator: float = 0.0


func panel_title() -> String:
	return "Single Battle Expedition"


func _ready() -> void:
	_bind_buttons()
	_load_templates()
	_populate_loadout_options()
	_reset_ui()
	_refresh_all_views()
	set_process(true)


func on_panel_activated() -> void:
	log_line("SingleBattleExpeditionTestPanel ready.")


func _bind_buttons() -> void:
	if not build_squad_button.pressed.is_connected(_on_build_squad_pressed):
		build_squad_button.pressed.connect(_on_build_squad_pressed)
	if not start_expedition_button.pressed.is_connected(_on_start_expedition_pressed):
		start_expedition_button.pressed.connect(_on_start_expedition_pressed)
	if not resolve_combat_button.pressed.is_connected(_on_resolve_combat_pressed):
		resolve_combat_button.pressed.connect(_on_resolve_combat_pressed)
	if not reset_button.pressed.is_connected(_on_reset_pressed):
		reset_button.pressed.connect(_on_reset_pressed)


func _load_templates() -> void:
	_templates.clear()
	_templates[&"observer"] = load(OBSERVER_TEMPLATE_PATH)
	_templates[&"robot"] = load(ROBOT_TEMPLATE_PATH)
	for template in _templates.values():
		if template is ActorTemplate:
			ActorTemplateResolverRef.register_template(template as ActorTemplate)


func _populate_loadout_options() -> void:
	observer_loadout_option.clear()
	robot_loadout_option.clear()
	for row in LOADOUT_OPTIONS:
		var label: String = str(row.get("label", "Unnamed"))
		observer_loadout_option.add_item(label)
		robot_loadout_option.add_item(label)


func _reset_ui() -> void:
	observer_enabled_check.button_pressed = true
	robot_enabled_check.button_pressed = true
	observer_loadout_option.select(0)
	robot_loadout_option.select(0)
	observer_hp_spin.value = -1.0
	robot_hp_spin.value = -1.0
	status_label.text = "Ready"
	_reset_runtime_state()


func _reset_runtime_state() -> void:
	_squad_runtime = null
	_session = null
	_location = null
	_last_battle_start = null
	_last_battle_result = null
	_combat_engine = null
	_combat_auto_running = false
	_combat_step_accumulator = 0.0
	_clear_runtime_host()


func _on_build_squad_pressed() -> void:
	_session = null
	_location = null
	_last_battle_start = null
	_last_battle_result = null
	_squad_runtime = _build_squad_runtime_from_ui()
	if _squad_runtime == null:
		status_label.text = "Build squad failed"
		log_line("Build squad failed.")
	else:
		status_label.text = "Squad built"
		log_line("Built squad runtime with %d members." % _squad_runtime.members.size())
	_refresh_all_views()


func _on_start_expedition_pressed() -> void:
	if _squad_runtime == null:
		status_label.text = "Build squad first"
		log_line("Start expedition skipped: squad is null.")
		return

	_last_battle_result = null
	_location = _build_fixed_location()
	_session = ExpeditionSessionRef.new()
	var ok: bool = bool(_session.setup(_location, _squad_runtime))
	if not ok:
		status_label.text = "Session setup failed"
		log_line("ExpeditionSession.setup() -> false")
		_refresh_all_views()
		return

	var event_obj = _session.advance()
	if event_obj == null or not event_obj.has_method("to_dict"):
		status_label.text = "Advance failed"
		log_line("Expedition advance did not produce a combat event.")
		_refresh_all_views()
		return
	var event_data: Dictionary = event_obj.to_dict()
	if StringName(str(event_data.get("event_type", ""))) != &"combat":
		status_label.text = "Advance failed"
		log_line("Expedition advance produced a non-combat event.")
		_refresh_all_views()
		return

	_last_battle_start = ExpeditionEventRouterRef.build_battle_start(event_obj, _squad_runtime)
	if _last_battle_start == null:
		status_label.text = "Build BattleStart failed"
		log_line("ExpeditionEventRouter.build_battle_start() -> null")
	else:
		_last_battle_start.rules["hp_policy_id"] = ResultApplierRef.CARRY_OVER_HP_POLICY_ID
		status_label.text = "Expedition started"
		log_line("Started single-battle expedition: event=%s enemy_group=%s" % [
			String(event_obj.event_id),
			String(event_obj.enemy_group_id)
		])
	_refresh_all_views()


func _on_resolve_combat_pressed() -> void:
	if _session == null or _last_battle_start == null or _squad_runtime == null:
		status_label.text = "Start expedition first"
		log_line("Resolve combat skipped: expedition is not ready.")
		return

	_clear_runtime_host()
	_last_battle_result = null
	_combat_engine = CombatEngineRef.new()
	_combat_engine.set_actor_host_root(runtime_host)
	var ok: bool = _combat_engine.setup(_last_battle_start)
	if not ok:
		status_label.text = "Combat setup failed"
		log_line("CombatEngine.setup() -> false")
		_refresh_all_views()
		return

	_combat_auto_running = true
	_combat_step_accumulator = 0.0
	status_label.text = "Combat running"
	log_line("Live combat started.")
	_refresh_all_views()


func _on_reset_pressed() -> void:
	_reset_ui()
	_refresh_all_views()
	log_line("Single battle expedition test reset.")


func _build_squad_runtime_from_ui():
	var squad_config = SquadConfigRef.new()
	squad_config.squad_id = &"single_battle_test_squad"

	_append_member_config(
		squad_config,
		observer_enabled_check.button_pressed,
		&"observer",
		_get_selected_loadout_id(observer_loadout_option),
		float(observer_hp_spin.value)
	)
	_append_member_config(
		squad_config,
		robot_enabled_check.button_pressed,
		&"robot",
		_get_selected_loadout_id(robot_loadout_option),
		float(robot_hp_spin.value)
	)

	if squad_config.members.is_empty():
		return null

	var runtime = SquadRuntimeFactoryRef.from_config(squad_config)
	if runtime == null:
		return null
	return runtime


func _append_member_config(squad_config, enabled: bool, template_id: StringName, loadout_id: StringName, initial_hp: float) -> void:
	if not enabled:
		return
	var template = _templates.get(template_id, null)
	if template == null:
		return

	var member_config = MemberConfigRef.new()
	member_config.member_id = StringName("%s_member" % String(template_id))
	member_config.actor_template_id = template_id
	member_config.equipment_ids = _get_loadout_ids(loadout_id)
	member_config.init_hp = initial_hp
	squad_config.members.append(member_config)


func _build_fixed_location():
	var location = ExpeditionLocationDefRef.new()
	location.location_id = LOCATION_ID
	location.event_sequence = PackedStringArray(["combat:%s" % String(ENEMY_GROUP_ID)])
	return location


func _get_selected_loadout_id(option: OptionButton) -> StringName:
	var idx: int = option.selected
	if idx < 0 or idx >= LOADOUT_OPTIONS.size():
		return &"none"
	return LOADOUT_OPTIONS[idx].get("id", &"none")


func _get_loadout_ids(loadout_id: StringName) -> Array[StringName]:
	if LOADOUT_PRESETS.has(loadout_id):
		var raw_ids: Array = LOADOUT_PRESETS[loadout_id]
		var out: Array[StringName] = []
		for item_id in raw_ids:
			out.append(StringName(str(item_id)))
		return out
	return []


func _refresh_all_views() -> void:
	_refresh_squad_view()
	_refresh_expedition_view()
	_refresh_runtime_view()
	_refresh_result_view()
	_refresh_validation_view()


func _refresh_squad_view() -> void:
	squad_view.clear()
	if _squad_runtime == null:
		squad_view.append_text("squad_runtime: null\n")
		return

	squad_view.append_text("Squad Runtime\n")
	squad_view.append_text("members=%d\n\n" % _squad_runtime.members.size())
	for member in _squad_runtime.members:
		if member == null:
			continue
		squad_view.append_text("- %s (%s)\n" % [
			String(member.member_id),
			String(member.actor_template_id)
		])
		squad_view.append_text("  hp=%s/%s alive=%s\n" % [
			str(member.current_hp),
			str(member.max_hp),
			str(member.alive)
		])
		squad_view.append_text("  equip=%s\n" % str(member.equipment_ids))
		var template = ActorTemplateResolverRef.resolve(member.actor_template_id)
		squad_view.append_text("  spd=%s cooldown_total=%s\n\n" % [
			str(_get_template_attr_base_value(template, &"spd")),
			str(_cooldown_from_template(template))
		])


func _refresh_expedition_view() -> void:
	expedition_view.clear()
	expedition_view.append_text("Single Battle Expedition\n")
	expedition_view.append_text("location=%s enemy_group=%s enemy_cd=%s\n\n" % [
		String(LOCATION_ID),
		String(ENEMY_GROUP_ID),
		str(ENEMY_COOLDOWN_SEC)
	])

	if _session == null:
		expedition_view.append_text("session: null\n")
	else:
		expedition_view.append_text("session_started=%s ended=%s reason=%s step=%s\n" % [
			str(_session.is_started),
			str(_session.is_ended),
			String(_session.end_reason),
			str(_session.step_count)
		])
		expedition_view.append_text("current_event=%s\n\n" % _event_summary(_session.current_event))

	if _last_battle_start == null:
		expedition_view.append_text("battle_start: null\n")
		return

	expedition_view.append_text("BattleStart\n")
	expedition_view.append_text("players=%d enemies=%d\n" % [
		_last_battle_start.player_entries.size(),
		_last_battle_start.enemy_entries.size()
	])
	for entry in _last_battle_start.player_entries:
		if entry == null:
			continue
		expedition_view.append_text("- player %s hp=%s/%s spd=%s cd=%s equip=%s\n" % [
			String(entry.member_id),
			str(entry.hp),
			str(entry.max_hp),
			str(_get_attr_base_value(entry.base_attr_set, &"spd")),
			str(_cooldown_from_attr_set(entry.base_attr_set)),
			str(entry.equipment_ids)
		])
	for entry in _last_battle_start.enemy_entries:
		if entry == null:
			continue
		expedition_view.append_text("- enemy %s hp=%s atk=%s spd=%s cd=%s\n" % [
			String(entry.actor_template_id),
			str(entry.max_hp),
			str(_get_attr_base_value(entry.base_attr_set, &"atk")),
			str(_get_attr_base_value(entry.base_attr_set, &"spd")),
			str(_cooldown_from_attr_set(entry.base_attr_set))
		])


func _refresh_runtime_view() -> void:
	runtime_view.clear()
	if _combat_engine == null:
		runtime_view.append_text("combat_runtime: null\n")
		return

	runtime_view.append_text("Live Combat Runtime\n")
	runtime_view.append_text("running=%s finished=%s tick=%s reason=%s winner=%s\n\n" % [
		str(_combat_engine.is_running),
		str(_combat_engine.is_finished),
		str(_combat_engine.tick_count),
		String(_combat_engine.end_reason),
		String(_combat_engine.winner_camp)
	])

	runtime_view.append_text("Players\n")
	_append_runtime_actor_lines(runtime_view, _combat_engine.player_actors)
	runtime_view.append_text("\nEnemies\n")
	_append_runtime_actor_lines(runtime_view, _combat_engine.enemy_actors)


func _append_runtime_actor_lines(view: RichTextLabel, actors: Array) -> void:
	if actors.is_empty():
		view.append_text("- none\n")
		return
	for actor in actors:
		if actor == null:
			continue
		view.append_text("- %s (%s)\n" % [String(actor.actor_id), String(actor.actor_template_id)])
		view.append_text("  hp=%s/%s alive=%s cd=%s/%s\n" % [
			str(actor.get_current_hp()),
			str(actor.get_max_hp()),
			str(actor.is_alive()),
			str(actor.cooldown_remaining),
			str(actor.get_cooldown_total())
		])
		view.append_text("  atk=%s def=%s spd=%s dmg_out=%s dmg_in=%s\n" % [
			str(actor.get_attr_value(&"atk", 0.0)),
			str(actor.get_attr_value(&"def", 0.0)),
			str(actor.get_attr_value(&"spd", 0.0)),
			str(actor.get_attr_value(&"dmg_out_mul", 0.0)),
			str(actor.get_attr_value(&"dmg_in_mul", 0.0))
		])
		view.append_text("  buffs=%s\n" % str(_collect_runtime_buffs(actor)))


func _refresh_result_view() -> void:
	result_view.clear()
	if _last_battle_result == null:
		result_view.append_text("battle_result: null\n")
		return

	result_view.append_text("Battle Result\n")
	result_view.append_text("victory=%s end=%s living_players=%s\n" % [
		str(_last_battle_result.victory),
		String(_last_battle_result.ended_reason),
		str(_last_battle_result.living_player_count)
	])
	result_view.append_text("event_log=%d\n\n" % _last_battle_result.event_log.size())

	for row in _last_battle_result.get_player_result_rows():
		if not (row is Dictionary):
			continue
		result_view.append_text("- %s hp %s -> %s alive=%s\n" % [
			String(row.get("member_id", "")),
			str(row.get("hp_before", 0.0)),
			str(row.get("hp_after", 0.0)),
			str(row.get("alive", false))
		])


func _refresh_validation_view() -> void:
	validation_view.clear()
	for line in _build_validation_lines():
		validation_view.append_text("%s\n" % line)


func _build_validation_lines() -> Array[String]:
	var lines: Array[String] = []
	lines.append(_validation_wait_line(_squad_runtime != null, "squad built", "press Build Squad"))
	lines.append(_validation_wait_line(_session != null, "session started", "press Start Expedition"))
	lines.append(_validation_wait_line(_last_battle_start != null, "battle start built", "start expedition to build battle start"))
	lines.append(_validation_wait_line(_last_battle_result != null, "combat resolved", "press Resolve Combat"))

	if _squad_runtime != null:
		lines.append(_validation_result_line(_validate_member_cooldown(&"observer", 4.0), "observer cooldown is 4s", "observer cooldown resource mismatch"))
		lines.append(_validation_result_line(_validate_member_cooldown(&"robot", 8.0), "robot cooldown is 8s", "robot cooldown resource mismatch"))

	if _last_battle_start != null:
		lines.append(_validation_result_line(_validate_enemy_spec(), "enemy matches single dummy spec", "enemy spec mismatch"))

	return lines


func _validate_member_cooldown(template_id: StringName, expected_sec: float) -> bool:
	if _squad_runtime == null:
		return false
	var found: bool = false
	for member in _squad_runtime.members:
		if member == null or member.actor_template_id != template_id:
			continue
		found = true
		var template := ActorTemplateResolverRef.resolve(member.actor_template_id)
		if not is_equal_approx(_cooldown_from_template(template), expected_sec):
			return false
	return found


func _validate_enemy_spec() -> bool:
	if _last_battle_start == null or _last_battle_start.enemy_entries.size() != 1:
		return false
	var enemy = _last_battle_start.enemy_entries[0]
	if enemy == null:
		return false
	if not is_equal_approx(float(enemy.max_hp), 999.0):
		return false
	if not is_equal_approx(_get_attr_base_value(enemy.base_attr_set, &"atk"), 5.0):
		return false
	return is_equal_approx(_cooldown_from_attr_set(enemy.base_attr_set), ENEMY_COOLDOWN_SEC)


func _cooldown_from_attr_set(attr_set) -> float:
	var spd: float = _get_attr_base_value(attr_set, &"spd")
	if spd <= 0.0:
		return 0.0
	return 1.0 / spd


func _cooldown_from_template(template: ActorTemplate) -> float:
	if template == null:
		return 0.0
	return _cooldown_from_attr_set(template.base_attr_set)


func _get_attr_base_value(attr_set, attr_name: StringName) -> float:
	if attr_set == null:
		return 0.0
	var attr = attr_set.find_attribute(String(attr_name))
	if attr == null:
		return 0.0
	return float(attr.get_base_value())


func _get_template_attr_base_value(template: ActorTemplate, attr_name: StringName) -> float:
	if template == null:
		return 0.0
	return _get_attr_base_value(template.base_attr_set, attr_name)


func _event_summary(event_obj) -> String:
	if event_obj == null:
		return "null"
	if event_obj != null and event_obj.has_method("to_dict"):
		var event_data: Dictionary = event_obj.to_dict()
		if StringName(str(event_data.get("event_type", ""))) == &"combat":
			return "combat(%s)" % String(event_data.get("event_id", ""))
	return str(event_obj)


func _process(delta: float) -> void:
	if not _combat_auto_running or _combat_engine == null:
		return

	_combat_step_accumulator += maxf(delta, 0.0)
	if _combat_step_accumulator < COMBAT_STEP_DELTA:
		return

	while _combat_step_accumulator >= COMBAT_STEP_DELTA and _combat_auto_running:
		_combat_step_accumulator -= COMBAT_STEP_DELTA
		_combat_engine.step(COMBAT_STEP_DELTA)
		if not _combat_engine.is_finished and _combat_engine.tick_count >= COMBAT_MAX_TICKS:
			_combat_engine.is_finished = true
			_combat_engine.is_running = false
			_combat_engine.end_reason = &"tick_limit_reached"
			_combat_engine.winner_camp = &""
		_refresh_all_views()
		if _combat_engine.is_finished:
			_finish_live_combat()
			return


func _finish_live_combat() -> void:
	if _combat_engine == null:
		return

	_combat_auto_running = false
	_append_combat_end_log_if_needed(_combat_engine)
	_last_battle_result = _build_battle_result_from_engine(_combat_engine, _last_battle_start)
	if _last_battle_result == null:
		status_label.text = "Combat finalize failed"
		log_line("Failed to build BattleResult from live engine.")
		_refresh_all_views()
		return

	var apply_ok: bool = ResultApplierRef.apply_stub_result_to_squad_runtime(
		_last_battle_result,
		_squad_runtime,
		ResultApplierRef.CARRY_OVER_HP_POLICY_ID
	)
	if not apply_ok:
		status_label.text = "Apply result failed"
		log_line("ResultApplier.apply_stub_result_to_squad_runtime() -> false")
		_refresh_all_views()
		return

	_session.complete_current_event()
	_session.end_session(&"single_battle_complete")
	status_label.text = "Combat resolved"
	log_line("Combat resolved: victory=%s end=%s" % [
		str(_last_battle_result.victory),
		String(_last_battle_result.ended_reason)
	])
	_refresh_all_views()


func _build_battle_result_from_engine(engine, start):
	if engine == null or start == null:
		return null
	var result = BattleResultRef.new()
	result.battle_id = start.battle_id
	result.source_event_id = start.source_event_id
	result.event_type = &"combat"
	result.step_index = start.step_index
	result.enemy_group_id = start.enemy_group_id
	result.player_count = start.player_entries.size()
	result.success = true
	result.victory = engine.winner_camp == &"player"
	result.ended_reason = engine.end_reason
	result.living_player_count = _count_living_runtime_actors(engine.player_actors)
	result.player_actor_results = _build_actor_results(engine.player_actors)
	result.event_log = engine.event_log.duplicate(true)
	return result


func _build_actor_results(actors: Array) -> Array:
	var rows: Array = []
	for actor in actors:
		if actor == null:
			continue
		rows.append(actor.to_actor_result())
	return rows

func _count_living_runtime_actors(actors: Array) -> int:
	var count: int = 0
	for actor in actors:
		if actor != null and actor.is_alive():
			count += 1
	return count


func _winner_from_survivors(player_actors: Array, enemy_actors: Array) -> StringName:
	var living_players: int = _count_living_runtime_actors(player_actors)
	var living_enemies: int = _count_living_runtime_actors(enemy_actors)
	if living_players > 0 and living_enemies <= 0:
		return &"player"
	if living_enemies > 0 and living_players <= 0:
		return &"enemy"
	if living_players >= living_enemies:
		return &"player"
	return &"enemy"


func _append_combat_end_log_if_needed(engine) -> void:
	if engine == null:
		return
	var has_combat_end: bool = false
	for row in engine.event_log:
		if row is Dictionary and StringName(str(row.get("type", ""))) == &"combat_end":
			has_combat_end = true
			break
	if has_combat_end:
		return
	engine.event_log.append({
		"type": &"combat_end",
		"tick": engine.tick_count,
		"winner_camp": engine.winner_camp,
		"end_reason": engine.end_reason,
		"living_players": _count_living_runtime_actors(engine.player_actors),
		"living_enemies": _count_living_runtime_actors(engine.enemy_actors),
	})


func _collect_runtime_buffs(actor) -> Dictionary:
	if actor == null or actor.attr_set == null:
		return {}
	var rows: Dictionary = {}
	for attr_name in actor.attr_set.attributes_runtime_dict.keys():
		var attr = actor.attr_set.attributes_runtime_dict[attr_name]
		if attr == null or attr.buffs.is_empty():
			continue
		var buff_names: Array[String] = []
		for buff in attr.buffs:
			if buff == null:
				continue
			buff_names.append("%s(%s)" % [String(buff.buff_name), str(buff.value)])
		if not buff_names.is_empty():
			rows[attr_name] = buff_names
	return rows


func _clear_runtime_host() -> void:
	if runtime_host == null:
		return
	for child in runtime_host.get_children():
		runtime_host.remove_child(child)
		child.free()


func _validation_wait_line(ok: bool, pass_label: String, wait_label: String) -> String:
	if ok:
		return "[PASS] %s" % pass_label
	return "[WAIT] %s" % wait_label


func _validation_result_line(ok: bool, pass_label: String, fail_label: String) -> String:
	if ok:
		return "[PASS] %s" % pass_label
	return "[FAIL] %s" % fail_label
