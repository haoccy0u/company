class_name RuntimeCooldownTotalAttribute extends Attribute


func derived_from() -> Array[String]:
	return ["spd"]


func custom_compute(_operated_value: float, compute_params: Array[Attribute]) -> float:
	var spd_value: float = 1.0
	if not compute_params.is_empty() and compute_params[0] != null:
		spd_value = maxf(compute_params[0].get_value(), 0.1)
	return maxf(1.0 / spd_value, 0.1)


func post_attribute_value_changed(_value: float) -> float:
	return maxf(_value, 0.1)
