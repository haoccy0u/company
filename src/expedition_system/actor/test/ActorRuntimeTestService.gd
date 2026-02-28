extends RefCounted
class_name ActorRuntimeTestService

const ActorTemplateRef = preload("res://src/expedition_system/actor/ActorTemplate.gd")
const ActorEntryRef = preload("res://src/expedition_system/actor/ActorEntry.gd")
const ActorRuntimeScene = preload("res://src/expedition_system/actor/ActorRuntime.tscn")
const AttributeBuffRef = preload("res://src/attribute_framework/AttributeBuff.gd")
const ItemContainerRef = preload("res://src/inventory/ItemContainer.gd")
const ItemDataRef = preload("res://src/inventory/ItemData.gd")
const ItemDataResolverRef = preload("res://src/inventory/ItemDataResolver.gd")

const DEVTEST_ACTOR_TEMPLATE_PATHS: Array[String] = [
	"res://data/devtest/expedition/actors/observer.tres",
	"res://data/devtest/expedition/actors/robot.tres",
]

const LOADOUT_PRESETS := {
	&"none": [],
	&"sword": [&"iron_sword"],
	&"shield": [&"wood_shield"],
	&"bow": [&"hunter_bow"],
	&"sword_shield": [&"iron_sword", &"wood_shield"],
}


static func get_template_options() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for template in _load_devtest_templates():
		rows.append({
			"id": template.template_id,
			"label": _template_label(template),
			"template": template,
		})
	return rows


static func get_loadout_options() -> Array[Dictionary]:
	return [
		{"id": &"none", "label": "None"},
		{"id": &"sword", "label": "Iron Sword"},
		{"id": &"shield", "label": "Wood Shield"},
		{"id": &"bow", "label": "Hunter Bow"},
		{"id": &"sword_shield", "label": "Sword + Shield"},
	]


static func clear_host(host: Node) -> void:
	if host == null:
		return
	for child in host.get_children():
		host.remove_child(child)
		child.free()


static func build_actor(host: Node, template_id: StringName, options: Dictionary = {}):
	if host == null:
		return null
	var template := _find_template(template_id)
	if template == null:
		return null

	var runtime = ActorRuntimeScene.instantiate()
	if runtime == null:
		return null

	host.add_child(runtime)

	var entry := ActorEntryRef.new()
	entry.actor_id = StringName(str(options.get("actor_id", "%s_actor" % String(template_id))))
	entry.member_id = StringName(str(options.get("member_id", entry.actor_id)))
	entry.camp = StringName(str(options.get("camp", "player")))
	entry.actor_template_id = template.template_id
	entry.base_attr_set = template.base_attr_set.duplicate(true) if template.base_attr_set != null else null
	entry.max_hp = template.get_base_attr_value(&"hp_max", 0.0)
	var initial_hp: float = float(options.get("initial_hp", -1.0))
	entry.hp = entry.max_hp if initial_hp < 0.0 else initial_hp
	entry.ai_id = template.ai_id
	entry.action_ids = template.action_ids.duplicate()
	entry.passive_ids = template.passive_ids.duplicate()

	var loadout_id := StringName(str(options.get("loadout_id", "none")))
	var equipment_ids: Array[StringName] = options.get("equipment_ids", _get_loadout_ids(loadout_id))
	entry.equipment_ids = equipment_ids.duplicate()
	entry.equipment_container = options.get("equipment_container", _make_equipment_container(equipment_ids))
	entry.extra = {
		"template_display_name": template.display_name,
		"test_loadout_id": loadout_id,
	}

	if not runtime.setup_from_entry(entry):
		host.remove_child(runtime)
		runtime.free()
		return null

	return runtime


static func collect_actor_snapshot(actor) -> Dictionary:
	if actor == null:
		return {}
	return {
		"actor_id": actor.actor_id,
		"template_id": actor.actor_template_id,
		"camp": actor.camp,
		"hp": actor.get_current_hp(),
		"hp_max": actor.get_max_hp(),
		"alive": actor.is_alive(),
		"cooldown_remaining": actor.cooldown_remaining,
		"cooldown_total": actor.get_cooldown_total(),
		"action_ids": actor.action_ids.duplicate(),
		"passive_ids": actor.passive_ids.duplicate(),
		"attr": collect_attr_snapshot(actor),
		"buffs": collect_buff_snapshot(actor),
		"equipment_ids": _collect_actor_equipment_ids(actor),
	}


static func collect_attr_snapshot(actor) -> Dictionary:
	if actor == null:
		return {}
	var attr_names: Array[StringName] = [
		&"hp",
		&"hp_max",
		&"atk",
		&"def",
		&"spd",
		&"cooldown_total",
		&"dmg_out_mul",
		&"dmg_in_mul",
		&"heal_out_mul",
		&"heal_in_mul",
	]
	var rows: Dictionary = {}
	for attr_name in attr_names:
		rows[String(attr_name)] = {
			"base": actor.get_attr_base_value(attr_name, 0.0),
			"value": actor.get_attr_value(attr_name, 0.0),
		}
	return rows


