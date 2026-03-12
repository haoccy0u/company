extends Resource
class_name ActorCatalog

@export var actors: Array[ActorDefinition] = []


func find_actor(actor_id: StringName) -> ActorDefinition:
	if actor_id.is_empty():
		return null

	var matches: Array[ActorDefinition] = []
	for actor in actors:
		if actor == null:
			continue
		if actor.actor_id == actor_id:
			matches.append(actor)

	if matches.is_empty():
		return null
	if matches.size() > 1:
		push_error("ActorCatalog.find_actor failed: duplicate actor_id=%s" % String(actor_id))
		return null
	return matches[0]


func has_actor(actor_id: StringName) -> bool:
	return find_actor(actor_id) != null
