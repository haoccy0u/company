class_name TestPanelBase extends VBoxContainer

signal log_requested(message: String)


func panel_title() -> String:
	return name


func on_panel_activated() -> void:
	pass


func on_panel_deactivated() -> void:
	pass


func log_line(message: String) -> void:
	log_requested.emit(message)
