class_name SquadConfig extends Resource

@export var squad_id: StringName
@export var members: Array[MemberConfig] = []
@export var formation_slots: Array[int] = []
@export var strategy_tag: StringName


func get_member_count() -> int:
	return members.size()


func is_empty() -> bool:
	return members.is_empty()
