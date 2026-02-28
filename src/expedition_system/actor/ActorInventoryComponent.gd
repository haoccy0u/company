extends InventoryComponent
class_name ActorInventoryComponent

const ItemDataRef = preload("res://src/inventory/ItemData.gd")
const ItemDataResolverRef = preload("res://src/inventory/ItemDataResolver.gd")
const AttributeBuffRef = preload("res://src/attribute_framework/AttributeBuff.gd")

const EQUIP_BUFF_PREFIX := "equip::"

var runtime_attribute_set: AttributeSet = null

var _placeholder_items: Dictionary = {} # item_id(String) -> ItemData
var _applied_effects: Array = [] # [{ "attr": Attribute, "buff": AttributeBuff }]
var _suppress_rebuild: bool = false


func _ready() -> void:
	super._ready()
	if not changed.is_connected(_on_inventory_changed):
		changed.connect(_on_inventory_changed)


func bind_runtime_attribute_set(attribute_set: AttributeSet) -> void:
	runtime_attribute_set = attribute_set
	rebuild_equipment_effects()


func load_container_snapshot(snapshot: ItemContainer) -> void:
	_suppress_rebuild = true
	if snapshot != null:
		container = snapshot.duplicate(true) as ItemContainer
	else:
		container = null
	ensure_initialized()
	_suppress_rebuild = false
	notify_changed()


func get_container_snapshot() -> ItemContainer:
	ensure_initialized()
	return container.duplicate(true) as ItemContainer if container != null else null


func load_equipment_ids(equipment_ids: Array[StringName]) -> void:
	ensure_initialized()
	_suppress_rebuild = true
	_clear_slots()

	var slot_index: int = 0
	for equip_id in equipment_ids:
		if equip_id.is_empty():
			continue
		if slot_index >= container.slots.size():
			break

		var item := _resolve_or_make_item(equip_id)
		var slot := container.slots[slot_index]
		if slot != null:
			slot.clear()
			slot.item = item
			slot.count = 1
			slot_index += 1

	_suppress_rebuild = false
	notify_changed()


func collect_equipped_item_ids() -> Array[StringName]:
	ensure_initialized()
	var out: Array[StringName] = []
	for slot in container.slots:
		if slot == null or slot.is_empty() or slot.item == null:
			continue
		if slot.item.item_id.is_empty():
			continue
		out.append(slot.item.item_id)
	return out


func rebuild_equipment_effects() -> void:
	_clear_applied_equipment_effects()
	if runtime_attribute_set == null:
		return

	for slot in container.slots:
		if slot == null or slot.is_empty() or slot.item == null:
			continue
		var item: ItemData = slot.item
		var item_id: StringName = item.item_id
		var effects: Array = _resolve_item_effects(item)
		for i in range(effects.size()):
			var effect: Dictionary = effects[i]
			_apply_effect(item_id, i, effect)


func _on_inventory_changed() -> void:
	if _suppress_rebuild:
		return
	rebuild_equipment_effects()


func _clear_slots() -> void:
	if container == null:
		return
	for slot in container.slots:
		if slot != null:
			slot.clear()


func _get_or_make_placeholder_item(item_id: StringName) -> ItemData:
	var key := String(item_id)
	if _placeholder_items.has(key):
		return _placeholder_items[key]

	var item := ItemDataRef.new()
	item.item_id = item_id
	item.item_name = key
	item.max_stack = 1
	_placeholder_items[key] = item
	return item


func _resolve_or_make_item(item_id: StringName) -> ItemData:
	var resolved: ItemData = ItemDataResolverRef.resolve(item_id)
	if resolved != null:
		return resolved
	return _get_or_make_placeholder_item(item_id)


func _resolve_item_effects(item: ItemData) -> Array:
	if item == null:
		return []
	var effects: Array[Dictionary] = ItemDataResolverRef.get_equipment_effects(item)
	if not effects.is_empty():
		return effects
	var fallback_item: ItemData = ItemDataResolverRef.resolve(item.item_id)
	if fallback_item == null or fallback_item == item:
		return []
	return ItemDataResolverRef.get_equipment_effects(fallback_item)


func _apply_effect(item_id: StringName, effect_index: int, effect: Dictionary) -> void:
	if runtime_attribute_set == null:
		return

	var attr_name := String(effect.get("attr", ""))
	if attr_name.is_empty():
		return

	var attr = runtime_attribute_set.find_attribute(attr_name)
	if attr == null:
		return

	var value: float = float(effect.get("value", 0.0))
	var op: StringName = StringName(str(effect.get("op", &"add")))
	var buff_name := "%s%s::%s::%d" % [EQUIP_BUFF_PREFIX, String(item_id), attr_name, effect_index]

	var buff = _make_equipment_buff(op, value, buff_name)
	if buff == null:
		return

	var applied = attr.add_buff(buff)
	if applied != null:
		_applied_effects.append({
			"attr": attr,
			"buff": applied,
		})


func _make_equipment_buff(op: StringName, value: float, buff_name: String) -> AttributeBuff:
	match op:
		&"add":
			return AttributeBuffRef.add(value, buff_name)
		&"sub":
			return AttributeBuffRef.sub(value, buff_name)
		&"mult":
			return AttributeBuffRef.mult(value, buff_name)
		&"div":
			return AttributeBuffRef.div(value, buff_name)
		_:
			push_warning("ActorInventoryComponent: unsupported equipment op=%s" % String(op))
			return null


func _clear_applied_equipment_effects() -> void:
	for row in _applied_effects:
		var attr = row.get("attr", null)
		var buff = row.get("buff", null)
		if attr != null and buff != null:
			attr.remove_buff(buff)
	_applied_effects.clear()
