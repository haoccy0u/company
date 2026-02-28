class_name EnemyEntryImporter extends RefCounted

const ActorEntryRef = preload("res://src/expedition_system/actor/ActorEntry.gd")
const ActorTemplateResolverRef = preload("res://src/expedition_system/actor/ActorTemplateResolver.gd")
const PlayerActorAssemblerRef = preload("res://src/expedition_system/actor/PlayerActorAssembler.gd")
const EnemyGroupDefRef = preload("res://src/expedition_system/enemy/EnemyGroupDef.gd")
const GROUP_DIRS: PackedStringArray = [
	"res://data/expedition/enemies/groups",
	"res://data/devtest/expedition/enemies/groups",
]
const RESOURCE_EXTENSIONS: PackedStringArray = [".tres", ".res"]

static var _group_cache: Dictionary = {}
static var _missing_group_ids: Dictionary = {}


static func register_group(group: EnemyGroupDef) -> void:
	if group == null:
		return
	if group.group_id.is_empty():
		push_warning("EnemyEntryImporter.register_group skipped: group_id is empty")
		return
	var key := String(group.group_id)
	_group_cache[key] = group
	_missing_group_ids.erase(key)


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
	if _missing_group_ids.has(key):
		return null

	var loaded := _load_group_from_known_paths(group_id)
	if loaded != null:
		register_group(loaded)
		return loaded

	_missing_group_ids[key] = true
	return null


static func _load_group_from_known_paths(group_id: StringName) -> EnemyGroupDef:
	for path in _build_candidate_paths(group_id, GROUP_DIRS):
		var loaded: Resource = load(path)
		if loaded is EnemyGroupDef:
			return loaded as EnemyGroupDef
		if loaded != null and loaded.get_script() == EnemyGroupDefRef:
			return loaded as EnemyGroupDef
	return null


static func _build_candidate_paths(resource_id: StringName, directories: PackedStringArray) -> Array[String]:
	var paths: Array[String] = []
	var file_name := String(resource_id)
	for directory in directories:
		for ext in RESOURCE_EXTENSIONS:
			paths.append("%s/%s%s" % [directory, file_name, ext])
	return paths
