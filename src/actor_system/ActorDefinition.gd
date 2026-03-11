extends Resource
class_name ActorDefinition

@export_group("Index And Basic Info")
@export var actor_id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var tags: Array[StringName] = []

@export_group("Primary Stats")
@export var strength: float = 0.0
@export var constitution: float = 0.0
@export var dexterity: float = 0.0
@export var perception: float = 0.0
@export var will: float = 0.0
@export var intelligence: float = 0.0
@export var luck: float = 0.0

@export_group("Extensions")
@export_subgroup("Expedition")
@export var skill_ids: Array[StringName] = []
@export var passive_ids: Array[StringName] = []
@export var ai_profile_id: StringName = &""
@export var capture_profile_id: StringName = &""

