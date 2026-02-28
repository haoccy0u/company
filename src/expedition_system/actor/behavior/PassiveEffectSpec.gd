extends Resource
class_name PassiveEffectSpec

@export var effect_id: StringName = &""
@export var trigger_id: StringName = &""
@export var effect_type: StringName = &""
@export var target_rule: StringName = &""

@export var attr_name: StringName = &""
@export var status_id: StringName = &""
@export var required_status_id: StringName = &""

@export var buff: AttributeBuff
@export var params: Dictionary = {}
