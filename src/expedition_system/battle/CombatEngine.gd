extends RefCounted
class_name CombatEngine

const ActorRuntimeRef = preload("res://src/expedition_system/battle/ActorRuntime.gd")
const ActorResultRef = preload("res://src/expedition_system/battle/ActorResult.gd")

const PASSIVE_CRUSH_JOINTS: StringName = &"crush_joints"
const PASSIVE_ATTACK_HEAL_ALLY: StringName = &"attack_heal_ally"
const STATUS_WEAKEN: StringName = &"weaken"

const DEFAULT_TICK_DELTA: float = 0.2
const DEFAULT_MAX_TICKS: int = 200
const CRUSH_JOINTS_WEAK_MULT: float = 0.7
const CRUSH_JOINTS_WEAK_DURATION: float = 2.0
const CRUSH_JOINTS_BONUS_MULT: float = 1.25
const ROBOT_HEAL_FLAT: float = 8.0

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


func setup(start: BattleStart) -> bool:
	if start == null:
		push_error("CombatEngine.setup failed: start is null")
		return false

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
		damage_after_mul *= CRUSH_JOINTS_BONUS_MULT
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
		var applied: bool = target.add_multiplicative_buff(&"dmg_out_mul", CRUSH_JOINTS_WEAK_MULT, STATUS_WEAKEN, CRUSH_JOINTS_WEAK_DURATION)
		if applied:
			event_log.append({
				"type": &"status_applied",
				"tick": tick_count,
				"actor_id": target.actor_id,
				"member_id": target.member_id,
				"status_id": STATUS_WEAKEN,
				"duration": CRUSH_JOINTS_WEAK_DURATION,
				"source_actor_id": attacker.actor_id,
				"passive_id": PASSIVE_CRUSH_JOINTS,
			})

	if _has_passive(attacker, PASSIVE_ATTACK_HEAL_ALLY):
		var ally = _select_heal_target(attacker)
		if ally != null:
			var heal_out_mul: float = attacker.get_attr_value(&"heal_out_mul", 1.0)
			var heal_in_mul: float = ally.get_attr_value(&"heal_in_mul", 1.0)
			var atk: float = attacker.get_attr_value(&"atk", 10.0)
			var heal_amount: float = maxf((ROBOT_HEAL_FLAT + atk * 0.2) * heal_out_mul * heal_in_mul, 1.0)
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


func _select_heal_target(attacker):
	if attacker == null:
		return null
	var allies: Array = player_actors if attacker.camp == &"player" else enemy_actors
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
		var actor = ActorRuntimeRef.from_entry(entry)
		if actor != null:
			actor.tags["hp_start"] = actor.current_hp
			actor.tags["spawn_index"] = i
			actors.append(actor)
	return actors


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
