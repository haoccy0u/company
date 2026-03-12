extends RefCounted
class_name SaveCodecTemplate

const CODEC_UTILS := preload("res://src/save/codecs/SaveCodecUtils.gd")

# Copy this template when adding a new save codec for another system.
# Replace `Node` with the real component type and implement your fields.


static func capture(component: Node) -> Dictionary:
	if component == null:
		return {}

	# Example payload; replace with real data fields.
	return {
		"schema_version": 1,
		"data": {},
	}


static func apply(component: Node, data: Dictionary) -> bool:
	if component == null or data.is_empty():
		return false

	var validation: Dictionary = _validate_and_prepare(component, data)
	if not bool(validation.get("ok", false)):
		return false

	# Read values prepared by validation and apply to runtime state.
	# var prepared_value: Variant = validation.get("prepared_value", null)
	return true


static func _validate_and_prepare(component: Node, data: Dictionary) -> Dictionary:
	if component == null:
		return CODEC_UTILS.fail(
			"SAVE.CODEC.INVALID_COMPONENT",
			"validate",
			"component is null"
		)
	if data.is_empty():
		return CODEC_UTILS.fail(
			"SAVE.CODEC.EMPTY_DATA",
			"validate",
			"data is empty"
		)

	var schema_version: int = int(data.get("schema_version", -1))
	if schema_version != 1:
		return CODEC_UTILS.fail(
			"SAVE.CODEC.UNSUPPORTED_SCHEMA_VERSION",
			"validate",
			"unsupported codec schema version",
			{"expected": 1, "actual": schema_version}
		)

	return CODEC_UTILS.ok()

