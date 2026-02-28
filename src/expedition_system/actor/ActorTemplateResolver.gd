class_name ActorTemplateResolver extends RefCounted

const TEMPLATE_DIRS: PackedStringArray = [
	"res://data/expedition/actors",
	"res://data/expedition/enemies/templates",
	"res://data/devtest/expedition/actors",
	"res://data/devtest/expedition/enemies/templates",
]
const RESOURCE_EXTENSIONS: PackedStringArray = [".tres", ".res"]

static var _template_cache: Dictionary = {}
static var _missing_template_ids: Dictionary = {}


static func register_template(template: ActorTemplate) -> void:
	if template == null:
		return
	if template.template_id.is_empty():
		push_warning("ActorTemplateResolver.register_template skipped: template_id is empty")
		return
	var key := String(template.template_id)
	_template_cache[key] = template
	_missing_template_ids.erase(key)


static func register_templates(templates: Array) -> void:
	for template in templates:
		if template is ActorTemplate:
			register_template(template as ActorTemplate)


static func resolve(template_id: StringName) -> ActorTemplate:
	if template_id.is_empty():
		return null

	var key: String = String(template_id)
	if _template_cache.has(key):
		return _template_cache.get(key) as ActorTemplate
	if _missing_template_ids.has(key):
		return null

	var loaded := _load_template_from_known_paths(template_id)
	if loaded != null:
		register_template(loaded)
		return loaded

	_missing_template_ids[key] = true
	return null


static func _load_template_from_known_paths(template_id: StringName) -> ActorTemplate:
	for path in _build_candidate_paths(template_id, TEMPLATE_DIRS):
		var loaded := load(path)
		if loaded is ActorTemplate:
			return loaded as ActorTemplate
	return null


static func _build_candidate_paths(resource_id: StringName, directories: PackedStringArray) -> Array[String]:
	var paths: Array[String] = []
	var file_name := String(resource_id)
	for directory in directories:
		for ext in RESOURCE_EXTENSIONS:
			paths.append("%s/%s%s" % [directory, file_name, ext])
	return paths
