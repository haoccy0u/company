extends RefCounted
class_name ItemDataResolver

const DEFAULT_SEARCH_ROOTS: Array[String] = ["res://data"]
const EQUIP_EFFECT_TAG_PREFIX := "equip_effect:"

static var _item_cache: Dictionary = {}


static func resolve(item_id: StringName, search_roots: Array[String] = []) -> ItemData:
	if item_id.is_empty():
		return null

	var key := String(item_id)
	if _item_cache.has(key):
		return _item_cache[key] as ItemData

	var resolved_roots: Array[String] = search_roots if not search_roots.is_empty() else DEFAULT_SEARCH_ROOTS
	for root_dir in resolved_roots:
		var found: ItemData = _find_item_in_dir_by_id(item_id, root_dir)
		if found != null:
			_item_cache[key] = found
			return found

	return null


static func get_equipment_effects(item: ItemData) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if item == null:
		return rows

	for raw_tag in item.tags:
		var tag_text := String(raw_tag)
		if not tag_text.begins_with(EQUIP_EFFECT_TAG_PREFIX):
			continue

		var parts: PackedStringArray = tag_text.split(":")
		if parts.size() != 4:
			push_warning("ItemDataResolver: invalid equip effect tag=%s | item_id=%s" % [tag_text, String(item.item_id)])
			continue

		var value_text := parts[3]
		if not value_text.is_valid_float():
			push_warning("ItemDataResolver: invalid equip effect value=%s | item_id=%s" % [value_text, String(item.item_id)])
			continue

		rows.append({
			"attr": StringName(parts[2]),
			"op": StringName(parts[1]),
			"value": float(value_text),
		})

	return rows


static func _find_item_in_dir_by_id(item_id: StringName, root_dir: String) -> ItemData:
	if item_id.is_empty():
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
			var nested: ItemData = _find_item_in_dir_by_id(item_id, path)
			if nested != null:
				dir.list_dir_end()
				return nested
			continue

		if not entry_name.ends_with(".tres") and not entry_name.ends_with(".res"):
			continue

		var loaded: Resource = ResourceLoader.load(path)
		if loaded is ItemData and (loaded as ItemData).item_id == item_id:
			dir.list_dir_end()
			return loaded as ItemData

	dir.list_dir_end()
	return null
