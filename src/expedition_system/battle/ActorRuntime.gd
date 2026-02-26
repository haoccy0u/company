extends RefCounted
class_name ActorRuntime

const ActorResultRef = preload("res://src/expedition_system/battle/ActorResult.gd")
const AttributeBuffRef = preload("res://src/attribute_framework/AttributeBuff.gd")

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
var equipment_ids: Array[StringName] = []

var tags: Dictionary = {}


static func from_entry(entry):
	if entry == null:
		return null

	var rt = new()
	rt.actor_id = entry.actor_id
	rt.camp = entry.camp
	rt.member_id = entry.member_id
	rt.actor_template_id = entry.actor_template_id
	rt.attr_set = entry.base_attr_set.duplicate(true) if entry.base_attr_set != null else null
	rt.max_hp = maxf(rt.get_attr_value(&"hp_max", float(entry.max_hp)), 0.0)
	rt.current_hp = clampf(float(entry.hp), 0.0, rt.max_hp)
	rt.alive = rt.current_hp > 0.0
	rt.cooldown_total = rt._compute_cooldown_total_from_spd()
	rt.cooldown_remaining = rt.cooldown_total
	rt.ai_id = entry.ai_id
	rt.action_ids = entry.action_ids.duplicate()
	rt.passive_ids = entry.passive_ids.duplicate()
	rt.equipment_ids = entry.equipment_ids.duplicate()
	rt.tags = entry.extra.duplicate(true)
	return rt


func is_usable() -> bool:
	return alive and current_hp > 0.0


func tick(delta: float) -> void:
	if attr_set != null:
		attr_set.run_process(delta)
	if not alive:
		return
	cooldown_remaining = maxf(cooldown_remaining - maxf(delta, 0.0), 0.0)


func is_ready() -> bool:
	return is_usable() and cooldown_remaining <= 0.0


func reset_cooldown() -> void:
	cooldown_total = _compute_cooldown_total_from_spd()
	cooldown_remaining = cooldown_total


func get_attr_value(attr_name: StringName, fallback: float = 0.0) -> float:
	if attr_set == null:
		return fallback
	var key := String(attr_name)
	if attr_set.attributes_runtime_dict.has(key):
		var attr = attr_set.attributes_runtime_dict[key]
		if attr != null:
			return float(attr.get_value())
	return fallback


func get_attr_base_value(attr_name: StringName, fallback: float = 0.0) -> float:
	if attr_set == null:
		return fallback
	var key := String(attr_name)
	if attr_set.attributes_runtime_dict.has(key):
		var attr = attr_set.attributes_runtime_dict[key]
		if attr != null:
			return float(attr.get_base_value())
	return fallback


func add_multiplicative_buff(attr_name: StringName, multiplier: float, buff_name: StringName, duration_sec: float) -> bool:
	if attr_set == null:
		return false
	var attr = attr_set.find_attribute(String(attr_name))
	if attr == null:
		return false
	var buff = AttributeBuffRef.mult(multiplier, String(buff_name))
	buff.set_duration(duration_sec)
	attr.add_buff(buff)
	return true


func has_named_buff(attr_name: StringName, buff_name: StringName) -> bool:
	if attr_set == null:
		return false
	var attr = attr_set.find_attribute(String(attr_name))
	if attr == null:
		return false
	return attr.find_buff(String(buff_name)) != null


func heal(amount: float) -> float:
	if amount <= 0.0 or not alive:
		return 0.0
	var before_hp: float = current_hp
	current_hp = clampf(current_hp + amount, 0.0, max_hp)
	alive = current_hp > 0.0
	return current_hp - before_hp


func take_damage(amount: float) -> float:
	if amount <= 0.0 or not alive:
		return 0.0
	var before_hp: float = current_hp
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
		"equipment_ids": equipment_ids.duplicate(),
		"tags": tags.duplicate(true),
	}


func _compute_cooldown_total_from_spd() -> float:
	var spd: float = maxf(get_attr_value(&"spd", 1.0), 0.1)
	return maxf(1.0 / spd, 0.1)
