extends RefCounted
class_name ActorEntry

const AttributeSetRef = preload("res://src/attribute_framework/AttributeSet.gd")

var actor_id: StringName = &""
var camp: StringName = &""
var member_id: StringName = &""
var actor_template_id: StringName = &""

var hp: float = 0.0
var max_hp: float = 0.0
var base_attr_set: AttributeSet

var ai_id: StringName = &""
var action_ids: Array[StringName] = []
var passive_ids: Array[StringName] = []
var equipment_container: ItemContainer
var equipment_ids: Array[StringName] = []

var extra: Dictionary = {}


func to_dict() -> Dictionary:
	var data: Dictionary = {
		"actor_id": actor_id,
		"camp": camp,
		"member_id": member_id,
		"actor_template_id": actor_template_id,
		"hp": hp,
		"max_hp": max_hp,
		"has_base_attr_set": base_attr_set != null,
		"ai_id": ai_id,
		"action_ids": action_ids.duplicate(),
		"passive_ids": passive_ids.duplicate(),
		"has_equipment_container": equipment_container != null,
		"equipment_ids": equipment_ids.duplicate(),
	}

	for key in extra.keys():
		data[key] = extra[key]

	return data
