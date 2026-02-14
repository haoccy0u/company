extends Node

signal ui_opened(ui_id: StringName, view: Node)
signal ui_closed(ui_id: StringName, reason: StringName)

const UI_REGISTRY := preload("res://src/ui_framework/UIRegistry.gd")
const UI_HANDLE := preload("res://src/ui_framework/UIHandle.gd")

const LAYER_HUD: StringName = &"hud"
const LAYER_POPUP: StringName = &"popup"
const LAYER_SYSTEM: StringName = &"system"

const CACHE_KEEP_ALIVE: StringName = &"keep_alive"
const CACHE_DESTROY_ON_CLOSE: StringName = &"destroy_on_close"

var _registry: UIRegistry = UI_REGISTRY.new()
var _definitions: Dictionary = {}
var _instances: Dictionary = {}
var _layer_roots: Dictionary = {}


func _ready() -> void:
	_ensure_layer_root(LAYER_HUD)
	_ensure_layer_root(LAYER_POPUP)
	_ensure_layer_root(LAYER_SYSTEM)


func register_ui(
	ui_id: StringName,
	scene: PackedScene,
	layer: StringName = LAYER_HUD,
	cache_policy: StringName = CACHE_KEEP_ALIVE
) -> void:
	_registry.register_definition(_definitions, ui_id, scene, layer, cache_policy)


func unregister_ui(ui_id: StringName, destroy_instance: bool = true) -> void:
	if destroy_instance:
		hide_ui(ui_id, &"unregister")
		if _instances.has(ui_id):
			var node_variant: Variant = _instances[ui_id]
			var node: Node = node_variant as Node
			if node != null and is_instance_valid(node):
				node.queue_free()
			_instances.erase(ui_id)
	_registry.unregister_definition(_definitions, ui_id)


func show_ui(ui_id: StringName, payload: Dictionary = {}) -> UIHandle:
	var def: Dictionary = _registry.get_definition(_definitions, ui_id)
	if def.is_empty():
		push_warning("UIManager.show_ui failed: ui_id not registered: %s" % String(ui_id))
		return null

	var view: Node = _get_or_create_view(ui_id, def)
	if view == null:
		return null

	if view.has_method("_ui_open"):
		view.call("_ui_open", payload)

	if view is Control:
		(view as Control).visible = true

	ui_opened.emit(ui_id, view)
	return UI_HANDLE.new(self, ui_id)


func hide_ui(ui_id: StringName, reason: StringName = &"manual") -> bool:
	var view := get_ui_node(ui_id)
	if view == null:
		return false

	if view.has_method("_ui_close"):
		var result: Variant = view.call("_ui_close", reason)
		if result is bool and not bool(result):
			return false

	if view is Control:
		(view as Control).visible = false

	var def: Dictionary = _registry.get_definition(_definitions, ui_id)
	var policy: StringName = StringName(String(def.get("cache_policy", CACHE_KEEP_ALIVE)))
	if policy == CACHE_DESTROY_ON_CLOSE:
		view.queue_free()
		_instances.erase(ui_id)

	ui_closed.emit(ui_id, reason)
	return true


func toggle_ui(ui_id: StringName, payload: Dictionary = {}) -> UIHandle:
	if is_open(ui_id):
		hide_ui(ui_id, &"toggle")
		return null
	return show_ui(ui_id, payload)


func is_open(ui_id: StringName) -> bool:
	var node := get_ui_node(ui_id)
	if node == null:
		return false
	if node is Control:
		return (node as Control).visible
	return true


func get_ui_node(ui_id: StringName) -> Node:
	if not _instances.has(ui_id):
		return null
	var node_variant: Variant = _instances[ui_id]
	var node: Node = node_variant as Node
	if node == null or not is_instance_valid(node):
		_instances.erase(ui_id)
		return null
	return node


func _get_or_create_view(ui_id: StringName, def: Dictionary) -> Node:
	var existing := get_ui_node(ui_id)
	if existing != null:
		return existing

	var scene_variant: Variant = def.get("scene", null)
	var scene: PackedScene = scene_variant as PackedScene
	if scene == null:
		push_warning("UIManager: scene is invalid for %s" % String(ui_id))
		return null

	var view: Node = scene.instantiate()
	if view == null:
		push_warning("UIManager: instantiate failed for %s" % String(ui_id))
		return null

	var layer_name: StringName = StringName(String(def.get("layer", LAYER_HUD)))
	var root: CanvasLayer = _ensure_layer_root(layer_name)
	root.add_child(view)

	if view is Control:
		(view as Control).visible = false

	_instances[ui_id] = view
	return view


func _ensure_layer_root(layer_name: StringName) -> CanvasLayer:
	if _layer_roots.has(layer_name):
		var existing_variant: Variant = _layer_roots[layer_name]
		var existing: CanvasLayer = existing_variant as CanvasLayer
		if existing != null and is_instance_valid(existing):
			return existing
		_layer_roots.erase(layer_name)

	var root := CanvasLayer.new()
	root.name = "UILayer_%s" % String(layer_name)
	root.layer = _layer_order(layer_name)
	add_child(root)
	_layer_roots[layer_name] = root
	return root


func _layer_order(layer_name: StringName) -> int:
	match layer_name:
		LAYER_HUD:
			return 10
		LAYER_POPUP:
			return 20
		LAYER_SYSTEM:
			return 30
		_:
			return 10
