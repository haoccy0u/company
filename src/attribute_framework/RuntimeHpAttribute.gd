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
