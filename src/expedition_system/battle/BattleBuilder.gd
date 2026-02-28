class_name BattleBuilder extends RefCounted

const ActorEntryRef = preload("res://src/expedition_system/actor/ActorEntry.gd")
const AttributeSetRef = preload("res://src/attribute_framework/AttributeSet.gd")
const AttributeRef = preload("res://src/attribute_framework/Attribute.gd")


static func from_combat_event(combat_event: CombatEventDef, squad_runtime: SquadRuntime) -> BattleStart:
	if combat_event == null:
		push_error("BattleBuilder.from_combat_event failed: combat_event is null")
		return null
	if squad_runtime == null:
		push_error("BattleBuilder.from_combat_event failed: squad_runtime is null")
		return null

	var start := BattleStart.new()
	start.battle_id = StringName("battle_%s" % String(combat_event.event_id))
	start.source_event_id = combat_event.event_id
	start.location_id = combat_event.location_id
	start.step_index = combat_event.step_index
	start.enemy_group_id = combat_event.enemy_group_id

	start.player_entries = _build_player_entries(squad_runtime)
	start.enemy_entries = _build_enemy_entries(combat_event)
	start.players = _entry_array_to_dicts(start.player_entries)
	start.enemies = _entry_array_to_dicts(start.enemy_entries)
	start.rules = {
		"hp_policy_id": &"carry_over",
		"cooldown_stagger": true,
	}

	return start


static func _build_player_entries(squad_runtime: SquadRuntime) -> Array:
	var entries: Array = []

	for member in squad_runtime.members:
		if member == null:
			continue
		if not member.alive:
			continue

		var entry := ActorEntryRef.new()
		entry.actor_id = StringName("p_%s" % String(member.member_id))
		entry.camp = &"player"
		entry.member_id = member.member_id
		entry.actor_template_id = member.actor_template_id
		entry.hp = member.current_hp
		entry.max_hp = member.max_hp
		entry.base_attr_set = member.base_attr_set.duplicate(true) if member.base_attr_set != null else _make_attr_set(member.max_hp, 10.0, 0.0, 1.0)
		entry.ai_id = member.ai_id
		entry.action_ids = member.action_ids.duplicate()
		entry.passive_ids = member.passive_ids.duplicate()
		entry.equipment_container = member.equipment_container.duplicate(true) if member.equipment_container != null else null
		entry.equipment_ids = member.equipment_ids.duplicate()
		entries.append(entry)

	return entries


static func _build_enemy_entries(combat_event: CombatEventDef) -> Array:
	var rows: Array = []
	var spec: Dictionary = _get_enemy_group_spec(combat_event.enemy_group_id, combat_event.step_index)
	var count: int = int(spec.get("count", 1))
	var hp_max: float = float(spec.get("hp_max", 60.0))
	var atk: float = float(spec.get("atk", 8.0))
	var def: float = float(spec.get("def", 2.0))
	var spd: float = float(spec.get("spd", 1.0))
	var action_ids: Array[StringName] = [StringName(str(spec.get("action_id", "basic_attack")))]
	var ai_id: StringName = StringName(str(spec.get("ai_id", "basic_auto")))

	for i in range(max(count, 1)):
		var entry := ActorEntryRef.new()
		entry.actor_id = StringName("e_%d_%d" % [max(combat_event.step_index, 0), i])
		entry.camp = &"enemy"
		entry.actor_template_id = StringName("%s_enemy_%d" % [String(combat_event.enemy_group_id), i])
		entry.hp = hp_max
		entry.max_hp = hp_max
		entry.base_attr_set = _make_attr_set(hp_max, atk, def, spd)
		entry.ai_id = ai_id
		entry.action_ids = action_ids.duplicate()
		entry.passive_ids = []
		entry.equipment_container = null
		entry.equipment_ids = []
		entry.extra = {
			"enemy_group_id": combat_event.enemy_group_id,
			"enemy_index": i,
		}
		rows.append(entry)

	return rows


static func _entry_array_to_dicts(entries: Array) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for entry in entries:
		if entry == null:
			continue
		rows.append(entry.to_dict())
	return rows


static func _get_enemy_group_spec(enemy_group_id: StringName, step_index: int) -> Dictionary:
	var step_scale: float = 1.0 + (0.08 * float(max(step_index, 0)))
	match enemy_group_id:
		&"training_dummy":
			return {
				"count": 1,
				"hp_max": 999.0,
				"atk": 5.0,
				"def": 0.0,
				"spd": 1.0 / 6.0,
				"action_id": &"basic_attack",
				"ai_id": &"basic_auto",
			}
		&"wolves":
			return {
				"count": 3,
				"hp_max": 52.0 * step_scale,
				"atk": 8.0 * step_scale,
				"def": 2.0,
				"spd": 1.35,
				"action_id": &"basic_attack",
				"ai_id": &"basic_auto",
			}
		&"bandits":
			return {
				"count": 2,
				"hp_max": 82.0 * step_scale,
				"atk": 10.0 * step_scale,
				"def": 4.0,
				"spd": 1.0,
				"action_id": &"basic_attack",
				"ai_id": &"basic_auto",
			}
		_:
			return {
				"count": 2,
				"hp_max": 70.0 * step_scale,
				"atk": 9.0 * step_scale,
				"def": 3.0,
				"spd": 1.0,
				"action_id": &"basic_attack",
				"ai_id": &"basic_auto",
			}


static func _make_attr_set(hp_max: float, atk: float, def: float, spd: float) -> AttributeSet:
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


static func _make_attr(attr_name: String, base_value: float) -> Attribute:
	var attr := AttributeRef.new()
	attr.attribute_name = attr_name
	attr.base_value = base_value
	return attr
