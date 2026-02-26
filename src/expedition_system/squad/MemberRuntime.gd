class_name MemberRuntime extends Resource

const AttributeSetRef = preload("res://src/attribute_framework/AttributeSet.gd")

@export var member_id: StringName
@export var actor_template_id: StringName
@export var equipment_ids: Array[StringName] = []
@export var action_ids: Array[StringName] = []
@export var passive_ids: Array[StringName] = []
@export var ai_id: StringName
@export var base_attr_set: AttributeSet

@export var alive: bool = true
@export var current_hp: float = 0.0
@export var max_hp: float = 0.0

@export var injury_flags: Dictionary = {}
@export var resources: Dictionary = {}


func is_usable() -> bool:
	return alive and current_hp > 0.0
