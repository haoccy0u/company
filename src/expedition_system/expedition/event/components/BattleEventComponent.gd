class_name BattleEventComponent extends Node

const BattleRunnerRef = preload("res://src/expedition_system/battle/BattleRunner.gd")
const BattleRunnerSceneRef = preload("res://src/expedition_system/battle/BattleRunner.tscn")
const ResultApplierRef = preload("res://src/expedition_system/battle/ResultApplier.gd")

signal completed(payload: Dictionary)

@export var battle_runner_scene: PackedScene = BattleRunnerSceneRef
@export var encounter_def: EncounterDef
@export var hp_policy_id: StringName = &"carry_over"
@export var auto_free_runner_on_complete: bool = true

var _runner: BattleRunner
var _running: bool = false
var _active_context: Dictionary = {}


func start_component(context: Dictionary) -> void:
	if _running:
		push_warning("BattleEventComponent.start_component blocked: already running")
		return
	if encounter_def == null:
		_emit_completed({
			"component": &"battle",
			"success": false,
			"battle_end_reason": &"missing_encounter_def",
		})
		return

	var squad_runtime: SquadRuntime = context.get("squad_runtime", null)
	if squad_runtime == null:
		_emit_completed({
			"component": &"battle",
			"encounter_id": encounter_def.encounter_id,
			"success": false,
			"battle_end_reason": &"missing_squad_runtime",
		})
		return

	var runner: BattleRunner = _create_runner()
	if runner == null:
		_emit_completed({
			"component": &"battle",
			"encounter_id": encounter_def.encounter_id,
			"success": false,
			"battle_end_reason": &"runner_create_failed",
		})
		return

	_runner = runner
	_running = true
	_active_context = context.duplicate(true)
	_runner.battle_finished.connect(_on_battle_finished, CONNECT_ONE_SHOT)

	var ok: bool = _runner.start_battle(squad_runtime, encounter_def, context)
	if ok:
		return

	_running = false
	_cleanup_runner()
	_emit_completed({
		"component": &"battle",
		"encounter_id": encounter_def.encounter_id,
		"success": false,
		"battle_end_reason": &"runner_start_failed",
	})


func _create_runner() -> BattleRunner:
	var scene_to_use: PackedScene = battle_runner_scene if battle_runner_scene != null else BattleRunnerSceneRef
	if scene_to_use == null:
		return null

	var instance: Variant = scene_to_use.instantiate()
	if not (instance is BattleRunnerRef):
		return null

	var runner := instance as BattleRunner
	add_child(runner)
	return runner


func _on_battle_finished(payload: Dictionary) -> void:
	_running = false

	var result_payload: Dictionary = payload.duplicate(true)
	result_payload["component"] = &"battle"
	result_payload["encounter_id"] = encounter_def.encounter_id

	var squad_runtime: SquadRuntime = _active_context.get("squad_runtime", null)
	if squad_runtime != null:
		ResultApplierRef.apply_battle_payload_to_squad_runtime(
			result_payload,
			squad_runtime,
			_resolve_hp_policy_id()
		)

	if int(result_payload.get("living_player_count", 0)) <= 0:
		result_payload["expedition_end_reason"] = &"squad_wiped"

	_cleanup_runner()
	_emit_completed(result_payload)


func _resolve_hp_policy_id() -> StringName:
	if encounter_def != null:
		var rules_hp_policy: Variant = encounter_def.rules.get("hp_policy_id", hp_policy_id)
		if rules_hp_policy is StringName:
			return rules_hp_policy
		if rules_hp_policy != null:
			return StringName(str(rules_hp_policy))
	return hp_policy_id


func _cleanup_runner() -> void:
	if _runner == null:
		return
	if not is_instance_valid(_runner):
		_runner = null
		return
	if auto_free_runner_on_complete:
		_runner.queue_free()
	_runner = null


func _emit_completed(payload: Dictionary) -> void:
	completed.emit(payload.duplicate(true))
