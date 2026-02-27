extends RefCounted
class_name CombatEngine

const ActorRuntimeRef = preload("res://src/expedition_system/actor/ActorRuntime.gd")
const ActorRuntimeSceneRef = preload("res://src/expedition_system/actor/ActorRuntime.tscn")
const ActorResultRef = preload("res://src/expedition_system/actor/ActorResult.gd")
const PassiveTemplateRef = preload("res://src/expedition_system/battle/PassiveTemplate.gd")

const PASSIVE_CRUSH_JOINTS: StringName = &"crush_joints"
const PASSIVE_ATTACK_HEAL_ALLY: StringName = &"attack_heal_ally"
const STATUS_WEAKEN: StringName = &"weaken"

const DEFAULT_TICK_DELTA: float = 0.2
const DEFAULT_MAX_TICKS: int = 200
const DEFAULT_CRUSH_JOINTS_WEAK_MULT: float = 0.7
const DEFAULT_CRUSH_JOINTS_WEAK_DURATION: float = 2.0
const DEFAULT_CRUSH_JOINTS_BONUS_RATIO: float = 0.25
const DEFAULT_ROBOT_HEAL_FLAT: float = 8.0
const PASSIVE_RESOURCE_DIR := "res://data/devtest/expedition/passives/"

var battle_id: StringName = &""
var source_event_id: StringName = &""
var battle_rules: Dictionary = {}

var player_actors: Array = [] # ActorRuntime[]
var enemy_actors: Array = [] # ActorRuntime[]
var event_log: Array[Dictionary] = []

var tick_count: int = 0
var is_running: bool = false
var is_finished: bool = false
var end_reason: StringName = &""
var winner_camp: StringName = &""
var passive_defs: Dictionary = {} # passive_id(String) -> PassiveTemplate
var actor_host_root: Node = null
var actor_nodes_root: Node = null


func setup(start: BattleStart) -> bool:
	if start == null:
		push_error("CombatEngine.setup failed: start is null")
		return false

	_free_runtime_actors(player_actors)
	_free_runtime_actors(enemy_actors)
	_ensure_actor_nodes_root()

	battle_id = start.battle_id
	source_event_id = start.source_event_id
	battle_rules = start.rules.duplicate(true)
	player_actors = _build_runtime_actors(start.player_entries)
	enemy_actors = _build_runtime_actors(start.enemy_entries)
	event_log = []
	tick_count = 0
	is_running = true
	is_finished = false
	end_reason = &""
	winner_camp = &""
	passive_defs.clear()

	_apply_initial_cooldown_stagger()

	event_log.append({
		"type": &"combat_start",
		"battle_id": battle_id,
		"source_event_id": source_event_id,
		"players": player_actors.size(),
		"enemies": enemy_actors.size(),
		"rules": battle_rules.duplicate(true),
	})

	_evaluate_end_condition()
	return true


func run_stub_until_end(start: BattleStart) -> Dictionary:
	# Compatibility entry for existing BattleSession/TestPanel. Behavior is now M3 auto-combat.
	return run_auto_until_end(start)


func run_auto_until_end(start: BattleStart) -> Dictionary:
	if not setup(start):
		return {}

	var tick_delta: float = float(battle_rules.get("tick_delta", DEFAULT_TICK_DELTA))
	var max_ticks: int = int(battle_rules.get("max_ticks", DEFAULT_MAX_TICKS))

	while not is_finished and tick_count < max_ticks:
		step(tick_delta)

	if not is_finished:
		is_finished = true
		is_running = false
		end_reason = &"tick_limit_reached"
		winner_camp = _winner_from_survivors()

	event_log.append({
		"type": &"combat_end",
		"tick": tick_count,
		"winner_camp": winner_camp,
		"end_reason": end_reason,
		"living_players": _count_living(player_actors),
		"living_enemies": _count_living(enemy_actors),
	})

	return {
		"success": true,
		"victory": winner_camp == &"player",
		"end_reason": end_reason,
		"player_actor_results": _build_player_results(),
		"event_log": event_log.duplicate(true),
		"living_player_count": _count_living(player_actors),
	}


