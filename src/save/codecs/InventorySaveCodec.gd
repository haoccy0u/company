extends RefCounted
class_name InventorySaveCodec

const SAVE_SCAN_ROOT := "res://data"


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

	var saved_slot_count: int = int(data.get("slot_count", container.slot_count))
	if saved_slot_count >= 0 and saved_slot_count != container.slot_count:
		container.slot_count = saved_slot_count

	for i in range(container.slots.size()):
		var slot: Slot = container.slots[i]
		if slot == null:
			slot = Slot.new()
			container.slots[i] = slot
		slot.clear()

	var slots_variant: Variant = data.get("slots", [])
	if not (slots_variant is Array):
		return true

	var resolve_cache: Dictionary = {}
	var slots_data: Array = slots_variant
	for entry_variant in slots_data:
		if not (entry_variant is Dictionary):
			continue

		var entry: Dictionary = entry_variant
		var index: int = int(entry.get("index", -1))
		if index < 0 or index >= container.slots.size():
			continue

		var item: ItemData = _resolve_saved_item(component, entry, resolve_cache)
		if item == null:
			continue

		var count: int = maxi(int(entry.get("count", 0)), 0)
		if count <= 0:
			continue

		var target_slot: Slot = container.slots[index]
		if target_slot == null:
			target_slot = Slot.new()
			container.slots[index] = target_slot
		target_slot.item = item
		target_slot.count = mini(count, maxi(item.max_stack, 1))

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

	var from_data: ItemData = _find_item_in_dir_by_id(item_id, SAVE_SCAN_ROOT)
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

		var path: String = "%s/%s" % [root_dir, entry_name]
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
