class_name ExpeditionLocationDef extends Resource

@export var location_id: StringName
@export var event_sequence: PackedStringArray = []
@export var tags: Array[StringName] = []


func has_event_at(step_index: int) -> bool:
	return step_index >= 0 and step_index < event_sequence.size()


func get_event_spec(step_index: int) -> String:
	if not has_event_at(step_index):
		return ""
	return String(event_sequence[step_index]).strip_edges()


func get_event_type(step_index: int) -> StringName:
	var spec: String = get_event_spec(step_index)
	if spec.is_empty():
		return &""
	var separator_index: int = spec.find(":")
	if separator_index < 0:
		return StringName(spec)
	return StringName(spec.substr(0, separator_index).strip_edges())


func get_event_payload_id(step_index: int) -> StringName:
	var spec: String = get_event_spec(step_index)
	if spec.is_empty():
		return &""
	var separator_index: int = spec.find(":")
	if separator_index < 0:
		return &""
	return StringName(spec.substr(separator_index + 1).strip_edges())
