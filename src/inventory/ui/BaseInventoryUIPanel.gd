extends Control
class_name BaseInventoryUIPanel

@export var cursor_scene: PackedScene

var cursor_ui: CursorWithItem
var session: InventorySession
var _bound_components: Array[InventoryComponent] = []


#region Public
func _ready() -> void:
	session = InventorySession.new()
	visible = false
	_ensure_cursor()

func open_with_components(components: Array[InventoryComponent]) -> void:
	_disconnect_components()
	_bound_components = components
	_connect_components()
	_on_open_components(components)
	refresh_all()
	visible = true

func refresh_all() -> void:
	_refresh_views()
	if cursor_ui != null:
		cursor_ui.sync(session)

func request_close(fallback: InventoryComponent = null) -> bool:
	var target := fallback if fallback != null else _get_default_close_target()
	var ok := session.return_cursor_to_origin(target)
	if not ok:
		push_warning("Can't close: cursor items couldn't be returned.")
		refresh_all()
		return false

	visible = false
	_on_closed()
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		request_close()
		accept_event()
#endregion


#region Protected
func _on_open_components(_components: Array[InventoryComponent]) -> void:
	pass

func _refresh_views() -> void:
	pass

func _on_closed() -> void:
	pass

func _get_default_close_target() -> InventoryComponent:
	if _bound_components.is_empty():
		return null
	return _bound_components[0]
#endregion


#region Private
func _connect_components() -> void:
	var cb := Callable(self, "refresh_all")
	for comp in _bound_components:
		if comp != null and not comp.changed.is_connected(cb):
			comp.changed.connect(cb)

func _disconnect_components() -> void:
	var cb := Callable(self, "refresh_all")
	for comp in _bound_components:
		if comp != null and comp.changed.is_connected(cb):
			comp.changed.disconnect(cb)

func _ensure_cursor() -> void:
	if cursor_ui != null:
		return
	if cursor_scene == null:
		return
	cursor_ui = cursor_scene.instantiate() as CursorWithItem
	add_child(cursor_ui)
	move_child(cursor_ui, get_child_count() - 1)
#endregion
