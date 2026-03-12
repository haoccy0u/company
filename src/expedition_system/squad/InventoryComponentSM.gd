extends InventoryComponent
class_name InventoryComponentSM

signal equipment_effects_changed(effects: Dictionary)
signal equipment_effects_invalid(reason: String)

const EQUIP_EFFECT_TAG_PREFIX := "equip_effect:"
const SUPPORTED_OPERATIONS: Dictionary = {
	&"add": true,
	&"sub": true,
	&"mult": true,
	&"div": true,
}

@export var search_roots: Array[String] = []

var _equipment_ids: Array[StringName] = []
var _cached_effects: Dictionary = {}


func set_equipment_ids(ids: Array[StringName]) -> bool:
	_equipment_ids = ids.duplicate()

	var parse_result := _parse_equipment_effects(_equipment_ids)
	if not bool(parse_result.get("ok", false)):
		var reason := String(parse_result.get("reason", "invalid_equipment_effects"))
		equipment_effects_invalid.emit(reason)
		return false

	var effects = parse_result.get("effects", {}) as Dictionary
	_cached_effects = effects.duplicate(true)
	equipment_effects_changed.emit(_cached_effects.duplicate(true))
	notify_changed()
	return true


func get_equipment_ids() -> Array[StringName]:
	return _equipment_ids.duplicate()


func build_equipment_effects() -> Dictionary:
	var parse_result := _parse_equipment_effects(_equipment_ids)
	if not bool(parse_result.get("ok", false)):
		var reason := String(parse_result.get("reason", "invalid_equipment_effects"))
		equipment_effects_invalid.emit(reason)
		return {}
	var effects = parse_result.get("effects", {}) as Dictionary
	_cached_effects = effects.duplicate(true)
	return _cached_effects.duplicate(true)


func _parse_equipment_effects(ids: Array[StringName]) -> Dictionary:
	var effects_by_attr: Dictionary = {}

	for item_index in range(ids.size()):
		var item_id: StringName = ids[item_index]
		if item_id.is_empty():
			return {
				"ok": false,
				"reason": "InventoryComponentSM: equipment id is empty",
			}

		var item: ItemData = ItemDataResolver.resolve(item_id, search_roots)
		if item == null:
			return {
				"ok": false,
				"reason": "InventoryComponentSM: item not found | item_id=%s" % String(item_id),
			}

		var parsed_rows_result := _parse_item_effect_rows(item)
		if not bool(parsed_rows_result.get("ok", false)):
			var reason := String(parsed_rows_result.get("reason", "invalid_equip_tag"))
			return {
				"ok": false,
				"reason": "%s | item_id=%s" % [reason, String(item_id)],
			}

		var rows = parsed_rows_result.get("rows", []) as Array
		for row_index in range(rows.size()):
			var row = rows[row_index] as Dictionary
			var attr_name := row.get("attr", &"") as StringName
			var op := row.get("op", &"") as StringName
			var value := float(row.get("value", 0.0))
			var buff_name := StringName("equip:%s:%d:%s:%s:%d" % [
				String(item_id),
				item_index,
				String(attr_name),
				String(op),
				row_index,
			])

			if not effects_by_attr.has(attr_name):
				effects_by_attr[attr_name] = []
			var grouped_rows = effects_by_attr[attr_name] as Array
			grouped_rows.append({
				"op": op,
				"value": value,
				"buff_name": buff_name,
				"source_item_id": item_id,
			})

	return {
		"ok": true,
		"effects": effects_by_attr,
	}


func _parse_item_effect_rows(item: ItemData) -> Dictionary:
	var rows: Array[Dictionary] = []
	if item == null:
		return {
			"ok": false,
			"reason": "InventoryComponentSM: item is null",
		}

	for raw_tag in item.tags:
		var tag_text := String(raw_tag)
		if not tag_text.begins_with(EQUIP_EFFECT_TAG_PREFIX):
			continue

		var parts: PackedStringArray = tag_text.split(":")
		if parts.size() != 4:
			return {
				"ok": false,
				"reason": "InventoryComponentSM: invalid equip effect tag format=%s" % tag_text,
			}

		var op := StringName(parts[1].to_lower())
		if not SUPPORTED_OPERATIONS.has(op):
			return {
				"ok": false,
				"reason": "InventoryComponentSM: unsupported equip operation=%s" % String(op),
			}

		var attr_name := StringName(parts[2])
		if attr_name.is_empty():
			return {
				"ok": false,
				"reason": "InventoryComponentSM: empty equip attribute name",
			}

		var value_text := parts[3]
		if not value_text.is_valid_float():
			return {
				"ok": false,
				"reason": "InventoryComponentSM: invalid equip value=%s" % value_text,
			}

		rows.append({
			"op": op,
			"attr": attr_name,
			"value": float(value_text),
		})

	return {
		"ok": true,
		"rows": rows,
	}
