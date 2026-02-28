class_name RuntimeHpAttribute extends Attribute


func derived_from() -> Array[String]:
	return ["hp_max"]


func custom_compute(operated_value: float, compute_params: Array[Attribute]) -> float:
	var hp_max_value: float = 0.0
	if not compute_params.is_empty() and compute_params[0] != null:
		hp_max_value = maxf(compute_params[0].get_value(), 0.0)
	return clampf(operated_value, 0.0, hp_max_value)


func post_attribute_value_changed(_value: float) -> float:
	var hp_max_attr = attribute_set.find_attribute("hp_max") if attribute_set != null else null
	if hp_max_attr == null:
		return maxf(_value, 0.0)
	return clampf(_value, 0.0, maxf(hp_max_attr.get_value(), 0.0))


func preview_attack_damage(
	attack_power: float,
	defense: float = 0.0,
	outgoing_multiplier: float = 1.0,
	incoming_multiplier: float = 1.0,
	temp_buffs: Array = [],
	defense_ratio: float = 0.5,
	minimum_damage: float = 1.0
) -> Dictionary:
	var raw_damage: float = maxf(attack_power - (defense * defense_ratio), minimum_damage)
	return {
		"raw_damage": raw_damage,
		"final_damage": _resolve_hp_delta(raw_damage, outgoing_multiplier, incoming_multiplier, temp_buffs, minimum_damage),
	}


func preview_scaled_heal(
	flat_amount: float,
	scale_value: float = 0.0,
	scale_ratio: float = 0.0,
	outgoing_multiplier: float = 1.0,
	incoming_multiplier: float = 1.0,
	temp_buffs: Array = [],
	minimum_heal: float = 0.0
) -> float:
	var raw_heal: float = maxf(flat_amount + scale_value * scale_ratio, minimum_heal)
	return _resolve_hp_delta(raw_heal, outgoing_multiplier, incoming_multiplier, temp_buffs, minimum_heal)


func apply_heal_amount(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var before_hp: float = get_value()
	add(amount)
	return get_value() - before_hp


func apply_damage_amount(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var before_hp: float = get_value()
	sub(amount)
	return before_hp - get_value()


func _resolve_hp_delta(
	raw_amount: float,
	outgoing_multiplier: float,
	incoming_multiplier: float,
	temp_buffs: Array,
	minimum_value: float
) -> float:
	if raw_amount <= 0.0:
		return 0.0

	var resolved_value: float = raw_amount
	resolved_value = AttributeModifier.multiply(maxf(outgoing_multiplier, 0.0)).operate(resolved_value)
	resolved_value = AttributeModifier.multiply(maxf(incoming_multiplier, 0.0)).operate(resolved_value)

	for buff in temp_buffs:
		if buff is AttributeBuff:
			resolved_value = buff.operate(resolved_value)

	return maxf(resolved_value, minimum_value)
