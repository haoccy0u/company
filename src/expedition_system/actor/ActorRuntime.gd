extends Node
class_name ActorRuntime

const ActorResultRef = preload("res://src/expedition_system/actor/ActorResult.gd")
const AttributeRef = preload("res://src/attribute_framework/Attribute.gd")
const RuntimeHpAttributeRef = preload("res://src/attribute_framework/RuntimeHpAttribute.gd")
const RuntimeDamageAttributeRef = preload("res://src/attribute_framework/RuntimeDamageAttribute.gd")
const RuntimeHealAttributeRef = preload("res://src/attribute_framework/RuntimeHealAttribute.gd")
const RuntimeCooldownTotalAttributeRef = preload("res://src/attribute_framework/RuntimeCooldownTotalAttribute.gd")
const PassiveExecutorRef = preload("res://src/expedition_system/actor/behavior/PassiveExecutor.gd")
const STATUS_WEAKEN: StringName = &"weaken"

signal hp_changed(actor_id: StringName, current_hp: float, max_hp: float)
signal alive_changed(actor_id: StringName, alive: bool)
signal cooldown_changed(actor_id: StringName, cooldown_remaining: float, cooldown_total: float)

@onready var attribute_component: AttributeComponent = get_node_or_null("AttributeComponent")
@onready var inventory_component = get_node_or_null("ActorInventoryComponent")
@onready var visual_root: Node2D = get_node_or_null("VisualRoot")
@onready var state_fx_root: Node2D = get_node_or_null("VisualRoot/StateFxRoot")
@onready var ui_anchor: Marker2D = get_node_or_null("VisualRoot/UiAnchor")

var actor_id: StringName = &""
var camp: StringName = &""
var member_id: StringName = &""
var actor_template_id: StringName = &""

var max_hp: float = 0.0
var current_hp: float = 0.0
var alive: bool = true
var attr_set: AttributeSet

# M2 placeholder fields for future CombatEngine loop.
var cooldown_total: float = 1.0
var cooldown_remaining: float = 0.0

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


static func from_entry(entry):
	if entry == null:
		return null

	var rt = new()
	if not rt.setup_from_entry(entry):
		return null
	return rt


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


func is_usable() -> bool:
	return alive and current_hp > 0.0


func tick(delta: float) -> void:
	if attr_set != null:
		attr_set.run_process(delta)
		_sync_runtime_state_from_attributes()
	if not alive:
		return
	var before_cd: float = cooldown_remaining
	cooldown_remaining = maxf(cooldown_remaining - maxf(delta, 0.0), 0.0)
	if not is_equal_approx(before_cd, cooldown_remaining):
		cooldown_changed.emit(actor_id, cooldown_remaining, cooldown_total)


func is_ready() -> bool:
	return is_usable() and cooldown_remaining <= 0.0


func reset_cooldown() -> void:
	cooldown_total = maxf(get_attr_value(&"cooldown_total", cooldown_total), 0.1)
	cooldown_remaining = cooldown_total
	cooldown_changed.emit(actor_id, cooldown_remaining, cooldown_total)


func get_hp_ratio() -> float:
	if max_hp <= 0.0:
		return 0.0
	return clampf(current_hp / max_hp, 0.0, 1.0)


func get_current_hp() -> float:
	return current_hp


func get_max_hp() -> float:
	return max_hp


func is_alive() -> bool:
	return alive


func set_cooldown_ratio(ratio: float) -> void:
	cooldown_remaining = cooldown_total * clampf(ratio, 0.0, 1.0)
	cooldown_changed.emit(actor_id, cooldown_remaining, cooldown_total)


func select_action_id() -> StringName:
	if action_ids.is_empty():
		return &"basic_attack"
	return action_ids[0]


func select_attack_target(opponents: Array):
	for target in opponents:
		if target != null and target.is_usable():
			return target
	return null


func build_turn_plan(opponents: Array, allies: Array) -> Dictionary:
	if not is_usable():
		return {}

	var target = select_attack_target(opponents)
	if target == null:
		return {}

	var action_id: StringName = select_action_id()
	var attack_ctx := compute_attack_context(target)
	var follow_up_effects := build_on_attack_effects(target, allies)
	return {
		"action_id": action_id,
		"primary_target": target,
		"attack_ctx": attack_ctx,
		"follow_up_effects": follow_up_effects,
	}


func get_attr_value(attr_name: StringName, fallback: float = 0.0) -> float:
	var attr = find_attribute(attr_name)
	if attr != null:
		return float(attr.get_value())
	if attr_set == null:
		return fallback
	var key := String(attr_name)
	if attr_set.attributes_runtime_dict.has(key):
		var attr2 = attr_set.attributes_runtime_dict[key]
		if attr2 != null:
			return float(attr2.get_value())
	return fallback


