class_name PlayerActorAssembler extends RefCounted

const ActorTemplateResolverRef = preload("res://src/expedition_system/actor/ActorTemplateResolver.gd")
const ActorEntryRef = preload("res://src/expedition_system/actor/ActorEntry.gd")
const MemberRuntimeRef = preload("res://src/expedition_system/squad/MemberRuntime.gd")


static func build_member_runtime(member_cfg: MemberConfig) -> MemberRuntime:
	if member_cfg == null:
		push_warning("PlayerActorAssembler.build_member_runtime skipped: member_cfg is null")
		return null

	var template := ActorTemplateResolverRef.resolve(member_cfg.actor_template_id)
	if template == null:
		push_warning("PlayerActorAssembler.build_member_runtime skipped: template not found | template_id=%s member_id=%s" % [
			String(member_cfg.actor_template_id),
			String(member_cfg.member_id),
		])
		return null

	var runtime := MemberRuntimeRef.new()
	runtime.member_id = member_cfg.member_id
	runtime.actor_template_id = template.template_id
	runtime.equipment_container = member_cfg.equipment_container.duplicate(true) if member_cfg.equipment_container != null else null
	runtime.equipment_ids = member_cfg.equipment_ids.duplicate()
	runtime.max_hp = get_template_max_hp(template)
	runtime.current_hp = member_cfg.get_init_hp(runtime.max_hp)
	runtime.alive = runtime.current_hp > 0.0
	runtime.injury_flags = {}
	runtime.resources = {}
	return runtime


static func build_actor_entry(member: MemberRuntime) -> ActorEntry:
	if member == null:
		push_warning("PlayerActorAssembler.build_actor_entry skipped: member is null")
		return null

	var template := ActorTemplateResolverRef.resolve(member.actor_template_id)
	if template == null:
		push_warning("PlayerActorAssembler.build_actor_entry skipped: template not found | template_id=%s member_id=%s" % [
			String(member.actor_template_id),
			String(member.member_id),
		])
		return null

	var entry := ActorEntryRef.new()
	entry.actor_id = StringName("p_%s" % String(member.member_id))
	entry.camp = &"player"
	entry.member_id = member.member_id
	entry.actor_template_id = member.actor_template_id
	entry.hp = member.current_hp
	entry.max_hp = member.max_hp
	entry.base_attr_set = template.base_attr_set.duplicate(true) if template.base_attr_set != null else null
	entry.ai_id = template.ai_id
	entry.action_ids = template.action_ids.duplicate()
	entry.passive_ids = template.passive_ids.duplicate()
	entry.equipment_container = member.equipment_container.duplicate(true) if member.equipment_container != null else null
	entry.equipment_ids = member.equipment_ids.duplicate()
	return entry


static func resolve_template(template_id: StringName) -> ActorTemplate:
	return ActorTemplateResolverRef.resolve(template_id)


static func get_template_max_hp(template: ActorTemplate) -> float:
	if template == null:
		return 0.0
	if template.base_attr_set == null:
		push_warning("PlayerActorAssembler: actor_template.base_attr_set is null | template_id=%s" % String(template.template_id))
		return 0.0

	var hp_max: float = template.get_base_attr_value(&"hp_max", -1.0)
	if hp_max < 0.0:
		push_warning("PlayerActorAssembler: missing hp_max in ActorTemplate.base_attr_set | template_id=%s" % String(template.template_id))
		return 0.0
	return maxf(hp_max, 0.0)
