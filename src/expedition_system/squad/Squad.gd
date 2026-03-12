extends Node
class_name Squad

const ActorCatalogRef = preload("res://src/actor_system/ActorCatalog.gd")
const SquadMemberRef = preload("res://src/expedition_system/squad/SquadMember.gd")

@export var source_squad_id: StringName = &"expedition_runtime_squad"
@export var members_root_path: NodePath = ^"Members"
@export var member_scene: PackedScene

var shared_res: Dictionary = {}
var long_states: Dictionary = {}


func build_from_roster_state(
	player_roster_state: Node,
	selected_player_actor_ids: Array[StringName],
	actor_catalog: Resource
) -> bool:
	if player_roster_state == null or not player_roster_state.has_method("find_player_actor"):
		push_error("Squad.build_from_roster_state failed: invalid player_roster_state")
		return false
	if actor_catalog == null or actor_catalog.get_script() != ActorCatalogRef:
		push_error("Squad.build_from_roster_state failed: invalid actor_catalog")
		return false
	if selected_player_actor_ids.is_empty():
		push_error("Squad.build_from_roster_state failed: selected_player_actor_ids is empty")
		return false
	if member_scene == null:
		push_error("Squad.build_from_roster_state failed: member_scene is null")
		return false

	var members_root := _get_members_root()
	if members_root == null:
		push_error("Squad.build_from_roster_state failed: Members root missing")
		return false

	_clear_members()
	shared_res = {}
	long_states = {}

	var seen_player_actor_ids: Dictionary = {}
	for i in range(selected_player_actor_ids.size()):
		var player_actor_id: StringName = selected_player_actor_ids[i]
		if player_actor_id.is_empty():
			push_error("Squad.build_from_roster_state failed: selected player_actor_id is empty")
			_clear_members()
			return false
		if seen_player_actor_ids.has(player_actor_id):
			push_error("Squad.build_from_roster_state failed: duplicate player_actor_id=%s" % String(player_actor_id))
			_clear_members()
			return false
		seen_player_actor_ids[player_actor_id] = true

		var player_actor: PlayerActorData = player_roster_state.call("find_player_actor", player_actor_id) as PlayerActorData
		if player_actor == null:
			push_error("Squad.build_from_roster_state failed: player actor not found | player_actor_id=%s" % String(player_actor_id))
			_clear_members()
			return false

		var actor_def = actor_catalog.find_actor(player_actor.actor_id)
		if actor_def == null:
			push_error("Squad.build_from_roster_state failed: actor def not found | actor_id=%s player_actor_id=%s" % [
				String(player_actor.actor_id),
				String(player_actor_id),
			])
			_clear_members()
			return false

		var member_node: Node = member_scene.instantiate()
		if member_node == null or member_node.get_script() != SquadMemberRef:
			push_error("Squad.build_from_roster_state failed: invalid member scene root script")
			_clear_members()
			return false
		members_root.add_child(member_node)

		var member := member_node as SquadMember
		if member == null:
			push_error("Squad.build_from_roster_state failed: member cast failed")
			_clear_members()
			return false

		var ok := member.initialize_from_player(player_actor, actor_def, source_squad_id, i)
		if not ok:
			push_error("Squad.build_from_roster_state failed: member initialization failed")
			_clear_members()
			return false

	return true


func find_member(member_id: StringName) -> SquadMember:
	for member in get_members():
		if member.member_id == member_id:
			return member
	return null


func find_member_by_unit_uid(unit_uid: StringName) -> SquadMember:
	if unit_uid.is_empty():
		return null
	for member in get_members():
		if member.unit_uid == unit_uid:
			return member
	return null


func get_members() -> Array[SquadMember]:
	var out: Array[SquadMember] = []
	var members_root := _get_members_root()
	if members_root == null:
		return out
	for child in members_root.get_children():
		if child is SquadMember:
			out.append(child as SquadMember)
	return out


func has_living_members() -> bool:
	for member in get_members():
		if member.is_usable():
			return true
	return false


func get_shared(key: StringName, fallback: Variant = null) -> Variant:
	return shared_res.get(key, fallback)


func set_shared(key: StringName, value: Variant) -> void:
	shared_res[key] = value


func inc_shared_int(key: StringName, delta: int = 1) -> int:
	var next_value: int = int(shared_res.get(key, 0)) + delta
	shared_res[key] = next_value
	return next_value


func export_run_snapshot() -> Dictionary:
	var rows: Array[Dictionary] = []
	for member in get_members():
		rows.append(member.to_snapshot_dict())
	return {
		"source_squad_id": source_squad_id,
		"shared_res": shared_res.duplicate(true),
		"long_states": long_states.duplicate(true),
		"members": rows,
	}


func _get_members_root() -> Node:
	return get_node_or_null(members_root_path)


func _clear_members() -> void:
	var members_root := _get_members_root()
	if members_root == null:
		return
	for child in members_root.get_children():
		members_root.remove_child(child)
		child.queue_free()
