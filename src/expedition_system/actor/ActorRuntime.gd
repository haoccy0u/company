extends Node
class_name ActorRuntime

const ActorResultRef = preload("res://src/expedition_system/actor/ActorResult.gd")
const PassiveExecutorRef = preload("res://src/expedition_system/actor/behavior/PassiveExecutor.gd")
const RuntimeHpAttributeRef = preload("res://src/attribute_framework/RuntimeHpAttribute.gd")
const RuntimeCooldownTotalAttributeRef = preload("res://src/attribute_framework/RuntimeCooldownTotalAttribute.gd")
signal hp_changed(actor_id: StringName, current_hp: float, max_hp: float)
signal alive_changed(actor_id: StringName, alive: bool)
signal cooldown_changed(actor_id: StringName, cooldown_remaining: float, cooldown_total: float)

@onready var attribute_component: AttributeComponent = get_node_or_null("AttributeComponent")
@onready var inventory_component = get_node_or_null("ActorInventoryComponent")

var actor_id: StringName = &""
var camp: StringName = &""
var member_id: StringName = &""
var actor_template_id: StringName = &""

var attr_set: AttributeSet

# Runtime countdown state belongs to ActorRuntime. The total value is derived from attributes.
var cooldown_remaining: float = 0.0
var _cached_max_hp: float = 0.0
var _cached_current_hp: float = 0.0
var _cached_cooldown_total: float = 1.0
var _cached_alive: bool = true

var ai_id: StringName = &""
var action_ids: Array[StringName] = []
var passive_ids: Array[StringName] = []
var equipment_container: ItemContainer
var equipment_ids: Array[StringName] = []

var tags: Dictionary = {}


func _ready() -> void:
	if inventory_component != null and not inventory_component.changed.is_connected(_on_inventory_component_changed):
		inventory_component.changed.connect(_on_inventory_component_changed)
	_sync_components_after_setup()


func setup_from_entry(entry) -> bool:
	if entry == null:
		return false

	_apply_identity_from_entry(entry)
	_apply_attribute_state_from_entry(entry)
	_apply_combat_state_from_entry()
	_apply_behavior_state_from_entry(entry)
	_apply_equipment_state_from_entry(entry)
	_apply_extra_state_from_entry(entry)
	_sync_components_after_setup()
	return true


func can_act() -> bool:
	return is_alive()


func is_targetable() -> bool:
	return is_alive()


func is_usable() -> bool:
	return can_act()


func tick(delta: float) -> void:
	if attr_set != null:
		attr_set.run_process(delta)
		_sync_runtime_state_from_attributes()
	if not is_alive():
		return
	var before_cd: float = cooldown_remaining
	cooldown_remaining = maxf(cooldown_remaining - maxf(delta, 0.0), 0.0)
	if not is_equal_approx(before_cd, cooldown_remaining):
		cooldown_changed.emit(actor_id, cooldown_remaining, get_cooldown_total())


func is_ready() -> bool:
	return can_act() and cooldown_remaining <= 0.0


func reset_cooldown() -> void:
	var cooldown_total := get_cooldown_total()
	cooldown_remaining = cooldown_total
	cooldown_changed.emit(actor_id, cooldown_remaining, cooldown_total)


func get_hp_ratio() -> float:
	var max_hp := get_max_hp()
	if max_hp <= 0.0:
		return 0.0
	return clampf(get_current_hp() / max_hp, 0.0, 1.0)


func get_current_hp() -> float:
	var hp_attr = _get_runtime_hp_attr()
	if hp_attr != null:
		return float(hp_attr.get_value())
	return clampf(_cached_current_hp, 0.0, get_max_hp())


func get_max_hp() -> float:
	return maxf(get_attr_value(&"hp_max", _cached_max_hp), 0.0)


func get_cooldown_total() -> float:
	return maxf(get_attr_value(&"cooldown_total", _cached_cooldown_total), 0.1)


func is_alive() -> bool:
	return get_current_hp() > 0.0


func set_cooldown_ratio(ratio: float) -> void:
	var cooldown_total := get_cooldown_total()
	cooldown_remaining = cooldown_total * clampf(ratio, 0.0, 1.0)
	cooldown_changed.emit(actor_id, cooldown_remaining, cooldown_total)


