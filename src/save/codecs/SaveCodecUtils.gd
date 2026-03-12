extends RefCounted
class_name SaveCodecUtils


static func ok(extra: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {"ok": true}
	for key in extra.keys():
		out[key] = extra[key]
	return out


static func fail(code: String, stage: String, message: String = "", context: Dictionary = {}) -> Dictionary:
	return {
		"ok": false,
		"error": make_issue(code, stage, message, context),
	}


static func make_issue(code: String, stage: String, message: String = "", context: Dictionary = {}) -> Dictionary:
	return {
		"code": code,
		"stage": stage,
		"message": message,
		"context": context.duplicate(true),
	}


static func dict_or_empty(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value as Dictionary
	return {}


static func array_or_empty(value: Variant) -> Array:
	if value is Array:
		return value as Array
	return []

