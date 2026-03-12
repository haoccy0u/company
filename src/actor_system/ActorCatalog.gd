@tool
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


func validate_catalog() -> Dictionary:
	var errors: PackedStringArray = []
	var valid_count := 0
	var seen_actor_ids: Dictionary = {}

	for i in range(actors.size()):
		var actor := actors[i]
		if actor == null:
			errors.append("index %d: null actor entry" % i)
			continue

		if actor.actor_id.is_empty():
			errors.append("index %d: actor_id is empty" % i)
			continue

		if seen_actor_ids.has(actor.actor_id):
			var first_index: int = int(seen_actor_ids[actor.actor_id])
			errors.append("index %d: duplicate actor_id=%s (first=%d)" % [i, String(actor.actor_id), first_index])
			continue
		seen_actor_ids[actor.actor_id] = i

		var actor_path := actor.resource_path
		if not actor_path.is_empty() and not ResourceLoader.exists(actor_path):
			errors.append("index %d: missing actor resource path=%s" % [i, actor_path])
			continue

		valid_count += 1

	return {
		"ok": errors.is_empty(),
		"total_count": actors.size(),
		"valid_count": valid_count,
		"error_count": errors.size(),
		"errors": errors,
	}


func repair_catalog() -> Dictionary:
	var removed: PackedStringArray = []
	var cleaned: Array[ActorDefinition] = []
	var seen_actor_ids: Dictionary = {}

	for i in range(actors.size()):
		var actor := actors[i]
		if actor == null:
			removed.append("index %d removed: null actor entry" % i)
			continue

		if actor.actor_id.is_empty():
			removed.append("index %d removed: actor_id is empty" % i)
			continue

		if seen_actor_ids.has(actor.actor_id):
			var first_index: int = int(seen_actor_ids[actor.actor_id])
			removed.append("index %d removed: duplicate actor_id=%s (first=%d)" % [i, String(actor.actor_id), first_index])
			continue

		var actor_path := actor.resource_path
		if not actor_path.is_empty() and not ResourceLoader.exists(actor_path):
			removed.append("index %d removed: missing actor resource path=%s" % [i, actor_path])
			continue

		seen_actor_ids[actor.actor_id] = i
		cleaned.append(actor)

	actors = cleaned
	var report := validate_catalog()
	report["removed_count"] = removed.size()
	report["removed"] = removed
	return report
