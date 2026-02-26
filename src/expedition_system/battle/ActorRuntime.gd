extends Node
class_name ActorRuntime

const ActorResultRef = preload("res://src/expedition_system/battle/ActorResult.gd")
const AttributeBuffRef = preload("res://src/attribute_framework/AttributeBuff.gd")
const AttributeRef = preload("res://src/attribute_framework/Attribute.gd")

signal hp_changed(actor_id: StringName, current_hp: float, max_hp: float)
signal alive_changed(actor_id: StringName, alive: bool)
signal cooldown_changed(actor_id: StringName, cooldown_remaining: float, cooldown_total: float)

@onready var attribute_component: AttributeComponent = get_node_or_null("AttributeComponent")
@onready var inventory_component = get_node_or_null("ActorInventoryComponent")

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

	actor_id = entry.actor_id
	camp = entry.camp
	member_id = entry.member_id
	actor_template_id = entry.actor_template_id
	attr_set = entry.base_attr_set.duplicate(true) if entry.base_attr_set != null else null
	max_hp = maxf(get_attr_value(&"hp_max", float(entry.max_hp)), 0.0)
	current_hp = clampf(float(entry.hp), 0.0, max_hp)
	_ensure_runtime_hp_attribute(current_hp)
	_sync_runtime_state_from_attributes()
	cooldown_total = _compute_cooldown_total_from_spd()
	cooldown_remaining = cooldown_total
	ai_id = entry.ai_id
	action_ids = entry.action_ids.duplicate()
	passive_ids = entry.passive_ids.duplicate()
	equipment_container = entry.equipment_container.duplicate(true) if entry.equipment_container != null else null
	equipment_ids = entry.equipment_ids.duplicate()
	tags = entry.extra.duplicate(true)
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
	cooldown_total = _compute_cooldown_total_from_spd()
	cooldown_remaining = cooldown_total
	cooldown_changed.emit(actor_id, cooldown_remaining, cooldown_total)


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


func add_multiplicative_buff(attr_name: StringName, multiplier: float, buff_name: StringName, duration_sec: float) -> bool:
	var attr = find_attribute(attr_name)
	if attr == null:
		return false
	var buff = AttributeBuffRef.mult(multiplier, String(buff_name))
	buff.set_duration(duration_sec)
	attr.add_buff(buff)
	return true


func has_named_buff(attr_name: StringName, buff_name: StringName) -> bool:
	var attr = find_attribute(attr_name)
	if attr == null:
		return false
	return attr.find_buff(String(buff_name)) != null


func get_attribute_component() -> AttributeComponent:
	return attribute_component


func get_inventory_component() -> InventoryComponent:
	return inventory_component


func heal(amount: float) -> float:
	if amount <= 0.0 or not alive:
		return 0.0
	var before_hp: float = current_hp
	var hp_attr = _get_runtime_hp_attr()
	if hp_attr != null:
		hp_attr.add(amount)
		var clamped_hp: float = clampf(hp_attr.get_value(), 0.0, maxf(get_attr_value(&"hp_max", max_hp), 0.0))
		hp_attr.set_value(clamped_hp)
		_sync_runtime_state_from_attributes()
	else:
		current_hp = clampf(current_hp + amount, 0.0, max_hp)
		alive = current_hp > 0.0
	return current_hp - before_hp


func take_damage(amount: float) -> float:
	if amount <= 0.0 or not alive:
		return 0.0
	var before_hp: float = current_hp
	var hp_attr = _get_runtime_hp_attr()
	if hp_attr != null:
		hp_attr.sub(amount)
		var clamped_hp: float = clampf(hp_attr.get_value(), 0.0, maxf(get_attr_value(&"hp_max", max_hp), 0.0))
		hp_attr.set_value(clamped_hp)
		_sync_runtime_state_from_attributes()
	else:
		current_hp = maxf(current_hp - amount, 0.0)
		alive = current_hp > 0.0
	return before_hp - current_hp


func to_actor_result() -> RefCounted:
	var row := ActorResultRef.new()
	row.member_id = member_id
	row.hp_before = current_hp
	row.hp_after = current_hp
	row.max_hp = max_hp
	row.alive = alive
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


func _compute_cooldown_total_from_spd() -> float:
	var spd: float = maxf(get_attr_value(&"spd", 1.0), 0.1)
	return maxf(1.0 / spd, 0.1)


func _ensure_runtime_hp_attribute(initial_hp: float) -> void:
	if attr_set == null:
		return

	var has_hp_attr: bool = attr_set.attributes_runtime_dict.has("hp")
	if has_hp_attr:
		var hp_attr = attr_set.attributes_runtime_dict["hp"]
		if hp_attr != null:
			hp_attr.set_value(initial_hp)
		return

	var new_attr := AttributeRef.new()
	new_attr.attribute_name = "hp"
	new_attr.base_value = initial_hp

	var new_attributes: Array[Attribute] = []
	for attr in attr_set.attributes:
		if attr != null:
			new_attributes.append(attr)
	new_attributes.append(new_attr)
	attr_set.attributes = new_attributes


func _get_runtime_hp_attr():
	if attr_set == null:
		return null
	if not attr_set.attributes_runtime_dict.has("hp"):
		return null
	return attr_set.attributes_runtime_dict["hp"]


func _sync_runtime_state_from_attributes() -> void:
	var prev_max_hp: float = max_hp
	var prev_hp: float = current_hp
	var prev_alive: bool = alive
	max_hp = maxf(get_attr_value(&"hp_max", max_hp), 0.0)
	var hp_attr = _get_runtime_hp_attr()
	if hp_attr != null:
		current_hp = clampf(float(hp_attr.get_value()), 0.0, max_hp)
		if not is_equal_approx(float(hp_attr.get_value()), current_hp):
			hp_attr.set_value(current_hp)
	else:
		current_hp = clampf(current_hp, 0.0, max_hp)
	alive = current_hp > 0.0
	if not is_equal_approx(prev_hp, current_hp) or not is_equal_approx(prev_max_hp, max_hp):
		hp_changed.emit(actor_id, current_hp, max_hp)
	if prev_alive != alive:
		alive_changed.emit(actor_id, alive)


func _sync_components_after_setup() -> void:
	if attribute_component != null:
		# CombatEngine owns battle timing. Disable component auto-process to avoid double ticking.
		attribute_component.set_physics_process(false)
		attribute_component.attribute_set = attr_set

	if inventory_component != null:
		# Battle actors are runtime instances, not save roots.
		inventory_component.save_enabled = false
		inventory_component.ensure_initialized()
		inventory_component.bind_runtime_attribute_set(attr_set)
		if equipment_container != null and inventory_component.has_method("load_container_snapshot"):
			inventory_component.load_container_snapshot(equipment_container)
		elif not equipment_ids.is_empty() and inventory_component.has_method("load_equipment_ids"):
			inventory_component.load_equipment_ids(equipment_ids)
		_sync_runtime_state_from_attributes()


func _on_inventory_component_changed() -> void:
	if inventory_component == null:
		return
	_sync_runtime_state_from_attributes()
