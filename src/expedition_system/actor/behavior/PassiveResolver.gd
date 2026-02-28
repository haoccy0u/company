extends RefCounted
class_name PassiveResolver

const PassiveTemplateRef = preload("res://src/expedition_system/battle/PassiveTemplate.gd")
const DEFAULT_SEARCH_ROOTS: Array[String] = ["res://data"]

static var _passive_cache: Dictionary = {}
static var _known_status_ids: Dictionary = {}


static func has_passive(passive_ids: Array[StringName], passive_id: StringName) -> bool:
	for pid in passive_ids:
		if pid == passive_id:
			return true
	return false


static func get_passive(passive_id: StringName):
	var key := String(passive_id)
	if _passive_cache.has(key):
		return _passive_cache[key]

	for root_dir in DEFAULT_SEARCH_ROOTS:
		var res = _find_passive_in_dir(passive_id, root_dir)
		if res != null:
			_passive_cache[key] = res
			_register_status_ids(res)
			return res

	push_warning("PassiveResolver: failed to resolve passive_id=%s in roots=%s" % [key, DEFAULT_SEARCH_ROOTS])
	return null


static func get_passive_params(passive_ids: Array[StringName], passive_id: StringName) -> Dictionary:
	if not has_passive(passive_ids, passive_id):
		return {}
	var passive_def = get_passive(passive_id)
	if passive_def == null:
		return {}
	return passive_def.params if passive_def.params is Dictionary else {}


static func get_effects(passive_ids: Array[StringName], trigger_id: StringName) -> Array:
	var rows: Array = []
	for passive_id in passive_ids:
		var passive_def = get_passive(passive_id)
		if passive_def == null or not passive_def.has_method("get_effects_for_trigger"):
			continue
		for effect in passive_def.get_effects_for_trigger(trigger_id):
			if effect != null:
				rows.append(effect)
	return rows


static func get_known_status_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for key in _known_status_ids.keys():
		ids.append(StringName(str(key)))
	return ids


static func _register_status_ids(passive_def) -> void:
	if passive_def == null or not passive_def.has_method("get_all_effects"):
		return
	for effect in passive_def.get_all_effects():
		if effect == null:
			continue
		if effect.status_id != StringName():
			_known_status_ids[String(effect.status_id)] = true


static func _find_passive_in_dir(passive_id: StringName, root_dir: String):
	if passive_id.is_empty():
		return null

	var dir: DirAccess = DirAccess.open(root_dir)
	if dir == null:
		return null

	dir.list_dir_begin()
	while true:
		var entry_name: String = dir.get_next()
		if entry_name.is_empty():
			break
		if entry_name.begins_with("."):
			continue

		var path := "%s/%s" % [root_dir, entry_name]
		if dir.current_is_dir():
			var nested = _find_passive_in_dir(passive_id, path)
			if nested != null:
				dir.list_dir_end()
				return nested
			continue

		if not entry_name.ends_with(".tres") and not entry_name.ends_with(".res"):
			continue

		var loaded: Resource = ResourceLoader.load(path)
		if loaded is PassiveTemplateRef and (loaded as PassiveTemplate).passive_id == passive_id:
			dir.list_dir_end()
			return loaded

	dir.list_dir_end()
	return null
