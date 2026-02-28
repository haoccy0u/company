extends Resource
class_name PassiveTemplate

const PassiveEffectSpecRef = preload("res://src/expedition_system/actor/behavior/PassiveEffectSpec.gd")

@export var passive_id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""

# Data-only placeholders for M3/M4 implementation.
@export var trigger_id: StringName = &""
@export var effect_tags: Array[StringName] = []
@export var params: Dictionary = {}
@export var effects: Array[Resource] = [] # PassiveEffectSpec[]


func get_effects_for_trigger(filter_trigger_id: StringName) -> Array:
	var rows: Array = []
	for effect in effects:
		if effect == null:
			continue
		if effect.get_script() == PassiveEffectSpecRef and effect.trigger_id == filter_trigger_id:
			rows.append(effect)
	return rows


func get_all_effects() -> Array:
	var rows: Array = []
	for effect in effects:
		if effect != null:
			rows.append(effect)
	return rows