func get_attr_base_value(attr_name: StringName, fallback: float = 0.0) -> float:
	var attr = find_attribute(attr_name)
	if attr != null:
		return float(attr.get_base_value())
	if attr_set == null:
		return fallback
	var key := String(attr_name)
	if attr_set.attributes_runtime_dict.has(key):
		var attr2 = attr_set.attributes_runtime_dict[key]
		if attr2 != null:
			return float(attr2.get_base_value())
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
	match status_id:
		STATUS_WEAKEN:
			return has_named_buff(&"dmg_out_mul", STATUS_WEAKEN)
		_:
			return false


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


func get_attribute_component() -> AttributeComponent:
	return attribute_component


func get_inventory_component() -> InventoryComponent:
	return inventory_component


func apply_heal(amount: float) -> float:
	if amount <= 0.0 or not alive:
		return 0.0
	var before_hp: float = current_hp
	var hp_attr = _get_runtime_hp_attr()
	if hp_attr == null:
		push_error("ActorRuntime.apply_heal failed: missing runtime hp attribute | actor_id=%s" % String(actor_id))
		return 0.0
	hp_attr.add(amount)
	_sync_runtime_state_from_attributes()
	return current_hp - before_hp


func heal(amount: float) -> float:
	return apply_heal(amount)


func apply_damage(amount: float) -> float:
	if amount <= 0.0 or not alive:
		return 0.0
	var before_hp: float = current_hp
	var hp_attr = _get_runtime_hp_attr()
	if hp_attr == null:
		push_error("ActorRuntime.apply_damage failed: missing runtime hp attribute | actor_id=%s" % String(actor_id))
		return 0.0
	hp_attr.sub(amount)
	_sync_runtime_state_from_attributes()
	return before_hp - current_hp


func take_damage(amount: float) -> float:
	return apply_damage(amount)


func resolve_heal_amount(raw_amount: float, incoming_multiplier: float = 1.0, temp_buffs: Array = []) -> float:
	if raw_amount <= 0.0:
		return 0.0
	var heal_attr = _get_runtime_heal_attr()
	if heal_attr == null:
		push_error("ActorRuntime.resolve_heal_amount failed: missing runtime heal attribute | actor_id=%s" % String(actor_id))
		return maxf(raw_amount, 0.0)
	heal_attr.set_value(raw_amount)
	heal_attr.mult(maxf(get_attr_value(&"heal_out_mul", 1.0), 0.0))
	heal_attr.mult(maxf(incoming_multiplier, 0.0))
	var applied_temp_buffs: Array = []
	for buff in temp_buffs:
		if not (buff is AttributeBuff):
			continue
		var applied_buff = heal_attr.add_buff(buff)
		if applied_buff != null:
			applied_temp_buffs.append(applied_buff)
	var final_heal: float = maxf(heal_attr.get_value(), 0.0)
	for buff in applied_temp_buffs:
		heal_attr.remove_buff(buff)
	heal_attr.set_value(0.0)
	return final_heal


func resolve_damage_amount(raw_amount: float, incoming_multiplier: float = 1.0, temp_buffs: Array = []) -> float:
	if raw_amount <= 0.0:
		return 0.0
	var damage_attr = _get_runtime_damage_attr()
	if damage_attr == null:
		push_error("ActorRuntime.resolve_damage_amount failed: missing runtime damage attribute | actor_id=%s" % String(actor_id))
		return maxf(raw_amount, 0.0)
	damage_attr.set_value(raw_amount)
	damage_attr.mult(maxf(get_attr_value(&"dmg_out_mul", 1.0), 0.0))
	damage_attr.mult(maxf(incoming_multiplier, 0.0))
	var applied_temp_buffs: Array = []
	for buff in temp_buffs:
		if not (buff is AttributeBuff):
			continue
		var applied_buff = damage_attr.add_buff(buff)
		if applied_buff != null:
			applied_temp_buffs.append(applied_buff)
	var final_damage: float = maxf(damage_attr.get_value(), 0.0)
	for buff in applied_temp_buffs:
		damage_attr.remove_buff(buff)
	damage_attr.set_value(0.0)
	return final_damage


func compute_attack_context(target) -> Dictionary:
	if target == null:
		return {
			"damage_pre_passive": 0.0,
			"damage_final": 0.0,
			"triggered_effect_ids": [],
		}
	var atk: float = get_attr_value(&"atk", 10.0)
	var defense: float = target.get_attr_value(&"def", 0.0)
	var dmg_in_mul: float = target.get_attr_value(&"dmg_in_mul", 1.0)

	var raw_damage: float = maxf(atk - (defense * 0.5), 1.0)
	var modifier_ctx: Dictionary = PassiveExecutorRef.build_attack_damage_modifiers(self, target)
	var damage_buffs: Array = modifier_ctx.get("buffs", [])
	var effect_ids: Array = modifier_ctx.get("effect_ids", [])
	var damage_after_mul: float = resolve_damage_amount(raw_damage, dmg_in_mul, damage_buffs)

	return {
		"damage_pre_passive": raw_damage,
		"damage_final": maxf(damage_after_mul, 1.0),
		"triggered_effect_ids": effect_ids,
	}


