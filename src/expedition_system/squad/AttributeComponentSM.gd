extends AttributeComponent
class_name AttributeComponentSM

const EQUIPMENT_BUFF_PREFIX := "equip:"
const REQUIRED_ATTRIBUTE_NAMES: Array[StringName] = [
	&"strength",
	&"constitution",
	&"dexterity",
	&"perception",
	&"will",
	&"intelligence",
	&"luck",
	&"hp_max",
	&"hp",
]


func initialize_from_actor_def(actor_def: ActorDefinition) -> bool:
	if actor_def == null:
		push_error("AttributeComponentSM.initialize_from_actor_def failed: actor_def is null")
		return false
	if attribute_set == null:
		push_error("AttributeComponentSM.initialize_from_actor_def failed: template AttributeSet missing")
		return false

	var runtime_set := attribute_set.duplicate(true) as AttributeSet
	if runtime_set == null:
		push_error("AttributeComponentSM.initialize_from_actor_def failed: duplicate template AttributeSet failed")
		return false
	# Rebuild runtime maps for this instance and avoid sharing internal state.
	runtime_set.attributes = runtime_set.attributes

	for attribute_name in REQUIRED_ATTRIBUTE_NAMES:
		if runtime_set.find_attribute(String(attribute_name)) == null:
			push_error("AttributeComponentSM.initialize_from_actor_def failed: missing required attribute | name=%s" % String(attribute_name))
			return false

	attribute_set = runtime_set

	var primary_values: Dictionary = {
		&"strength": actor_def.strength,
		&"constitution": actor_def.constitution,
		&"dexterity": actor_def.dexterity,
		&"perception": actor_def.perception,
		&"will": actor_def.will,
		&"intelligence": actor_def.intelligence,
		&"luck": actor_def.luck,
	}
	for attribute_name in primary_values.keys():
		if not _set_required_value(attribute_name, float(primary_values[attribute_name])):
			return false

	var hp_max_value: float = maxf(actor_def.constitution * 10.0, 1.0)
	if not _set_required_value(&"hp_max", hp_max_value):
		return false
	if not _set_required_value(&"hp", hp_max_value):
		return false

	clear_equipment_effects()
	return true


func apply_equipment_effects(effects: Dictionary) -> bool:
	if attribute_set == null:
		push_error("AttributeComponentSM.apply_equipment_effects failed: attribute_set is null")
		return false

	if effects.is_empty():
		clear_equipment_effects()
		return true

	var apply_rows: Array[Dictionary] = []
	for attr_key in effects.keys():
		var attr_name := StringName(attr_key)
		var target_attr := attribute_set.find_attribute(String(attr_name))
		if target_attr == null:
			push_error("AttributeComponentSM.apply_equipment_effects failed: target attribute missing | attr=%s" % String(attr_name))
			return false

		var rows_variant: Variant = effects[attr_key]
		if not (rows_variant is Array):
			push_error("AttributeComponentSM.apply_equipment_effects failed: invalid effect rows type | attr=%s" % String(attr_name))
			return false

		var rows: Array = rows_variant
		for row_variant in rows:
			if not (row_variant is Dictionary):
				push_error("AttributeComponentSM.apply_equipment_effects failed: effect row is not Dictionary | attr=%s" % String(attr_name))
				return false
			var row: Dictionary = row_variant

			var op := StringName(row.get("op", &""))
			var buff_name := StringName(row.get("buff_name", &""))
			if buff_name.is_empty():
				push_error("AttributeComponentSM.apply_equipment_effects failed: buff_name missing | attr=%s" % String(attr_name))
				return false
			if not String(buff_name).begins_with(EQUIPMENT_BUFF_PREFIX):
				buff_name = StringName("%s%s" % [EQUIPMENT_BUFF_PREFIX, String(buff_name)])

			var value_variant: Variant = row.get("value", null)
			if value_variant == null:
				push_error("AttributeComponentSM.apply_equipment_effects failed: value missing | attr=%s buff=%s" % [
					String(attr_name),
					String(buff_name),
				])
				return false
			var value := float(value_variant)

			var buff := _make_buff(op, value, buff_name)
			if buff == null:
				push_error("AttributeComponentSM.apply_equipment_effects failed: unsupported op=%s | attr=%s buff=%s" % [
					String(op),
					String(attr_name),
					String(buff_name),
				])
				return false

			apply_rows.append({
				"attribute": target_attr,
				"buff": buff,
			})

	clear_equipment_effects()
	for entry in apply_rows:
		var target_attr = entry.get("attribute", null) as Attribute
		var buff = entry.get("buff", null) as AttributeBuff
		if target_attr == null or buff == null:
			push_error("AttributeComponentSM.apply_equipment_effects failed: invalid apply row")
			clear_equipment_effects()
			return false
		var applied := target_attr.add_buff(buff)
		if applied == null:
			push_error("AttributeComponentSM.apply_equipment_effects failed: add_buff failed | attr=%s buff=%s" % [
				String(target_attr.attribute_name),
				String(buff.buff_name),
			])
			clear_equipment_effects()
			return false

	return true


func clear_equipment_effects() -> void:
	if attribute_set == null:
		return

	for attribute_name_key in attribute_set.attributes_runtime_dict.keys():
		var runtime_attr = attribute_set.attributes_runtime_dict[attribute_name_key] as Attribute
		if runtime_attr == null:
			continue
		var pending_remove: Array[AttributeBuff] = []
		for buff in runtime_attr.buffs:
			if buff != null and String(buff.buff_name).begins_with(EQUIPMENT_BUFF_PREFIX):
				pending_remove.append(buff)
		for buff in pending_remove:
			runtime_attr.remove_buff(buff)


func _set_required_value(attribute_name: StringName, value: float) -> bool:
	if attribute_set == null:
		return false
	var attr := attribute_set.find_attribute(String(attribute_name))
	if attr == null:
		push_error("AttributeComponentSM missing required attribute | name=%s" % String(attribute_name))
		return false
	attr.set_value(value)
	return true


func _make_buff(op: StringName, value: float, buff_name: StringName) -> AttributeBuff:
	match op:
		&"add":
			return AttributeBuff.add(value, String(buff_name))
		&"sub":
			return AttributeBuff.sub(value, String(buff_name))
		&"mult":
			return AttributeBuff.mult(value, String(buff_name))
		&"div":
			return AttributeBuff.div(value, String(buff_name))
		_:
			return null
