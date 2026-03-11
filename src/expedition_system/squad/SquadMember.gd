extends Node
class_name SquadMember

const AttributeSetRef = preload("res://src/attribute_framework/AttributeSet.gd")
const RuntimeHpAttributeRef = preload("res://src/attribute_framework/RuntimeHpAttribute.gd")

@export var member_id: StringName = &""
@export var player_actor_id: StringName = &""
@export var actor_id: StringName = &""
@export var unit_uid: StringName = &""

@export var equipment_ids: Array[StringName] = []

@export var injury_flags: Dictionary = {}
@export var resources: Dictionary = {}
@export var capture_meta: Dictionary = {}
@export var long_states: Dictionary = {}

@export var attribute_component_path: NodePath = ^"AttributeComponent"


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

	var attribute_component := _get_attribute_component()
	if attribute_component == null:
		push_error("SquadMember.initialize_from_player failed: missing AttributeComponent")
		return false
	attribute_component.attribute_set = _build_attribute_set(actor_def)
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


func _build_attribute_set(actor_def: ActorDefinition) -> AttributeSet:
	var attr_set: AttributeSet = AttributeSetRef.new()
	var attrs: Array[Attribute] = []

	attrs.append(_make_basic_attribute("strength", actor_def.strength))
	attrs.append(_make_basic_attribute("constitution", actor_def.constitution))
	attrs.append(_make_basic_attribute("dexterity", actor_def.dexterity))
	attrs.append(_make_basic_attribute("perception", actor_def.perception))
	attrs.append(_make_basic_attribute("will", actor_def.will))
	attrs.append(_make_basic_attribute("intelligence", actor_def.intelligence))
	attrs.append(_make_basic_attribute("luck", actor_def.luck))

	var hp_max_value: float = maxf(actor_def.constitution * 10.0, 1.0)
	attrs.append(_make_basic_attribute("hp_max", hp_max_value))
	attrs.append(_make_hp_attribute("hp", hp_max_value))

	attr_set.attributes = attrs
	return attr_set


func _make_basic_attribute(attribute_name: String, base_value: float) -> Attribute:
	var attribute: Attribute = Attribute.new()
	attribute.attribute_name = attribute_name
	attribute.base_value = base_value
	return attribute


func _make_hp_attribute(attribute_name: String, base_value: float) -> Attribute:
	var attribute: RuntimeHpAttribute = RuntimeHpAttributeRef.new()
	attribute.attribute_name = attribute_name
	attribute.base_value = base_value
	return attribute


func _get_attribute_component() -> AttributeComponent:
	var node = get_node_or_null(attribute_component_path)
	if node == null:
		return null
	if not (node is AttributeComponent):
		return null
	return node as AttributeComponent


func _build_member_id(source_player_actor_id: StringName, member_index: int) -> StringName:
	return StringName("member_%s_%d" % [String(source_player_actor_id), member_index])


func _build_unit_uid(source_squad_id: StringName, source_member_id: StringName, member_index: int) -> StringName:
	if not source_squad_id.is_empty():
		return StringName("unit_%s_%s_%d" % [String(source_squad_id), String(source_member_id), member_index])
	return StringName("unit_%s_%d" % [String(source_member_id), member_index])