func build_on_attack_effects(primary_target, allies: Array) -> Array[Dictionary]:
	return PassiveExecutorRef.build_on_attack_effects(self, primary_target, allies)


func record_battle_start_state(spawn_index: int) -> void:
	tags["hp_start"] = current_hp
	tags["spawn_index"] = spawn_index


func get_battle_start_hp() -> float:
	return float(tags.get("hp_start", current_hp))


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
		"current_hp": current_hp,
		"max_hp": max_hp,
		"alive": alive,
		"has_attr_set": attr_set != null,
		"cooldown_remaining": cooldown_remaining,
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
	max_hp = maxf(get_attr_value(&"hp_max", float(entry.max_hp)), 0.0)
	current_hp = clampf(float(entry.hp), 0.0, max_hp)
	_ensure_runtime_hp_attribute(current_hp)
	_ensure_runtime_damage_attribute(0.0)
	_ensure_runtime_heal_attribute(0.0)
	_ensure_runtime_cooldown_total_attribute()
	_sync_runtime_state_from_attributes()


func _apply_combat_state_from_entry() -> void:
	cooldown_total = maxf(get_attr_value(&"cooldown_total", 1.0), 0.1)
	cooldown_remaining = cooldown_total


func _apply_behavior_state_from_entry(entry) -> void:
	ai_id = entry.ai_id
	action_ids = entry.action_ids.duplicate()
	passive_ids = entry.passive_ids.duplicate()


func _apply_equipment_state_from_entry(entry) -> void:
	equipment_container = entry.equipment_container.duplicate(true) if entry.equipment_container != null else null
	equipment_ids = entry.equipment_ids.duplicate()


func _apply_extra_state_from_entry(entry) -> void:
	tags = entry.extra.duplicate(true)


func _ensure_runtime_value_attribute(attribute_name: StringName, initial_value: float) -> void:
	_ensure_runtime_value_attribute_with_script(attribute_name, initial_value, AttributeRef)


func _ensure_runtime_hp_attribute(initial_value: float) -> void:
	_ensure_runtime_value_attribute_with_script(&"hp", initial_value, RuntimeHpAttributeRef)


func _ensure_runtime_damage_attribute(initial_value: float) -> void:
	_ensure_runtime_value_attribute_with_script(&"damage", initial_value, RuntimeDamageAttributeRef)


func _ensure_runtime_heal_attribute(initial_value: float) -> void:
	_ensure_runtime_value_attribute_with_script(&"heal", initial_value, RuntimeHealAttributeRef)


func _ensure_runtime_cooldown_total_attribute() -> void:
	_ensure_runtime_value_attribute_with_script(&"cooldown_total", 0.0, RuntimeCooldownTotalAttributeRef)


func _ensure_runtime_value_attribute_with_script(attribute_name: StringName, initial_value: float, attribute_script) -> void:
	if attr_set == null:
		return

	var key := String(attribute_name)
	var has_attr: bool = attr_set.attributes_runtime_dict.has(key)
	if has_attr:
		var runtime_attr = attr_set.attributes_runtime_dict[key]
		if runtime_attr != null:
			runtime_attr.set_value(initial_value)
		return

	var new_attr = attribute_script.new()
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


func _get_runtime_damage_attr():
	return _get_runtime_value_attr(&"damage")


func _get_runtime_heal_attr():
	return _get_runtime_value_attr(&"heal")


func _get_runtime_value_attr(attribute_name: StringName):
	if attr_set == null:
		return null
	var key := String(attribute_name)
	if not attr_set.attributes_runtime_dict.has(key):
		return null
	return attr_set.attributes_runtime_dict[key]


func _sync_runtime_state_from_attributes() -> void:
	var prev_max_hp: float = max_hp
	var prev_hp: float = current_hp
	var prev_alive: bool = alive
	var prev_cooldown_total: float = cooldown_total
	var prev_cooldown_remaining: float = cooldown_remaining
	max_hp = maxf(get_attr_value(&"hp_max", max_hp), 0.0)
	cooldown_total = maxf(get_attr_value(&"cooldown_total", cooldown_total), 0.1)
	var hp_attr = _get_runtime_hp_attr()
	if hp_attr != null:
		current_hp = float(hp_attr.get_value())
	else:
		current_hp = clampf(current_hp, 0.0, max_hp)
	cooldown_remaining = clampf(cooldown_remaining, 0.0, cooldown_total)
	alive = current_hp > 0.0
	if not is_equal_approx(prev_hp, current_hp) or not is_equal_approx(prev_max_hp, max_hp):
		hp_changed.emit(actor_id, current_hp, max_hp)
	if not is_equal_approx(prev_cooldown_total, cooldown_total) or not is_equal_approx(prev_cooldown_remaining, cooldown_remaining):
		cooldown_changed.emit(actor_id, cooldown_remaining, cooldown_total)
	if prev_alive != alive:
		alive_changed.emit(actor_id, alive)


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
