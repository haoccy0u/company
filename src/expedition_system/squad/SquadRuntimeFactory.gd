class_name SquadRuntimeFactory extends RefCounted

const PlayerActorAssemblerRef = preload("res://src/expedition_system/actor/PlayerActorAssembler.gd")


static func from_config(config: SquadConfig) -> SquadRuntime:
	if config == null:
		push_error("SquadRuntimeFactory.from_config failed: config is null")
		return null

	var runtime := SquadRuntime.new()
	runtime.source_squad_id = config.squad_id
	runtime.shared_res = {}
	runtime.long_states = {}

	for member_cfg in config.members:
		var member_runtime := _build_member_runtime(member_cfg)
		if member_runtime == null:
			continue
		runtime.members.append(member_runtime)

	return runtime


static func _build_member_runtime(member_cfg: MemberConfig) -> MemberRuntime:
	return PlayerActorAssemblerRef.build_member_runtime(member_cfg)
