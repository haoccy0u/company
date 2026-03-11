class_name SquadRuntime extends Resource

const ActorDefResolverRef = preload("res://src/expedition_system/actor/ActorDefResolver.gd")

@export var source_squad_id: StringName
@export var members: Array[MemberRuntime] = []
@export var shared_res: Dictionary = {}
@export var long_states: Dictionary = {}


func find_member(member_id: StringName) -> MemberRuntime:
	for member in members:
		if member != null and member.member_id == member_id:
			return member
	return null


func find_member_by_unit_uid(unit_uid: StringName) -> MemberRuntime:
	if unit_uid.is_empty():
		return null
	for member in members:
		if member != null and member.unit_uid == unit_uid:
			return member
	return null


func has_living_members() -> bool:
	for member in members:
		if member != null and member.is_usable():
			return true
	return false


func make_run_instance() -> SquadRuntime:
	if members.is_empty():
		push_error("SquadRuntime.make_run_instance failed: members is empty")
		return null

	var seen_member_ids: Dictionary = {}
	var seen_unit_uids: Dictionary = {}
	for member in members:
		if member == null:
			push_error("SquadRuntime.make_run_instance failed: member is null")
			return null
		if member.member_id.is_empty():
			push_error("SquadRuntime.make_run_instance failed: member_id is empty")
			return null
		if member.actor_id.is_empty():
			push_error("SquadRuntime.make_run_instance failed: actor_id is empty | member_id=%s" % String(member.member_id))
			return null

		var member_key := String(member.member_id)
		if seen_member_ids.has(member_key):
			push_error("SquadRuntime.make_run_instance failed: duplicate member_id=%s" % member_key)
			return null
		seen_member_ids[member_key] = true

		if not member.unit_uid.is_empty():
			var unit_uid_key := String(member.unit_uid)
			if seen_unit_uids.has(unit_uid_key):
				push_error("SquadRuntime.make_run_instance failed: duplicate unit_uid=%s" % unit_uid_key)
				return null
			seen_unit_uids[unit_uid_key] = true

		var actor_def := ActorDefResolverRef.resolve(member.actor_id)
		if actor_def == null:
			push_error("SquadRuntime.make_run_instance failed: actor def not found | member_id=%s actor_id=%s" % [
				String(member.member_id),
				String(member.actor_id),
			])
			return null

	var run_any := duplicate(true)
	if not (run_any is SquadRuntime):
		push_error("SquadRuntime.make_run_instance failed: duplicate type mismatch")
		return null

	var run := run_any as SquadRuntime
	run.shared_res = {}
	run.long_states = {}

	for member in run.members:
		if member == null:
			continue

		_ensure_member_unit_uid(run.source_squad_id, member)
		var actor_max_hp: float = ActorDefResolverRef.get_default_max_hp(member.actor_id)
		if actor_max_hp <= 0.0:
			push_error("SquadRuntime.make_run_instance failed: invalid actor max hp | member_id=%s actor_id=%s" % [
				String(member.member_id),
				String(member.actor_id),
			])
			return null

		member.max_hp = actor_max_hp
		member.set_current_hp(member.get_init_hp(member.max_hp))
		member.injury_flags = {}
		member.resources = {}
		member.equipment_ids = member.equipment_ids.duplicate()
		if member.equipment_container != null:
			member.equipment_container = member.equipment_container.duplicate(true)

	return run


func get_shared(key: StringName, fallback: Variant = null) -> Variant:
	return shared_res.get(key, fallback)


func set_shared(key: StringName, value: Variant) -> void:
	shared_res[key] = value


func inc_shared_int(key: StringName, delta: int = 1) -> int:
	var next_value: int = int(shared_res.get(key, 0)) + delta
	shared_res[key] = next_value
	return next_value


func _ensure_member_unit_uid(source_id: StringName, member: MemberRuntime) -> void:
	if member == null or not member.unit_uid.is_empty():
		return
	if not source_id.is_empty():
		member.unit_uid = StringName("unit_%s_%s" % [String(source_id), String(member.member_id)])
		return
	member.unit_uid = StringName("unit_%s" % String(member.member_id))
