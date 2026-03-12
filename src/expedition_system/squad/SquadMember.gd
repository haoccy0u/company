extends Node
class_name SquadMember

@export var member_id: StringName = &""
@export var player_actor_id: StringName = &""
@export var actor_id: StringName = &""
@export var unit_uid: StringName = &""

@export var equipment_ids: Array[StringName] = []

@export var injury_flags: Dictionary = {}
@export var resources: Dictionary = {}
@export var capture_meta: Dictionary = {}
@export var long_states: Dictionary = {}

@export var attribute_component_path: NodePath = ^"AttributeComponentSM"
@export var inventory_component_path: NodePath = ^"InventoryComponentSM"

var _equipment_sync_ok: bool = true


func initialize_from_player(
	player_actor: PlayerActorData,
	actor_def: ActorDefinition,
	source_squad_id: StringName,
	member_index: int
) -> bool:
	if player_actor == null:
		push_error("SquadMember.initialize_from_player failed: invalid player_actor")
		return false
	if actor_def == null:
		push_error("SquadMember.initialize_from_player failed: invalid actor_def")
		return false

	player_actor_id = player_actor.player_actor_id
	actor_id = player_actor.actor_id
	member_id = _build_member_id(player_actor.player_actor_id, member_index)
	unit_uid = _build_unit_uid(source_squad_id, member_id, member_index)
	equipment_ids = player_actor.equipment_ids.duplicate()
	injury_flags = {}
	resources = {}
	capture_meta = {}
	long_states = {}
	_equipment_sync_ok = true

	var attribute_component := _get_attribute_component()
	if attribute_component == null:
		push_error("SquadMember.initialize_from_player failed: missing AttributeComponentSM")
		return false
	var inventory_component := _get_inventory_component()
	if inventory_component == null:
		push_error("SquadMember.initialize_from_player failed: missing InventoryComponentSM")
		return false
	_bind_inventory_signals(inventory_component)

	if not attribute_component.initialize_from_actor_def(actor_def):
		push_error("SquadMember.initialize_from_player failed: AttributeComponentSM initialization failed")
		return false

	if not inventory_component.set_equipment_ids(equipment_ids):
		push_error("SquadMember.initialize_from_player failed: equipment parsing failed")
		return false
	if not _equipment_sync_ok:
		push_error("SquadMember.initialize_from_player failed: equipment effects apply failed")
		return false

	return true


func is_usable() -> bool:
	return get_attribute_value("hp", 0.0) > 0.0


func get_attribute_value(attribute_name: String, fallback: float = 0.0) -> float:
	var attribute_component := _get_attribute_component()
	if attribute_component == null:
		return fallback
	var attribute = attribute_component.find_attribute(attribute_name)
	if attribute == null:
		return fallback
	return attribute.get_value()


func refresh_equipment_effects() -> bool:
	var inventory_component := _get_inventory_component()
	if inventory_component == null:
		push_error("SquadMember.refresh_equipment_effects failed: missing InventoryComponentSM")
		return false
	_equipment_sync_ok = true
	if not inventory_component.set_equipment_ids(equipment_ids):
		return false
	return _equipment_sync_ok


func to_snapshot_dict() -> Dictionary:
	return {
		"unit_uid": unit_uid,
		"member_id": member_id,
		"player_actor_id": player_actor_id,
		"actor_id": actor_id,
		"hp": get_attribute_value("hp", 0.0),
		"hp_max": get_attribute_value("hp_max", 0.0),
		"alive": is_usable(),
	}


func _bind_inventory_signals(inventory_component: InventoryComponentSM) -> void:
	if not inventory_component.equipment_effects_changed.is_connected(_on_equipment_effects_changed):
		inventory_component.equipment_effects_changed.connect(_on_equipment_effects_changed)
	if not inventory_component.equipment_effects_invalid.is_connected(_on_equipment_effects_invalid):
		inventory_component.equipment_effects_invalid.connect(_on_equipment_effects_invalid)


func _on_equipment_effects_changed(effects: Dictionary) -> void:
	var attribute_component := _get_attribute_component()
	if attribute_component == null:
		_equipment_sync_ok = false
		push_error("SquadMember._on_equipment_effects_changed failed: missing AttributeComponentSM")
		return

	_equipment_sync_ok = attribute_component.apply_equipment_effects(effects)
	if not _equipment_sync_ok:
		push_error("SquadMember._on_equipment_effects_changed failed: apply_equipment_effects returned false")


func _on_equipment_effects_invalid(reason: String) -> void:
	_equipment_sync_ok = false
	push_error("SquadMember received invalid equipment effects: %s" % reason)


func _get_attribute_component() -> AttributeComponentSM:
	var node = get_node_or_null(attribute_component_path)
	if node == null:
		return null
	if not (node is AttributeComponentSM):
		return null
	return node as AttributeComponentSM


func _get_inventory_component() -> InventoryComponentSM:
	var node = get_node_or_null(inventory_component_path)
	if node == null:
		return null
	if not (node is InventoryComponentSM):
		return null
	return node as InventoryComponentSM


func _build_member_id(source_player_actor_id: StringName, member_index: int) -> StringName:
	return StringName("member_%s_%d" % [String(source_player_actor_id), member_index])


func _build_unit_uid(source_squad_id: StringName, source_member_id: StringName, member_index: int) -> StringName:
	if not source_squad_id.is_empty():
		return StringName("unit_%s_%s_%d" % [String(source_squad_id), String(source_member_id), member_index])
	return StringName("unit_%s_%d" % [String(source_member_id), member_index])