func step(delta: float) -> void:
	if is_finished or not is_running:
		return

	tick_count += 1
	var status_before := _capture_tracked_status_snapshot()

	for actor in player_actors:
		if actor != null:
			actor.tick(delta)
	for actor in enemy_actors:
		if actor != null:
			actor.tick(delta)

	event_log.append({
		"type": &"combat_tick",
		"tick": tick_count,
		"delta": delta,
	})
	_log_tracked_status_transitions(status_before)

	_process_ready_actors(player_actors)
	_process_ready_actors(enemy_actors)
	_evaluate_end_condition()


func _process_ready_actors(group_actors: Array) -> void:
	if is_finished:
		return

	for actor in group_actors:
		if is_finished:
			return
		if actor == null or not actor.is_ready():
			continue
		_resolve_actor_turn(actor)


func _resolve_actor_turn(attacker) -> void:
	if attacker == null or not attacker.is_usable():
		return

	var target = _select_attack_target(attacker)
	if target == null:
		_evaluate_end_condition()
		return

	var action_id: StringName = _select_action_id(attacker)
	var action_log: Dictionary = {
		"type": &"action",
		"tick": tick_count,
		"actor_id": attacker.actor_id,
		"member_id": attacker.member_id,
		"camp": attacker.camp,
		"action_id": action_id,
		"target_actor_id": target.actor_id,
		"target_member_id": target.member_id,
	}

	var attack_ctx := _compute_attack_damage(attacker, target)
	var damage_before_bonus: float = float(attack_ctx.get("damage_pre_passive", 0.0))
	var damage_final: float = float(attack_ctx.get("damage_final", 0.0))
	var target_hp_before: float = target.current_hp
	var dealt: float = target.take_damage(damage_final)
	var target_hp_after: float = target.current_hp

	action_log["damage_pre_passive"] = damage_before_bonus
	action_log["damage"] = dealt
	event_log.append(action_log)

	event_log.append({
		"type": &"value_change",
		"tick": tick_count,
		"actor_id": target.actor_id,
		"member_id": target.member_id,
		"stat": &"hp",
		"hp_before": target_hp_before,
		"hp_after": target_hp_after,
		"delta_hp": -dealt,
		"source_actor_id": attacker.actor_id,
	})

	if bool(attack_ctx.get("bonus_vs_weakened", false)):
		event_log.append({
			"type": &"passive_trigger",
			"tick": tick_count,
			"actor_id": attacker.actor_id,
			"passive_id": PASSIVE_CRUSH_JOINTS,
			"effect": &"bonus_damage_vs_weakened",
			"target_actor_id": target.actor_id,
		})

	_apply_on_attack_passives(attacker, target)

	if not target.alive:
		event_log.append({
			"type": &"death",
			"tick": tick_count,
			"actor_id": target.actor_id,
			"member_id": target.member_id,
			"camp": target.camp,
		})

	attacker.reset_cooldown()
	_evaluate_end_condition()


func _compute_attack_damage(attacker, target) -> Dictionary:
	var atk: float = attacker.get_attr_value(&"atk", 10.0)
	var defense: float = target.get_attr_value(&"def", 0.0)
	var dmg_out_mul: float = attacker.get_attr_value(&"dmg_out_mul", 1.0)
	var dmg_in_mul: float = target.get_attr_value(&"dmg_in_mul", 1.0)

	var raw_damage: float = maxf(atk - (defense * 0.5), 1.0)
	var damage_after_mul: float = maxf(raw_damage * dmg_out_mul * dmg_in_mul, 1.0)
	var bonus_vs_weakened: bool = false

	if _has_passive(attacker, PASSIVE_CRUSH_JOINTS) and target.has_named_buff(&"dmg_out_mul", STATUS_WEAKEN):
		var bonus_ratio: float = _get_passive_param_float(attacker, PASSIVE_CRUSH_JOINTS, &"bonus_damage_ratio", DEFAULT_CRUSH_JOINTS_BONUS_RATIO)
		damage_after_mul *= maxf(1.0 + bonus_ratio, 0.0)
		bonus_vs_weakened = true

	return {
		"damage_pre_passive": raw_damage,
		"damage_final": maxf(damage_after_mul, 1.0),
		"bonus_vs_weakened": bonus_vs_weakened,
	}


