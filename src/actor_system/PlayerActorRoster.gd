extends Resource
class_name PlayerActorRoster

@export var players: Array[Resource] = []


func find_player_actor(player_actor_id: StringName) -> Resource:
	if player_actor_id.is_empty():
		return null

	var matches: Array[Resource] = []
	for player in players:
		if player == null:
			continue
		if player.player_actor_id == player_actor_id:
			matches.append(player)

	if matches.is_empty():
		return null
	if matches.size() > 1:
		push_error("PlayerActorRoster.find_player_actor failed: duplicate player_actor_id=%s" % String(player_actor_id))
		return null
	return matches[0]


func has_player_actor(player_actor_id: StringName) -> bool:
	return find_player_actor(player_actor_id) != null