static func collect_buff_snapshot(actor) -> Dictionary:
	if actor == null or actor.attr_set == null:
		return {}
	var rows: Dictionary = {}
	for attr_name in actor.attr_set.attributes_runtime_dict.keys():
		var attr = actor.attr_set.attributes_runtime_dict[attr_name]
		if attr == null:
			continue
		var buffs: Array[Dictionary] = []
		for buff in attr.buffs:
			if buff == null:
				continue
			buffs.append({
				"name": buff.buff_name,
				"value": buff.value,
				"duration": buff.duration,
				"remaining": buff.remaining_time,
				"policy": buff.policy,
			})
		if not buffs.is_empty():
			rows[attr_name] = buffs
	return rows


static func apply_demo_weaken(actor, duration_sec: float = 2.0, multiplier: float = 0.7) -> bool:
	if actor == null:
		return false
	var buff := AttributeBuffRef.mult(multiplier, "weaken")
	buff.set_duration(duration_sec)
	return actor.apply_attribute_buff(&"dmg_out_mul", buff)


static func build_turn_plan_report(host: Node, actor, target_template_id: StringName, ally_damage: float = 25.0) -> Dictionary:
	if actor == null:
		return {}
	_clear_host_except(host, actor)
	var target = build_actor(host, target_template_id, {
		"actor_id": "%s_target" % String(target_template_id),
		"member_id": "%s_target" % String(target_template_id),
		"camp": &"enemy",
	})
	if target == null:
		return {}

	var allies: Array = [actor]
	var opponents: Array = [target]
	var support_ally = null
	if actor.passive_ids.has(&"attack_heal_ally"):
		support_ally = build_actor(host, &"observer", {
			"actor_id": "support_ally",
			"member_id": "support_ally",
			"camp": actor.camp,
		})
		if support_ally != null:
			support_ally.apply_damage(ally_damage)
			allies.append(support_ally)

	var plan = actor.build_turn_plan(opponents, allies)
	var follow_up_summary: Array[Dictionary] = []
	for row in plan.get("follow_up_effects", []):
		if not (row is Dictionary):
			continue
		follow_up_summary.append({
			"type": row.get("type", &""),
			"target_actor_id": row["target"].actor_id if row.get("target", null) != null else &"",
			"status_id": row.get("status_id", &""),
			"effect_id": row.get("effect_id", &""),
			"amount": row.get("amount", 0.0),
		})

	var attack_payload: Dictionary = plan.get("attack_payload", {})
	var damage_ctx: Dictionary = target.resolve_attack_payload(attack_payload) if target != null else {}
	return {
		"plan_ready": not plan.is_empty(),
		"selected_action": plan.get("action_id", &""),
		"target_actor_id": plan["primary_target"].actor_id if plan.get("primary_target", null) != null else &"",
		"damage_pre_passive": float(damage_ctx.get("raw_damage", 0.0)),
		"damage_final": float(damage_ctx.get("final_damage", 0.0)),
		"triggered_effect_ids": attack_payload.get("triggered_effect_ids", []),
		"follow_up_effects": follow_up_summary,
	}


static func _load_devtest_templates() -> Array[ActorTemplate]:
	var rows: Array[ActorTemplate] = []
	for path in DEVTEST_ACTOR_TEMPLATE_PATHS:
		var loaded := load(path)
		if loaded is ActorTemplate:
			rows.append(loaded)
	return rows


static func _find_template(template_id: StringName) -> ActorTemplate:
	for template in _load_devtest_templates():
		if template.template_id == template_id:
			return template
	return null


static func _template_label(template: ActorTemplate) -> String:
	if template == null:
		return "null"
	if not template.display_name.is_empty():
		return "%s (%s)" % [template.display_name, String(template.template_id)]
	return String(template.template_id)


static func _get_loadout_ids(loadout_id: StringName) -> Array[StringName]:
	if LOADOUT_PRESETS.has(loadout_id):
		var raw_ids: Array = LOADOUT_PRESETS[loadout_id]
		var out: Array[StringName] = []
		for item_id in raw_ids:
			out.append(StringName(str(item_id)))
		return out
	return Array([], TYPE_STRING_NAME, "", null)


static func _make_equipment_container(item_ids: Array[StringName], slot_count: int = 6) -> ItemContainer:
	if item_ids.is_empty():
		return null
	var container := ItemContainerRef.new()
	container.item_container_id = &"actor_runtime_test_loadout"
	container.slot_count = slot_count
	for item_id in item_ids:
		if item_id.is_empty():
			continue
		var item := ItemDataResolverRef.resolve(item_id)
		if item == null:
			item = ItemDataRef.new()
			item.item_id = item_id
			item.item_name = String(item_id)
			item.max_stack = 1
		container.try_insert(item, 1)
	return container


static func _collect_actor_equipment_ids(actor) -> Array[StringName]:
	if actor == null or actor.inventory_component == null:
		return []
	if actor.inventory_component.has_method("collect_equipped_item_ids"):
		return actor.inventory_component.collect_equipped_item_ids()
	return []

static func _clear_host_except(host: Node, keep: Node) -> void:
	if host == null:
		return
	for child in host.get_children():
		if child == keep:
			continue
		host.remove_child(child)
		child.free()
