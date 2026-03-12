extends RefCounted
class_name InventorySaveCodec

const ITEM_DATA_RESOLVER := preload("res://src/inventory/ItemDataResolver.gd")


static func capture(component: InventoryComponent) -> Dictionary:
	if component == null:
		return {}

	component.ensure_initialized()
	var container: ItemContainer = component.container
	if container == null:
		return {}

	var slots_data: Array[Dictionary] = []
	for i in range(container.slots.size()):
		var slot: Slot = container.slots[i]
		if slot == null or slot.is_empty() or slot.item == null:
			continue
		slots_data.append({
			"index": i,
			"item_id": String(slot.item.item_id),
			"item_path": slot.item.resource_path,
			"count": slot.count
		})

	return {
		"slot_count": container.slot_count,
		"container_id": String(container.item_container_id),
		"slots": slots_data
	}


static func apply(component: InventoryComponent, data: Dictionary) -> bool:
	if component == null or data.is_empty():
		return false

	component.ensure_initialized()
	var container: ItemContainer = component.container
	if container == null:
		return false

	var validation: Dictionary = _validate_and_prepare_updates(component, data)
	if not bool(validation.get("ok", false)):
		return false

	var target_slot_count: int = int(validation.get("slot_count", container.slot_count))
	var prepared_entries: Array = validation.get("entries", [])

	if target_slot_count != container.slot_count:
		container.slot_count = target_slot_count

	for i in range(container.slots.size()):
		var slot: Slot = container.slots[i]
		if slot == null:
			slot = Slot.new()
			container.slots[i] = slot
		slot.clear()

	for prepared_variant in prepared_entries:
		var prepared: Dictionary = prepared_variant
		var index: int = int(prepared.get("index", -1))
		var item: ItemData = prepared.get("item", null) as ItemData
		var count: int = int(prepared.get("count", 0))
		if item == null or count <= 0:
			return false

		var target_slot: Slot = container.slots[index]
		if target_slot == null:
			target_slot = Slot.new()
			container.slots[index] = target_slot
		target_slot.item = item
		target_slot.count = count

	return true


static func _resolve_saved_item(component: InventoryComponent, entry: Dictionary, resolve_cache: Dictionary) -> ItemData:
	var item_id: StringName = StringName(String(entry.get("item_id", "")))
	if not item_id.is_empty() and resolve_cache.has(item_id):
		return resolve_cache[item_id] as ItemData

	var item_path: String = String(entry.get("item_path", ""))
	if not item_path.is_empty() and ResourceLoader.exists(item_path):
		var loaded: Resource = ResourceLoader.load(item_path)
		if loaded is ItemData:
			var from_path: ItemData = loaded
			if not item_id.is_empty():
				resolve_cache[item_id] = from_path
			return from_path

	var from_slots: ItemData = _find_item_in_existing_slots(component, item_id)
	if from_slots != null:
		if not item_id.is_empty():
			resolve_cache[item_id] = from_slots
		return from_slots

	var from_data: ItemData = ITEM_DATA_RESOLVER.resolve(item_id)
	if from_data != null and not item_id.is_empty():
		resolve_cache[item_id] = from_data
	return from_data


static func _find_item_in_existing_slots(component: InventoryComponent, item_id: StringName) -> ItemData:
	if component == null or item_id.is_empty():
		return null

	if component.container != null:
		for slot in component.container.slots:
			if slot != null and slot.item != null and slot.item.item_id == item_id:
				return slot.item

	if component.container_template != null:
		for slot in component.container_template.slots:
			if slot != null and slot.item != null and slot.item.item_id == item_id:
				return slot.item

	return null


static func _validate_and_prepare_updates(component: InventoryComponent, data: Dictionary) -> Dictionary:
	if component == null or data.is_empty():
		return {"ok": false}
	if component.container == null:
		return {"ok": false}

	var target_slot_count: int = int(data.get("slot_count", component.container.slot_count))
	if target_slot_count < 0:
		return {"ok": false}

	var slots_variant: Variant = data.get("slots", [])
	if not (slots_variant is Array):
		return {"ok": false}

	var resolve_cache: Dictionary = {}
	var seen_indices: Dictionary = {}
	var prepared_entries: Array[Dictionary] = []

	var slots_data: Array = slots_variant
	for entry_variant in slots_data:
		if not (entry_variant is Dictionary):
			return {"ok": false}

		var entry: Dictionary = entry_variant
		var index: int = int(entry.get("index", -1))
		if index < 0 or index >= target_slot_count:
			return {"ok": false}
		if seen_indices.has(index):
			return {"ok": false}
		seen_indices[index] = true

		var item: ItemData = _resolve_saved_item(component, entry, resolve_cache)
		if item == null:
			return {"ok": false}

		var raw_count: int = int(entry.get("count", 0))
		if raw_count <= 0:
			return {"ok": false}

		prepared_entries.append({
			"index": index,
			"item": item,
			"count": mini(raw_count, maxi(item.max_stack, 1)),
		})

	return {
		"ok": true,
		"slot_count": target_slot_count,
		"entries": prepared_entries,
	}
