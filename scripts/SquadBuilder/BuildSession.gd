extends RefCounted
class_name BuildSession

enum State { EDITING, COMMITTED, CANCELED }

var session_id: String
var created_at_msec: int
var state: State = State.EDITING

# resource_id -> qty（物品与员工统一抽象成资源）
var reserved_resources: Dictionary = {}

func _init(new_session_id: String) -> void:
	session_id = new_session_id
	created_at_msec = Time.get_ticks_msec()

func reserve_resource(resource_id: String, quantity: int) -> void:
	if quantity <= 0:
		return
	reserved_resources[resource_id] = int(reserved_resources.get(resource_id, 0)) + quantity

func release_resource(resource_id: String, quantity: int) -> void:
	if quantity <= 0:
		return
	var next_quantity := int(reserved_resources.get(resource_id, 0)) - quantity
	if next_quantity <= 0:
		reserved_resources.erase(resource_id)
	else:
		reserved_resources[resource_id] = next_quantity
