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
	runtime.equipment_ids = member_cfg.equipment_ids.duplicate()
	runtime.action_ids = template.action_ids.duplicate()
	runtime.passive_ids = template.passive_ids.duplicate()
	runtime.ai_id = template.ai_id

	runtime.max_hp = maxf(template.max_hp, 0.0)
	runtime.current_hp = member_cfg.get_init_hp(runtime.max_hp)
	runtime.alive = runtime.current_hp > 0.0

	runtime.injury_flags = {}
	runtime.resources = {}
	return runtime