func select_action_id() -> StringName:
	if action_ids.is_empty():
		return &"basic_attack"
	return action_ids[0]


func select_attack_target(opponents: Array):
	for target in opponents:
		if target != null and target.is_targetable():
			return target
	return null


func build_turn_plan(opponents: Array, allies: Array) -> Dictionary:
	if not can_act():
		return {}

	var target = select_attack_target(opponents)
	if target == null:
		return {}

	var action_id: StringName = select_action_id()
	var attack_payload := build_attack_payload(target)
	var follow_up_effects := build_on_attack_effects(target, allies)
	return {
		"action_id": action_id,
		"primary_target": target,
		"attack_payload": attack_payload,
		"follow_up_effects": follow_up_effects,
	}


func get_attr_value(attr_name: StringName, fallback: float = 0.0) -> float:
	var attr = find_attribute(attr_name)
	if attr != null:
		return float(attr.get_value())
	return fallback


func get_attr_base_value(attr_name: StringName, fallback: float = 0.0) -> float:
	var attr = find_attribute(attr_name)
	if attr != null:
		return float(attr.get_base_value())
	return fallback


func find_attribute(attr_name: StringName):
	if attribute_component != null:
		return attribute_component.find_attribute(String(attr_name))
	if attr_set == null:
		return null
	return attr_set.find_attribute(String(attr_name))


func apply_attribute_buff(attr_name: StringName, buff_template: AttributeBuff) -> bool:
	var attr = find_attribute(attr_name)
	if attr == null or buff_template == null:
		return false
	var buff_copy = buff_template.duplicate(true)
	if buff_copy == null:
		return false
	return attr.add_buff(buff_copy) != null


func has_named_buff(attr_name: StringName, buff_name: StringName) -> bool:
	var attr = find_attribute(attr_name)
	if attr == null:
		return false
	return attr.find_buff(String(buff_name)) != null


func has_status(status_id: StringName) -> bool:
	if status_id == StringName() or attr_set == null:
		return false
	return _has_named_buff_anywhere(status_id)


func get_tracked_status_snapshot() -> Dictionary:
	return PassiveExecutorRef.build_tracked_status_snapshot(self)