func _apply_on_attack_passives(attacker, target) -> void:
	if attacker == null or target == null:
		return

	if _has_passive(attacker, PASSIVE_CRUSH_JOINTS):
		var weak_mult: float = _get_passive_param_float(attacker, PASSIVE_CRUSH_JOINTS, &"weak_outgoing_damage_multiplier", DEFAULT_CRUSH_JOINTS_WEAK_MULT)
		var weak_duration: float = _get_passive_param_float(attacker, PASSIVE_CRUSH_JOINTS, &"weak_duration_sec", DEFAULT_CRUSH_JOINTS_WEAK_DURATION)
		var applied: bool = target.add_multiplicative_buff(&"dmg_out_mul", weak_mult, STATUS_WEAKEN, weak_duration)
		if applied:
			event_log.append({
				"type": &"status_applied",
				"tick": tick_count,
				"actor_id": target.actor_id,
				"member_id": target.member_id,
				"status_id": STATUS_WEAKEN,
				"duration": weak_duration,
				"multiplier": weak_mult,
				"source_actor_id": attacker.actor_id,
				"passive_id": PASSIVE_CRUSH_JOINTS,
			})

	if _has_passive(attacker, PASSIVE_ATTACK_HEAL_ALLY):
		var heal_rule: StringName = _get_passive_param_string_name(attacker, PASSIVE_ATTACK_HEAL_ALLY, &"heal_target_rule", &"lowest_hp_percent_ally")
		var ally = _select_heal_target(attacker, heal_rule)
		if ally != null:
			var heal_out_mul: float = attacker.get_attr_value(&"heal_out_mul", 1.0)
			var heal_in_mul: float = ally.get_attr_value(&"heal_in_mul", 1.0)
			var atk: float = attacker.get_attr_value(&"atk", 10.0)
			var heal_flat: float = _get_passive_param_float(attacker, PASSIVE_ATTACK_HEAL_ALLY, &"heal_amount_flat", DEFAULT_ROBOT_HEAL_FLAT)
			var heal_amount: float = maxf((heal_flat + atk * 0.2) * heal_out_mul * heal_in_mul, 1.0)
			var hp_before: float = ally.current_hp
			var healed: float = ally.heal(heal_amount)
			if healed > 0.0:
				event_log.append({
					"type": &"passive_trigger",
					"tick": tick_count,
					"actor_id": attacker.actor_id,
					"passive_id": PASSIVE_ATTACK_HEAL_ALLY,
					"effect": &"heal_one_ally_on_attack",
					"target_actor_id": ally.actor_id,
					"heal_target_rule": heal_rule,
				})
				event_log.append({
					"type": &"value_change",
					"tick": tick_count,
					"actor_id": ally.actor_id,
					"member_id": ally.member_id,
					"stat": &"hp",
					"hp_before": hp_before,
					"hp_after": ally.current_hp,
					"delta_hp": healed,
					"source_actor_id": attacker.actor_id,
				})


func _select_action_id(attacker) -> StringName:
	if attacker == null or attacker.action_ids.is_empty():
		return &"basic_attack"
	return attacker.action_ids[0]


func _select_attack_target(attacker):
	if attacker == null:
		return null
	var candidates: Array = enemy_actors if attacker.camp == &"player" else player_actors
	for target in candidates:
		if target != null and target.is_usable():
			return target
	return null


func _select_heal_target(attacker, heal_rule: StringName = &"lowest_hp_percent_ally"):
	if attacker == null:
		return null
	var allies: Array = player_actors if attacker.camp == &"player" else enemy_actors
	if heal_rule != &"lowest_hp_percent_ally":
		# Current M3/M4 only implements one rule; keep deterministic fallback.
		heal_rule = &"lowest_hp_percent_ally"
	var best = null
	var best_ratio: float = 2.0
	for ally in allies:
		if ally == null or not ally.is_usable():
			continue
		var max_hp: float = maxf(ally.max_hp, 1.0)
		var ratio: float = ally.current_hp / max_hp
		if ratio < best_ratio:
			best_ratio = ratio
			best = ally
	return best


