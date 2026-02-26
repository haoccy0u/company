extends Resource
class_name PassiveTemplate

@export var passive_id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""

# Data-only placeholders for M3/M4 implementation.
@export var trigger_id: StringName = &""
@export var effect_tags: Array[StringName] = []
@export var params: Dictionary = {}