func build_status_transition_events(before_snapshot: Dictionary, tick_index: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var now_snapshot: Dictionary = get_tracked_status_snapshot()
	for status_key in now_snapshot.keys():
		var had_before: bool = bool(before_snapshot.get(status_key, false))
		var has_now: bool = bool(now_snapshot.get(status_key, false))
		if had_before and not has_now:
			events.append({
				"type": &"status_removed",
				"tick": tick_index,
				"actor_id": actor_id,
				"member_id": member_id,
				"status_id": StringName(str(status_key)),
			})
	return events


func apply_heal(amount: float) -> float:
	if amount <= 0.0 or not is_alive():
		return 0.0
	var hp_attr = _get_runtime_hp_attr()
	if hp_attr == null or not hp_attr.has_method("apply_heal_amount"):
		push_error("ActorRuntime.apply_heal failed: missing runtime hp attribute | actor_id=%s" % String(actor_id))
		return 0.0
	var applied: float = hp_attr.apply_heal_amount(amount)
	_sync_runtime_state_from_attributes()
	return applied


func apply_damage(amount: float) -> float:
	if amount <= 0.0 or not is_alive():
		return 0.0
	var hp_attr = _get_runtime_hp_attr()
	if hp_attr == null or not hp_attr.has_method("apply_damage_amount"):
		push_error("ActorRuntime.apply_damage failed: missing runtime hp attribute | actor_id=%s" % String(actor_id))
		return 0.0
	var applied: float = hp_attr.apply_damage_amount(amount)
	_sync_runtime_state_from_attributes()
	return applied


func build_attack_payload(target) -> Dictionary:
	if target == null:
		return {
			"attack_power": 0.0,
			"outgoing_multiplier": 1.0,
			"damage_buffs": [],
			"triggered_effect_ids": [],
		}
	var modifier_ctx: Dictionary = PassiveExecutorRef.build_attack_damage_modifiers(self, target)
	var damage_buffs: Array = modifier_ctx.get("buffs", [])
	var effect_ids: Array = modifier_ctx.get("effect_ids", [])
	return {
		"attack_power": get_attr_value(&"atk", 10.0),
		"outgoing_multiplier": get_attr_value(&"dmg_out_mul", 1.0),
		"damage_buffs": damage_buffs,
		"triggered_effect_ids": effect_ids,
	}


func resolve_attack_payload(attack_payload: Dictionary) -> Dictionary:
	if attack_payload.is_empty():
		return {
			"raw_damage": 0.0,
			"final_damage": 0.0,
		}
	var hp_attr = _get_runtime_hp_attr()
	if hp_attr == null or not hp_attr.has_method("preview_attack_damage"):
		push_error("ActorRuntime.resolve_attack_payload failed: missing runtime hp attribute | actor_id=%s" % String(actor_id))
		return {
			"raw_damage": 0.0,
			"final_damage": 0.0,
		}
	return hp_attr.preview_attack_damage(
		float(attack_payload.get("attack_power", 0.0)),
		get_attr_value(&"def", 0.0),
		float(attack_payload.get("outgoing_multiplier", 1.0)),
		get_attr_value(&"dmg_in_mul", 1.0),
		attack_payload.get("damage_buffs", [])
	)


func build_on_attack_effects(primary_target, allies: Array) -> Array[Dictionary]:
	return PassiveExecutorRef.build_on_attack_effects(self, primary_target, allies)


func record_battle_start_state(spawn_index: int) -> void:
	tags["hp_start"] = get_current_hp()
	tags["spawn_index"] = spawn_index


func get_battle_start_hp() -> float:
	return float(tags.get("hp_start", get_current_hp()))


func to_actor_result() -> RefCounted:
	var row := ActorResultRef.new()
	row.member_id = member_id
	row.hp_before = get_battle_start_hp()
	row.hp_after = get_current_hp()
	row.max_hp = get_max_hp()
	row.alive = is_alive()
	return row


func to_dict() -> Dictionary:
	return {
		"actor_id": actor_id,
		"camp": camp,
		"member_id": member_id,
		"actor_template_id": actor_template_id,
		"current_hp": get_current_hp(),
		"max_hp": get_max_hp(),
		"alive": is_alive(),
		"has_attr_set": attr_set != null,
		"cooldown_remaining": cooldown_remaining,
		"cooldown_total": get_cooldown_total(),
		"ai_id": ai_id,
		"action_ids": action_ids.duplicate(),
		"passive_ids": passive_ids.duplicate(),
		"has_equipment_container": equipment_container != null,
		"equipment_ids": equipment_ids.duplicate(),
		"tags": tags.duplicate(true),
	}


func _apply_identity_from_entry(entry) -> void:
	actor_id = entry.actor_id
	camp = entry.camp
	member_id = entry.member_id
	actor_template_id = entry.actor_template_id


func _apply_attribute_state_from_entry(entry) -> void:
	attr_set = entry.base_attr_set.duplicate(true) if entry.base_attr_set != null else null
	var initial_max_hp: float = maxf(get_attr_value(&"hp_max", float(entry.max_hp)), 0.0)
	var initial_hp: float = clampf(float(entry.hp), 0.0, initial_max_hp)
	_ensure_runtime_hp_attribute(initial_hp)
	_ensure_runtime_cooldown_total_attribute()
	_sync_runtime_state_from_attributes()


func _apply_combat_state_from_entry() -> void:
	cooldown_remaining = get_cooldown_total()


func _apply_behavior_state_from_entry(entry) -> void:
	ai_id = entry.ai_id
	action_ids = entry.action_ids.duplicate()
	passive_ids = entry.passive_ids.duplicate()


func _apply_equipment_state_from_entry(entry) -> void:
	equipment_container = entry.equipment_container.duplicate(true) if entry.equipment_container != null else null
	equipment_ids = entry.equipment_ids.duplicate()


func _apply_extra_state_from_entry(entry) -> void:
	tags = entry.extra.duplicate(true)


func _ensure_runtime_hp_attribute(initial_value: float) -> void:
	_ensure_runtime_value_attribute_with_class(&"hp", initial_value, RuntimeHpAttributeRef)


func _ensure_runtime_cooldown_total_attribute() -> void:
	_ensure_runtime_value_attribute_with_class(&"cooldown_total", 0.0, RuntimeCooldownTotalAttributeRef)


func _ensure_runtime_value_attribute_with_class(attribute_name: StringName, initial_value: float, attribute_class) -> void:
	if attr_set == null:
		return

	var key := String(attribute_name)
	var has_attr: bool = attr_set.attributes_runtime_dict.has(key)
	if has_attr:
		var runtime_attr = attr_set.attributes_runtime_dict[key]
		if runtime_attr != null:
			runtime_attr.set_value(initial_value)
		return

	var new_attr: Attribute = attribute_class.new()
	new_attr.attribute_name = key
	new_attr.base_value = initial_value

	var new_attributes: Array[Attribute] = []
	for attr in attr_set.attributes:
		if attr != null:
			new_attributes.append(attr)
	new_attributes.append(new_attr)
	attr_set.attributes = new_attributes


func _get_runtime_hp_attr():
	return _get_runtime_value_attr(&"hp")


func _has_named_buff_anywhere(buff_name: StringName) -> bool:
	if attr_set == null:
		return false
	var key := String(buff_name)
	for attr in attr_set.attributes_runtime_dict.values():
		if attr == null:
			continue
		if attr.find_buff(key) != null:
			return true
	return false


func _get_runtime_value_attr(attribute_name: StringName):
	if attr_set == null:
		return null
	var key := String(attribute_name)
	if not attr_set.attributes_runtime_dict.has(key):
		return null
	return attr_set.attributes_runtime_dict[key]


func _sync_runtime_state_from_attributes() -> void:
	var prev_max_hp: float = _cached_max_hp
	var prev_hp: float = _cached_current_hp
	var prev_alive: bool = _cached_alive
	var prev_cooldown_total: float = _cached_cooldown_total
	var prev_cooldown_remaining: float = cooldown_remaining
	_cached_max_hp = get_max_hp()
	_cached_current_hp = get_current_hp()
	_cached_cooldown_total = get_cooldown_total()
	cooldown_remaining = clampf(cooldown_remaining, 0.0, _cached_cooldown_total)
	_cached_alive = _cached_current_hp > 0.0
	if not is_equal_approx(prev_hp, _cached_current_hp) or not is_equal_approx(prev_max_hp, _cached_max_hp):
		hp_changed.emit(actor_id, _cached_current_hp, _cached_max_hp)
	if not is_equal_approx(prev_cooldown_total, _cached_cooldown_total) or not is_equal_approx(prev_cooldown_remaining, cooldown_remaining):
		cooldown_changed.emit(actor_id, cooldown_remaining, _cached_cooldown_total)
	if prev_alive != _cached_alive:
		alive_changed.emit(actor_id, _cached_alive)


func _sync_components_after_setup() -> void:
	_bind_attribute_component()
	_bind_inventory_component()
	_sync_runtime_state_from_attributes()


func _bind_attribute_component() -> void:
	if attribute_component != null:
		# CombatEngine owns battle timing. Disable component auto-process to avoid double ticking.
		attribute_component.set_physics_process(false)
		attribute_component.attribute_set = attr_set


func _bind_inventory_component() -> void:
	if inventory_component != null:
		# Battle actors are runtime instances, not save roots.
		inventory_component.save_enabled = false
		inventory_component.ensure_initialized()
		inventory_component.bind_runtime_attribute_set(attr_set)
		if equipment_container != null and inventory_component.has_method("load_container_snapshot"):
			inventory_component.load_container_snapshot(equipment_container)
		elif not equipment_ids.is_empty() and inventory_component.has_method("load_equipment_ids"):
			inventory_component.load_equipment_ids(equipment_ids)


func _on_inventory_component_changed() -> void:
	if inventory_component == null:
		return
	_sync_runtime_state_from_attributes()
