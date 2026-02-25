class_name ActorTemplate extends Resource

@export var template_id: StringName
@export var max_hp: float = 100.0

@export var action_ids: Array[StringName] = []
@export var passive_ids: Array[StringName] = []
@export var ai_id: StringName = &"basic_auto"
