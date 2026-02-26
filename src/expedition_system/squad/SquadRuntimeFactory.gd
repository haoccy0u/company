class_name SquadRuntimeFactory extends RefCounted


static func from_config(config: SquadConfig) -> SquadRuntime:
	if config == null:
		push_error("SquadRuntimeFactory.from_config failed: config is null")
		return null

	var runtime := SquadRuntime.new()
	runtime.source_squad_id = config.squad_id
	runtime.members = []
	runtime.shared_res = {}
	runtime.long_states = {}

	for member_cfg in config.members:
		var member_runtime := _build_member_runtime(member_cfg)
		if member_runtime == null:
			continue
		runtime.members.append(member_runtime)

	return runtime


static func _build_member_runtime(member_cfg: MemberConfig) -> MemberRuntime:
	if member_cfg == null:
		push_warning("SquadRuntimeFactory skipped null MemberConfig")
		return null

	var template := member_cfg.actor_template
	if template == null:
		push_warning("SquadRuntimeFactory skipped member because actor_template is null | member_id=%s" % String(member_cfg.member_id))
		return null

	var runtime := MemberRuntime.new()
	runtime.member_id = member_cfg.member_id
	runtime.actor_template_id = member_cfg.actor_template_id if not member_cfg.actor_template_id.is_empty() else template.template_id
	runtime.equipment_container = member_cfg.equipment_container.duplicate(true) if member_cfg.equipment_container != null else null
	runtime.equipment_ids = member_cfg.equipment_ids.duplicate()
	runtime.action_ids = template.action_ids.duplicate()
	runtime.passive_ids = template.passive_ids.duplicate()
	runtime.ai_id = template.ai_id
	runtime.base_attr_set = template.base_attr_set.duplicate(true) if template.base_attr_set != null else null

	runtime.max_hp = _get_template_max_hp(template)
	runtime.current_hp = member_cfg.get_init_hp(runtime.max_hp)
	runtime.alive = runtime.current_hp > 0.0

	runtime.injury_flags = {}
	runtime.resources = {}
	return runtime


static func _get_template_max_hp(template: ActorTemplate) -> float:
	if template == null:
		return 0.0
	if template.base_attr_set == null:
		push_warning("SquadRuntimeFactory: actor_template.base_attr_set is null | template_id=%s" % String(template.template_id))
		return 0.0

	var hp_max: float = template.get_base_attr_value(&"hp_max", -1.0)
	if hp_max < 0.0:
		push_warning("SquadRuntimeFactory: missing hp_max in ActorTemplate.base_attr_set | template_id=%s" % String(template.template_id))
		return 0.0
	return maxf(hp_max, 0.0)