func _build_runtime_actors(entries: Array) -> Array:
	var actors: Array = []
	for i in range(entries.size()):
		var entry = entries[i]
		if entry == null:
			continue
		var actor = _instantiate_runtime_actor(entry)
		if actor != null:
			actor.tags["hp_start"] = actor.current_hp
			actor.tags["spawn_index"] = i
			_attach_runtime_actor(actor, i)
			actors.append(actor)
	return actors


func _instantiate_runtime_actor(entry):
	var actor = null
	if ActorRuntimeSceneRef != null:
		actor = ActorRuntimeSceneRef.instantiate()

	if actor == null:
		actor = ActorRuntimeRef.new()

	if actor == null:
		return null

	if not actor.has_method("setup_from_entry"):
		push_error("CombatEngine: ActorRuntime instance missing setup_from_entry()")
		if actor is Node:
			actor.free()
		return null

	var ok: bool = bool(actor.call("setup_from_entry", entry))
	if not ok:
		push_warning("CombatEngine: failed to setup ActorRuntime from entry")
		if actor is Node:
			actor.free()
		return null

	return actor


func _build_player_results() -> Array:
	var rows: Array = []
	for actor in player_actors:
		if actor == null:
			continue
		var row := ActorResultRef.new()
		row.member_id = actor.member_id
		row.hp_before = float(actor.tags.get("hp_start", actor.current_hp))
		row.hp_after = actor.current_hp
		row.max_hp = actor.max_hp
		row.alive = actor.alive
		rows.append(row)
	return rows


func _apply_initial_cooldown_stagger() -> void:
	if not bool(battle_rules.get("cooldown_stagger", true)):
		return

	_stagger_group(player_actors)
	_stagger_group(enemy_actors)


func _stagger_group(group_actors: Array) -> void:
	var living: Array = []
	for actor in group_actors:
		if actor != null and actor.is_usable():
			living.append(actor)
	var n: int = living.size()
	if n <= 1:
		return
	for i in range(n):
		var actor = living[i]
		var ratio: float = float(i) / float(n)
		actor.cooldown_remaining = actor.cooldown_total * ratio


func _has_passive(actor, passive_id: StringName) -> bool:
	if actor == null:
		return false
	for pid in actor.passive_ids:
		if pid == passive_id:
			return true
	return false


func _get_passive_param_float(actor, passive_id: StringName, key: StringName, fallback: float) -> float:
	var params: Dictionary = _get_passive_params(actor, passive_id)
	if params.is_empty():
		return fallback
	return float(params.get(String(key), fallback))


func _get_passive_param_string_name(actor, passive_id: StringName, key: StringName, fallback: StringName) -> StringName:
	var params: Dictionary = _get_passive_params(actor, passive_id)
	if params.is_empty():
		return fallback
	var value: Variant = params.get(String(key), fallback)
	if value is StringName:
		return value
	return StringName(str(value))


func _get_passive_params(actor, passive_id: StringName) -> Dictionary:
	if actor == null or not _has_passive(actor, passive_id):
		return {}
	var passive_def = _get_passive_def(passive_id)
	if passive_def == null:
		return {}
	return passive_def.params if passive_def.params is Dictionary else {}


func _get_passive_def(passive_id: StringName):
	var key := String(passive_id)
	if passive_defs.has(key):
		return passive_defs[key]

	var path := "%s%s.tres" % [PASSIVE_RESOURCE_DIR, key]
	var res = load(path)
	if res != null and res is Resource:
		passive_defs[key] = res
		return res
	push_warning("CombatEngine: failed to load PassiveTemplate for passive_id=%s | path=%s" % [key, path])
	return null


