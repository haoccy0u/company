class_name SquadRuntime extends Resource

@export var source_squad_id: StringName
@export var members: Array[MemberRuntime] = []
@export var shared_res: Dictionary = {}
@export var long_states: Dictionary = {}


func find_member(member_id: StringName) -> MemberRuntime:
	for member in members:
		if member != null and member.member_id == member_id:
			return member
	return null


func has_living_members() -> bool:
	for member in members:
		if member != null and member.is_usable():
			return true
	return false
