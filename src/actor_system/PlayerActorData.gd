extends Resource
class_name PlayerActorData

@export_group("Identity")
@export var player_actor_id: StringName = &""
@export var actor_id: StringName = &""

@export_group("Progression")
@export var level: int = 1
@export var progression_states: Dictionary = {}

@export_group("Loadout")
@export var equipment_ids: Array[StringName] = []
