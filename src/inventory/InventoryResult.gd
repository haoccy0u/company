extends RefCounted
class_name InventoryResult

const KEY_CHANGED := "changed"
const KEY_MOVED := "moved"
const KEY_REMAINDER := "remainder"
const KEY_REASON := "reason"
const KEY_META := "meta"


static func make(
	did_change: bool,
	moved: int,
	remainder: int,
	reason: StringName,
	meta: Dictionary = {},
	include_meta: bool = true
) -> Dictionary:
	var result: Dictionary = {
		KEY_CHANGED: did_change,
		KEY_MOVED: moved,
		KEY_REMAINDER: remainder,
		KEY_REASON: reason
	}
	if include_meta:
		result[KEY_META] = meta
	return result


static func changed_of(result: Dictionary) -> bool:
	return bool(result.get(KEY_CHANGED, false))


static func remainder_of(result: Dictionary) -> int:
	return int(result.get(KEY_REMAINDER, 0))
