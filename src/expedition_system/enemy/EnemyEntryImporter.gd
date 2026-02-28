class_name EnemyEntryImporter extends RefCounted

const ActorEntryRef = preload("res://src/expedition_system/actor/ActorEntry.gd")
const ActorTemplateResolverRef = preload("res://src/expedition_system/actor/ActorTemplateResolver.gd")
const PlayerActorAssemblerRef = preload("res://src/expedition_system/actor/PlayerActorAssembler.gd")
const EnemyGroupDefRef = preload("res://src/expedition_system/enemy/EnemyGroupDef.gd")

static var _group_cache: Dictionary = {}
static var _scan_complete: bool = false


static func from_combat_event(combat_event: CombatEventDef) -> Array:
	if combat_event == null:
		push_error("EnemyEntryImporter.from_combat_event failed: combat_event is null")
		return []

	var group: Resource = _resolve_group(combat_event.enemy_group_id)
	if group == null:
		push_warning("EnemyEntryImporter: enemy group not found | enemy_group_id=%s" % String(combat_event.enemy_group_id))
		return []

	var entries: Array = []
	var enemy_index: int = 0
	var members: Array = group.members
	for spawn in members:
		if spawn == null or spawn.actor_template_id.is_empty():
			continue
		var template: ActorTemplate = ActorTemplateResolverRef.resolve(spawn.actor_template_id)
		if template == null:
			push_warning("EnemyEntryImporter: enemy template not found | group_id=%s template_id=%s" % [
				String(group.group_id),
				String(spawn.actor_template_id),
			])
			continue

		var count: int = max(spawn.count, 1)
		for _i in range(count):
			var entry = _build_enemy_entry(template, combat_event, enemy_index)
			if entry != null:
				entries.append(entry)
				enemy_index += 1
	return entries


static func _build_enemy_entry(template: ActorTemplate, combat_event: CombatEventDef, enemy_index: int):
	if template == null or combat_event == null:
		return null

	var max_hp: float = PlayerActorAssemblerRef.get_template_max_hp(template)
	var empty_equipment_ids: Array[StringName] = []
	var entry = ActorEntryRef.new()
	entry.actor_id = StringName("e_%d_%d" % [max(combat_event.step_index, 0), enemy_index])
	entry.camp = &"enemy"
	entry.actor_template_id = template.template_id
	entry.hp = max_hp
	entry.max_hp = max_hp
	entry.base_attr_set = template.base_attr_set.duplicate(true) if template.base_attr_set != null else null
	entry.ai_id = template.ai_id
	entry.action_ids = template.action_ids.duplicate()
	entry.passive_ids = template.passive_ids.duplicate()
	entry.equipment_container = null
	entry.equipment_ids = empty_equipment_ids
	entry.extra = {
		"enemy_group_id": combat_event.enemy_group_id,
		"enemy_index": enemy_index,
	}
	return entry


static func _resolve_group(group_id: StringName) -> Resource:
	if group_id.is_empty():
		return null

	var key: String = String(group_id)
	if _group_cache.has(key):
		return _group_cache[key]

	if not _scan_complete:
		_scan_groups()

	if _group_cache.has(key):
		return _group_cache[key]
	return null


static func _scan_groups() -> void:
	_scan_complete = true
	_scan_dir("res://data")


static func _scan_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var name: String = dir.get_next()
	while not name.is_empty():
		if name.begins_with("."):
			name = dir.get_next()
			continue

		var child_path: String = "%s/%s" % [dir_path, name]
		if dir.current_is_dir():
			_scan_dir(child_path)
		elif name.ends_with(".tres") or name.ends_with(".res"):
			var loaded: Resource = load(child_path)
			if loaded != null and loaded.get_script() == EnemyGroupDefRef:
				var group_id_value: Variant = loaded.get("group_id")
				var loaded_group_id: StringName = group_id_value if group_id_value is StringName else StringName(str(group_id_value))
				if not loaded_group_id.is_empty():
					_group_cache[String(loaded_group_id)] = loaded
		name = dir.get_next()
	dir.list_dir_end()