func _capture_tracked_status_snapshot() -> Dictionary:
	var snap: Dictionary = {}
	for actor in player_actors:
		_capture_actor_status(actor, snap)
	for actor in enemy_actors:
		_capture_actor_status(actor, snap)
	return snap


func _capture_actor_status(actor, snap: Dictionary) -> void:
	if actor == null:
		return
	snap[String(actor.actor_id)] = {
		String(STATUS_WEAKEN): actor.has_named_buff(&"dmg_out_mul", STATUS_WEAKEN),
	}


func _log_tracked_status_transitions(before_snapshot: Dictionary) -> void:
	for actor in player_actors:
		_log_actor_status_transition(actor, before_snapshot)
	for actor in enemy_actors:
		_log_actor_status_transition(actor, before_snapshot)


func _log_actor_status_transition(actor, before_snapshot: Dictionary) -> void:
	if actor == null:
		return
	var key := String(actor.actor_id)
	var prev: Dictionary = before_snapshot.get(key, {})
	var prev_weaken: bool = bool(prev.get(String(STATUS_WEAKEN), false))
	var now_weaken: bool = actor.has_named_buff(&"dmg_out_mul", STATUS_WEAKEN)
	if prev_weaken and not now_weaken:
		event_log.append({
			"type": &"status_removed",
			"tick": tick_count,
			"actor_id": actor.actor_id,
			"member_id": actor.member_id,
			"status_id": STATUS_WEAKEN,
		})


func _evaluate_end_condition() -> void:
	var living_players: int = _count_living(player_actors)
	var living_enemies: int = _count_living(enemy_actors)

	if living_players <= 0:
		is_finished = true
		is_running = false
		winner_camp = &"enemy"
		end_reason = &"all_players_dead"
		return
	if living_enemies <= 0:
		is_finished = true
		is_running = false
		winner_camp = &"player"
		end_reason = &"all_enemies_dead"
		return


func _winner_from_survivors() -> StringName:
	var living_players: int = _count_living(player_actors)
	var living_enemies: int = _count_living(enemy_actors)
	if living_players > 0 and living_enemies <= 0:
		return &"player"
	if living_enemies > 0 and living_players <= 0:
		return &"enemy"
	if living_players >= living_enemies:
		return &"player"
	return &"enemy"


func _count_living(actors: Array) -> int:
	var count: int = 0
	for actor in actors:
		if actor != null and actor.is_usable():
			count += 1
	return count


func _free_runtime_actors(actors: Array) -> void:
	for actor in actors:
		if actor == null:
			continue
		if actor is Node:
			if actor.get_parent() != null:
				actor.get_parent().remove_child(actor)
			actor.free()


func set_actor_host_root(root: Node) -> void:
	if actor_nodes_root != null and is_instance_valid(actor_nodes_root):
		if actor_nodes_root.get_parent() != null:
			actor_nodes_root.get_parent().remove_child(actor_nodes_root)
		actor_nodes_root.free()
	actor_host_root = root
	actor_nodes_root = null
	var new_root := _ensure_actor_nodes_root()
	if new_root == null:
		return
	for i in range(player_actors.size()):
		_attach_runtime_actor(player_actors[i], i)
	for i in range(enemy_actors.size()):
		_attach_runtime_actor(enemy_actors[i], i)


func get_actor_nodes_root() -> Node:
	return actor_nodes_root if actor_nodes_root != null and is_instance_valid(actor_nodes_root) else null


func _ensure_actor_nodes_root() -> Node:
	if actor_host_root == null or not is_instance_valid(actor_host_root):
		actor_nodes_root = null
		return null
	if actor_nodes_root != null and is_instance_valid(actor_nodes_root):
		return actor_nodes_root

	var root := Node.new()
	root.name = "CombatActors"
	actor_host_root.add_child(root)
	actor_nodes_root = root
	return actor_nodes_root


func _attach_runtime_actor(actor, index: int) -> void:
	if actor == null or not (actor is Node):
		return
	var root := _ensure_actor_nodes_root()
	if root == null:
		return
	actor.name = "%s_%02d_%s" % [String(actor.camp), index, String(actor.actor_id)]
	root.add_child(actor)
