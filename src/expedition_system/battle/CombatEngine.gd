extends RefCounted
class_name CombatEngine

const ActorRuntimeRef = preload("res://src/expedition_system/actor/ActorRuntime.gd")
const ActorRuntimeSceneRef = preload("res://src/expedition_system/actor/ActorRuntime.tscn")
const DEFAULT_TICK_DELTA: float = 0.2
const DEFAULT_MAX_TICKS: int = 200

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

	var turn_plan: Dictionary = attacker.build_turn_plan(_get_actor_opponents(attacker), _get_actor_allies(attacker))
	var target = turn_plan.get("primary_target", null)
	if target == null:
		_evaluate_end_condition()
		return

	var action_id: StringName = turn_plan.get("action_id", &"basic_attack")
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

	var attack_ctx: Dictionary = turn_plan.get("attack_ctx", {})
	var damage_before_bonus: float = float(attack_ctx.get("damage_pre_passive", 0.0))
	var damage_final: float = float(attack_ctx.get("damage_final", 0.0))
	var target_hp_before: float = target.get_current_hp()
	var dealt: float = target.apply_damage(damage_final)
	var target_hp_after: float = target.get_current_hp()

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

	var triggered_effect_ids: Array = attack_ctx.get("triggered_effect_ids", [])
	for effect_id in triggered_effect_ids:
		event_log.append({
			"type": &"passive_trigger",
			"tick": tick_count,
			"actor_id": attacker.actor_id,
			"effect": effect_id,
			"target_actor_id": target.actor_id,
		})

	var follow_up_effects: Array[Dictionary] = turn_plan.get("follow_up_effects", [])
	_apply_actor_effects(attacker, follow_up_effects)

	if not target.is_alive():
		event_log.append({
			"type": &"death",
			"tick": tick_count,
			"actor_id": target.actor_id,
			"member_id": target.member_id,
			"camp": target.camp,
		})

	attacker.reset_cooldown()
	_evaluate_end_condition()


func _apply_actor_effects(attacker, effects: Array[Dictionary]) -> void:
	if attacker == null:
		return
	for effect in effects:
		var effect_type: StringName = effect.get("type", &"")
		match effect_type:
			&"status_apply":
				var target = effect.get("target", null)
				if target == null:
					continue
				var attr_name: StringName = effect.get("attr_name", &"")
				var buff = effect.get("buff", null)
				var applied: bool = target.apply_attribute_buff(attr_name, buff)
				if applied:
					event_log.append({
						"type": &"status_applied",
						"tick": tick_count,
						"actor_id": target.actor_id,
						"member_id": target.member_id,
						"status_id": effect.get("status_id", &""),
						"duration": float(effect.get("duration", 0.0)),
						"multiplier": float(effect.get("multiplier", 0.0)),
						"source_actor_id": attacker.actor_id,
						"passive_id": effect.get("passive_id", &""),
					})
			&"heal":
				var heal_target = effect.get("target", null)
				if heal_target == null:
					continue
				var hp_before: float = heal_target.get_current_hp()
				var healed: float = heal_target.apply_heal(float(effect.get("amount", 0.0)))
				if healed > 0.0:
					event_log.append({
						"type": &"passive_trigger",
						"tick": tick_count,
						"actor_id": attacker.actor_id,
						"passive_id": effect.get("passive_id", &""),
						"effect": effect.get("effect_id", &"heal_one_ally_on_attack"),
						"target_actor_id": heal_target.actor_id,
						"heal_target_rule": effect.get("heal_target_rule", &""),
					})
					event_log.append({
						"type": &"value_change",
						"tick": tick_count,
						"actor_id": heal_target.actor_id,
						"member_id": heal_target.member_id,
						"stat": &"hp",
						"hp_before": hp_before,
						"hp_after": heal_target.get_current_hp(),
						"delta_hp": healed,
						"source_actor_id": attacker.actor_id,
					})


func _get_actor_allies(actor) -> Array:
	if actor == null:
		return []
	return player_actors if actor.camp == &"player" else enemy_actors


func _get_actor_opponents(actor) -> Array:
	if actor == null:
		return []
	return enemy_actors if actor.camp == &"player" else player_actors


func _build_runtime_actors(entries: Array) -> Array:
	var actors: Array = []
	for i in range(entries.size()):
		var entry = entries[i]
		if entry == null:
			continue
		var actor = _instantiate_runtime_actor(entry)
		if actor != null:
			actor.record_battle_start_state(i)
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
		rows.append(actor.to_actor_result())
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
		actor.set_cooldown_ratio(ratio)


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
	snap[String(actor.actor_id)] = actor.get_tracked_status_snapshot()


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
	var actor_events: Array[Dictionary] = actor.build_status_transition_events(prev, tick_count)
	for row in actor_events:
		event_log.append(row)


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
