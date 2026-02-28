class_name RuntimeDamageAttribute extends Attribute


func post_attribute_value_changed(_value: float) -> float:
	return maxf(_value, 0.0)
