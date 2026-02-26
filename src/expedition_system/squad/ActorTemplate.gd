class_name ActorTemplate extends Resource

@export var template_id: StringName
@export var display_name: String = ""
@export var base_attr_set: AttributeSet

@export var action_ids: Array[StringName] = []
@export var passive_ids: Array[StringName] = []
@export var ai_id: StringName = &"basic_auto"
@export var tags: Dictionary = {}


func get_base_attr_value(attr_name: StringName, fallback: float = 0.0) -> float:
	if base_attr_set == null:
		return fallback

	var key := String(attr_name)
	if base_attr_set.attributes_runtime_dict.has(key):
		var attr := base_attr_set.attributes_runtime_dict[key]
		if attr != null:
			return float(attr.get_base_value())
	return fallback
