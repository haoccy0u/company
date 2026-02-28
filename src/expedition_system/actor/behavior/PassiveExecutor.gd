extends RefCounted
class_name PassiveExecutor

const PassiveResolverRef = preload("res://src/expedition_system/actor/behavior/PassiveResolver.gd")

const TRIGGER_ON_ATTACK_COMPUTE: StringName = &"on_attack_compute"
const TRIGGER_ON_ATTACK_HIT: StringName = &"on_attack_hit"

const EFFECT_APPLY_BUFF_TO_TARGET_ATTR: StringName = &"apply_buff_to_target_attr"
const EFFECT_DAMAGE_BUFF_IF_TARGET_STATUS: StringName = &"damage_buff_if_target_status"
const EFFECT_HEAL_ALLY: StringName = &"heal_ally"

const TARGET_PRIMARY_TARGET: StringName = &"primary_target"
const TARGET_LOWEST_HP_PERCENT_ALLY: StringName = &"lowest_hp_percent_ally"


static func build_attack_damage_modifiers(actor, target) -> Dictionary:
	var buffs: Array = []
	var effect_ids: Array[StringName] = []
	if actor == null or target == null:
		return {"buffs": buffs, "effect_ids": effect_ids}

	for effect in PassiveResolverRef.get_effects(actor.passive_ids, TRIGGER_ON_ATTACK_COMPUTE):
		if effect == null:
			continue
		if effect.effect_type != EFFECT_DAMAGE_BUFF_IF_TARGET_STATUS:
			continue
		if effect.target_rule != TARGET_PRIMARY_TARGET:
			continue
		if effect.required_status_id != StringName() and not target.has_status(effect.required_status_id):
			continue
		var buff = _duplicate_buff_template(effect.buff)
		if buff == null:
			continue
		if effect.effect_id != StringName() and buff.buff_name.is_empty():
			buff.buff_name = String(effect.effect_id)
		buffs.append(buff)
		effect_ids.append(effect.effect_id)

	return {"buffs": buffs, "effect_ids": effect_ids}


static func build_on_attack_effects(actor, primary_target, allies: Array) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if actor == null or primary_target == null:
		return rows

	for effect in PassiveResolverRef.get_effects(actor.passive_ids, TRIGGER_ON_ATTACK_HIT):
		if effect == null:
			continue
		match effect.effect_type:
			EFFECT_APPLY_BUFF_TO_TARGET_ATTR:
				var status_row := _build_status_apply_row(actor, primary_target, effect)
				if not status_row.is_empty():
					rows.append(status_row)
			EFFECT_HEAL_ALLY:
				var heal_row := _build_heal_row(actor, allies, effect)
				if not heal_row.is_empty():
					rows.append(heal_row)
	return rows


static func build_tracked_status_snapshot(actor) -> Dictionary:
	var snapshot: Dictionary = {}
	if actor == null:
		return snapshot
	for status_id in PassiveResolverRef.get_known_status_ids():
		snapshot[String(status_id)] = actor.has_status(status_id)
	return snapshot


static func _build_status_apply_row(actor, primary_target, effect) -> Dictionary:
	if primary_target == null or effect.target_rule != TARGET_PRIMARY_TARGET:
		return {}
	var buff = _duplicate_buff_template(effect.buff)
	if buff == null:
		return {}
	return {
		"type": &"status_apply",
		"target": primary_target,
		"status_id": effect.status_id,
		"attr_name": effect.attr_name,
		"buff": buff,
		"duration": buff.duration,
		"multiplier": buff.value,
		"passive_id": _find_source_passive_id(actor, effect),
		"effect_id": effect.effect_id,
	}


static func _build_heal_row(actor, allies: Array, effect) -> Dictionary:
	var heal_rule: StringName = effect.target_rule if effect.target_rule != StringName() else TARGET_LOWEST_HP_PERCENT_ALLY
	var ally = _select_heal_target(allies, heal_rule)
	if ally == null:
		return {}

	var params: Dictionary = effect.params if effect.params is Dictionary else {}
	var heal_flat: float = float(params.get("heal_amount_flat", 8.0))
	var heal_scale_attr: StringName = StringName(str(params.get("heal_scale_attr", "atk")))
	var heal_scale_ratio: float = float(params.get("heal_scale_ratio", 0.2))
	var scale_value: float = actor.get_attr_value(heal_scale_attr, 0.0)
	var raw_heal: float = maxf(heal_flat + scale_value * heal_scale_ratio, 0.0)
	var heal_amount: float = maxf(actor.resolve_heal_amount(raw_heal, ally.get_attr_value(&"heal_in_mul", 1.0)), 1.0)
	return {
		"type": &"heal",
		"target": ally,
		"amount": heal_amount,
		"heal_target_rule": heal_rule,
		"passive_id": _find_source_passive_id(actor, effect),
		"effect_id": effect.effect_id,
	}


static func _select_heal_target(allies: Array, heal_rule: StringName):
	var resolved_rule: StringName = heal_rule
	if resolved_rule != TARGET_LOWEST_HP_PERCENT_ALLY:
		resolved_rule = TARGET_LOWEST_HP_PERCENT_ALLY
	var best = null
	var best_ratio: float = 2.0
	for ally in allies:
		if ally == null or not ally.is_usable():
			continue
		var ratio: float = ally.get_hp_ratio()
		if ratio < best_ratio:
			best_ratio = ratio
			best = ally
	return best


static func _duplicate_buff_template(buff_template: AttributeBuff):
	if buff_template == null:
		return null
	return buff_template.duplicate_buff()


static func _find_source_passive_id(actor, effect) -> StringName:
	if actor == null or effect == null:
		return &""
	for passive_id in actor.passive_ids:
		var passive_def = PassiveResolverRef.get_passive(passive_id)
		if passive_def == null or not passive_def.has_method("get_all_effects"):
			continue
		for item in passive_def.get_all_effects():
			if item == effect:
				return passive_id
	return &""
