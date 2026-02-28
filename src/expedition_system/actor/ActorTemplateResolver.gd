class_name ActorTemplateResolver extends RefCounted

const SEARCH_ROOTS: PackedStringArray = ["res://data"]

static var _template_cache: Dictionary = {}
static var _scan_complete: bool = false


static func register_template(template: ActorTemplate) -> void:
	if template == null:
		return
	if template.template_id.is_empty():
		push_warning("ActorTemplateResolver.register_template skipped: template_id is empty")
		return
	_template_cache[String(template.template_id)] = template


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

	if not _scan_complete:
		_scan_templates()

	if _template_cache.has(key):
		return _template_cache.get(key) as ActorTemplate
	return null


static func _scan_templates() -> void:
	_scan_complete = true
	for root in SEARCH_ROOTS:
		_scan_dir(root)


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
			var loaded := load(child_path)
			if loaded is ActorTemplate:
				register_template(loaded as ActorTemplate)
		name = dir.get_next()
	dir.list_dir_end()
