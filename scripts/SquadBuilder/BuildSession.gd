extends RefCounted
class_name BuildSession

enum State { EDITING, COMMITTED, CANCELED }

var session_id: String
var created_at_msec: int
var state: State = State.EDITING

# item_id -> qty
var reserved_items: Dictionary = {}
# employee_id -> true
var reserved_employees: Dictionary = {}

func _init(_session_id: String) -> void:
	session_id = _session_id
	created_at_msec = Time.get_ticks_msec()

func reserve_item(item_id: String, qty: int) -> void:
	if qty <= 0:
		return
	reserved_items[item_id] = int(reserved_items.get(item_id, 0)) + qty

func release_item(item_id: String, qty: int) -> void:
	if qty <= 0:
		return
	var cur := int(reserved_items.get(item_id, 0)) - qty
	if cur <= 0:
		reserved_items.erase(item_id)
	else:
		reserved_items[item_id] = cur

func reserve_employee(employee_id: String) -> void:
	reserved_employees[employee_id] = true

func release_employee(employee_id: String) -> void:
	reserved_employees.erase(employee_id)
