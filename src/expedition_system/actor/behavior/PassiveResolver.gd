extends RefCounted
class_name PassiveResolver

const PASSIVE_RESOURCE_DIR := "res://data/devtest/expedition/passives/"

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

	var path := "%s%s.tres" % [PASSIVE_RESOURCE_DIR, key]
	var res = load(path)
	if res != null and res is Resource:
		_passive_cache[key] = res
		_register_status_ids(res)
		return res
	push_warning("PassiveResolver: failed to load passive_id=%s | path=%s" % [key, path])
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
