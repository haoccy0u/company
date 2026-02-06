extends Node
class_name WarehouseService

# =========================
# Real (真实库存/员工池)
# 统一资源抽象：resource_id -> qty
# - 普通物品：qty >= 0
# - 员工：qty 只允许 0/1
# =========================
var _real_item_quantities: Dictionary = {}
var _real_employee_quantities: Dictionary = {}

# =========================
# Sessions (预占用会话)
# =========================
# session_id -> BuildSession
var _sessions: Dictionary = {}

# 全局预占用汇总：resource_id -> qty
var _reserved_item_quantities_total: Dictionary = {}
var _reserved_employee_quantities_total: Dictionary = {}

signal warehouse_changed

# ------------------------------------------------------------
# Seed 初始化（后续可替换为存档载入）
# ------------------------------------------------------------
func seed_items(real_items: Dictionary) -> void:
	_real_item_quantities = real_items.duplicate(true)
	_recalc_reserved_totals()
	emit_signal("warehouse_changed")

func seed_employees(real_employee_ids: Array[String]) -> void:
	_real_employee_quantities.clear()
	for employee_id in real_employee_ids:
		_real_employee_quantities[String(employee_id)] = 1
	_recalc_reserved_totals()
	emit_signal("warehouse_changed")

# ------------------------------------------------------------
# Query 查询（available = real - reserved_total）
# ------------------------------------------------------------
func get_available_item_qty(item_id: String) -> int:
	item_id = String(item_id)
	var real_quantity := int(_real_item_quantities.get(item_id, 0))
	var reserved_quantity := int(_reserved_item_quantities_total.get(item_id, 0))
	return max(real_quantity - reserved_quantity, 0)

func is_employee_available(employee_id: String) -> bool:
	return get_available_employee_qty(employee_id) > 0

func get_available_employee_qty(employee_id: String) -> int:
	employee_id = String(employee_id)
	var real_quantity := int(_real_employee_quantities.get(employee_id, 0))
	var reserved_quantity := int(_reserved_employee_quantities_total.get(employee_id, 0))
	return max(real_quantity - reserved_quantity, 0)

# 可选：给 UI 一次性刷新用
func get_available_items_snapshot() -> Dictionary:
	var snapshot := {}
	for item_id in _real_item_quantities.keys():
		snapshot[item_id] = get_available_item_qty(item_id)
	return snapshot

func get_available_employees_snapshot() -> Dictionary:
	var snapshot := {}
	for employee_id in _real_employee_quantities.keys():
		snapshot[employee_id] = get_available_employee_qty(employee_id)
	return snapshot

# ------------------------------------------------------------
# Session 生命周期
# ------------------------------------------------------------
func create_session() -> String:
	var session_id := _new_id("sess")
	_sessions[session_id] = BuildSession.new(session_id)
	return session_id

func cancel_session(session_id: String) -> Dictionary:
	var session: BuildSession = _sessions.get(session_id, null)
	if session == null:
		return _err("session_not_found")

	_release_all_reserved_of_session(session)

	session.state = BuildSession.State.CANCELED
	_sessions.erase(session_id)
	emit_signal("warehouse_changed")
	return {"ok": true}

# ------------------------------------------------------------
# Reserve/Release 物品
# ------------------------------------------------------------
func reserve_item(session_id: String, item_id: String, delta_qty: int) -> Dictionary:
	if delta_qty <= 0:
		return _err("bad_qty")

	var session_or_error := _get_editing_session(session_id)
	if not session_or_error["ok"]:
		return session_or_error
	var session: BuildSession = session_or_error["session"]

	item_id = String(item_id)
	var available_quantity := get_available_item_qty(item_id)
	if available_quantity < delta_qty:
		return _err("insufficient_item", {"item_id": item_id, "need": delta_qty, "avail": available_quantity})

	session.reserve_resource(item_id, delta_qty)
	_reserved_item_quantities_total[item_id] = int(_reserved_item_quantities_total.get(item_id, 0)) + delta_qty

	emit_signal("warehouse_changed")
	return {"ok": true}

func release_item(session_id: String, item_id: String, delta_qty: int) -> Dictionary:
	if delta_qty <= 0:
		return _err("bad_qty")

	var session_or_error := _get_editing_session(session_id)
	if not session_or_error["ok"]:
		return session_or_error
	var session: BuildSession = session_or_error["session"]

	item_id = String(item_id)
	var reserved_quantity := int(session.reserved_resources.get(item_id, 0))
	if reserved_quantity < delta_qty:
		return _err("release_exceeds_reserved", {"item_id": item_id, "reserved": reserved_quantity, "release": delta_qty})

	session.release_resource(item_id, delta_qty)

	var next_total_quantity := int(_reserved_item_quantities_total.get(item_id, 0)) - delta_qty
	if next_total_quantity <= 0:
		_reserved_item_quantities_total.erase(item_id)
	else:
		_reserved_item_quantities_total[item_id] = next_total_quantity

	emit_signal("warehouse_changed")
	return {"ok": true}

# ------------------------------------------------------------
# Reserve/Release 员工（员工视为数量上限为 1 的资源）
# ------------------------------------------------------------
func reserve_employee(session_id: String, employee_id: String) -> Dictionary:
	employee_id = String(employee_id)
	if not _real_employee_quantities.has(employee_id):
		return _err("employee_not_found", {"employee_id": employee_id})
	return reserve_employee_qty(session_id, employee_id, 1)

func release_employee(session_id: String, employee_id: String) -> Dictionary:
	employee_id = String(employee_id)
	return release_employee_qty(session_id, employee_id, 1)

func reserve_employee_qty(session_id: String, employee_id: String, delta_qty: int) -> Dictionary:
	if delta_qty != 1:
		return _err("employee_qty_must_be_one", {"employee_id": employee_id, "qty": delta_qty})

	var session_or_error := _get_editing_session(session_id)
	if not session_or_error["ok"]:
		return session_or_error
	var session: BuildSession = session_or_error["session"]

	var available_quantity := get_available_employee_qty(employee_id)
	var already_reserved_quantity := int(session.reserved_resources.get(employee_id, 0))
	if already_reserved_quantity >= 1:
		return {"ok": true}
	if available_quantity < 1:
		return _err("employee_unavailable", {"employee_id": employee_id})

	session.reserve_resource(employee_id, 1)
	_reserved_employee_quantities_total[employee_id] = int(_reserved_employee_quantities_total.get(employee_id, 0)) + 1

	emit_signal("warehouse_changed")
	return {"ok": true}

func release_employee_qty(session_id: String, employee_id: String, delta_qty: int) -> Dictionary:
	if delta_qty != 1:
		return _err("employee_qty_must_be_one", {"employee_id": employee_id, "qty": delta_qty})

	var session_or_error := _get_editing_session(session_id)
	if not session_or_error["ok"]:
		return session_or_error
	var session: BuildSession = session_or_error["session"]

	if int(session.reserved_resources.get(employee_id, 0)) < 1:
		return _err("employee_not_reserved_in_session", {"employee_id": employee_id})

	session.release_resource(employee_id, 1)
	var next_total_quantity := int(_reserved_employee_quantities_total.get(employee_id, 0)) - 1
	if next_total_quantity <= 0:
		_reserved_employee_quantities_total.erase(employee_id)
	else:
		_reserved_employee_quantities_total[employee_id] = next_total_quantity

	emit_signal("warehouse_changed")
	return {"ok": true}

# ------------------------------------------------------------
# Commit：扣除 real，并返回 manifest（远征系统保存）
# 强一致：提交内容必须与该 session 的预占用一致
# ------------------------------------------------------------
func commit_session(session_id: String, squad_build: Dictionary) -> Dictionary:
	var session_or_error := _get_editing_session(session_id)
	if not session_or_error["ok"]:
		return session_or_error
	var session: BuildSession = session_or_error["session"]

	var required_item_quantities := _sum_items_from_build(squad_build)
	var required_employee_quantities := _sum_employees_from_build(squad_build)
	var required_resource_quantities := _merge_resource_requirements(required_item_quantities, required_employee_quantities)

	# 强一致校验：避免 UI draft 与 session 占用不同步
	if not _dict_equal_int(required_resource_quantities, session.reserved_resources):
		return _err("commit_mismatch_resources", {"need": required_resource_quantities, "reserved": session.reserved_resources})

	# 扣除真实库存（兜底检查，理论上不会失败）
	for item_id in required_item_quantities.keys():
		var quantity := int(required_item_quantities[item_id])
		var real_quantity := int(_real_item_quantities.get(item_id, 0))
		if real_quantity < quantity:
			return _err("real_stock_inconsistent", {"item_id": item_id, "real": real_quantity, "need": quantity})

	for employee_id in required_employee_quantities.keys():
		var real_employee_quantity := int(_real_employee_quantities.get(employee_id, 0))
		if real_employee_quantity < 1:
			return _err("real_employee_inconsistent", {"employee_id": employee_id, "real": real_employee_quantity, "need": 1})

	for item_id in required_item_quantities.keys():
		var consumed_quantity := int(required_item_quantities[item_id])
		var remain_item_quantity := int(_real_item_quantities.get(item_id, 0)) - consumed_quantity
		if remain_item_quantity <= 0:
			_real_item_quantities.erase(item_id)
		else:
			_real_item_quantities[item_id] = remain_item_quantity

	for employee_id in required_employee_quantities.keys():
		_real_employee_quantities.erase(employee_id)

	# 释放预占用（因为已扣 real）
	_release_all_reserved_of_session(session)

	session.state = BuildSession.State.COMMITTED
	_sessions.erase(session_id)

	var build_id := _new_id("build")
	var manifest := {
		"build_id": build_id,
		"vehicle_id": String(squad_build.get("vehicle_id", "")),
		"items": required_item_quantities,
		"employees": required_employee_quantities.keys()
	}

	emit_signal("warehouse_changed")
	return {"ok": true, "build_id": build_id, "manifest": manifest}

# ------------------------------------------------------------
# 远征结算：加回仓库（远征系统调用）
# ------------------------------------------------------------
func add_items(items: Dictionary) -> Dictionary:
	for item_id in items.keys():
		var quantity := int(items[item_id])
		if quantity <= 0:
			continue
		item_id = String(item_id)
		_real_item_quantities[item_id] = int(_real_item_quantities.get(item_id, 0)) + quantity
	emit_signal("warehouse_changed")
	return {"ok": true}

func add_employees(employee_ids: Array[String]) -> Dictionary:
	for employee_id in employee_ids:
		_real_employee_quantities[String(employee_id)] = 1
	emit_signal("warehouse_changed")
	return {"ok": true}

# ------------------------------------------------------------
# 内部：释放 session 的全部预占用（更新 totals）
# ------------------------------------------------------------
func _release_all_reserved_of_session(session: BuildSession) -> void:
	for resource_id in session.reserved_resources.keys():
		var quantity := int(session.reserved_resources[resource_id])
		if _reserved_item_quantities_total.has(resource_id):
			var next_item_total := int(_reserved_item_quantities_total.get(resource_id, 0)) - quantity
			if next_item_total <= 0:
				_reserved_item_quantities_total.erase(resource_id)
			else:
				_reserved_item_quantities_total[resource_id] = next_item_total
		if _reserved_employee_quantities_total.has(resource_id):
			var next_employee_total := int(_reserved_employee_quantities_total.get(resource_id, 0)) - quantity
			if next_employee_total <= 0:
				_reserved_employee_quantities_total.erase(resource_id)
			else:
				_reserved_employee_quantities_total[resource_id] = next_employee_total
	session.reserved_resources.clear()

func _recalc_reserved_totals() -> void:
	_reserved_item_quantities_total.clear()
	_reserved_employee_quantities_total.clear()
	for session_id in _sessions.keys():
		var session: BuildSession = _sessions[session_id]
		for resource_id in session.reserved_resources.keys():
			var quantity := int(session.reserved_resources[resource_id])
			if _real_item_quantities.has(resource_id):
				_reserved_item_quantities_total[resource_id] = int(_reserved_item_quantities_total.get(resource_id, 0)) + quantity
			elif _real_employee_quantities.has(resource_id):
				_reserved_employee_quantities_total[resource_id] = int(_reserved_employee_quantities_total.get(resource_id, 0)) + quantity

# ------------------------------------------------------------
# 内部：从 SquadBuild 汇总需求
# ------------------------------------------------------------
func _sum_items_from_build(squad_build: Dictionary) -> Dictionary:
	var item_quantities := {}
	if squad_build.has("cargo_items"):
		for cargo_entry in squad_build["cargo_items"]:
			var item_id := String(cargo_entry["item_id"])
			var quantity := int(cargo_entry["qty"])
			item_quantities[item_id] = int(item_quantities.get(item_id, 0)) + quantity

	if squad_build.has("member_loadouts"):
		var member_loadouts: Dictionary = squad_build["member_loadouts"]
		for employee_id in member_loadouts.keys():
			for loadout_entry in member_loadouts[employee_id]:
				var loadout_item_id := String(loadout_entry["item_id"])
				var loadout_quantity := int(loadout_entry["qty"])
				item_quantities[loadout_item_id] = int(item_quantities.get(loadout_item_id, 0)) + loadout_quantity

	for item_id in item_quantities.keys():
		if int(item_quantities[item_id]) <= 0:
			item_quantities.erase(item_id)
	return item_quantities

func _sum_employees_from_build(squad_build: Dictionary) -> Dictionary:
	var employee_quantities := {}
	if squad_build.has("member_ids"):
		for employee_id in squad_build["member_ids"]:
			employee_quantities[String(employee_id)] = 1
	return employee_quantities

func _merge_resource_requirements(item_requirements: Dictionary, employee_requirements: Dictionary) -> Dictionary:
	var required_resources := item_requirements.duplicate(true)
	for employee_id in employee_requirements.keys():
		required_resources[employee_id] = int(employee_requirements[employee_id])
	return required_resources

# ------------------------------------------------------------
# 内部：工具
# ------------------------------------------------------------
func _get_editing_session(session_id: String) -> Dictionary:
	var session: BuildSession = _sessions.get(session_id, null)
	if session == null:
		return _err("session_not_found")
	if session.state != BuildSession.State.EDITING:
		return _err("session_not_editing")
	return {"ok": true, "session": session}

func _dict_equal_int(lhs: Dictionary, rhs: Dictionary) -> bool:
	if lhs.size() != rhs.size():
		return false
	for key in lhs.keys():
		if not rhs.has(key):
			return false
		if int(lhs[key]) != int(rhs[key]):
			return false
	return true

func _err(reason: String, details: Dictionary = {}) -> Dictionary:
	return {"ok": false, "reason": reason, "details": details}

func _new_id(prefix: String) -> String:
	return "%s_%d_%d" % [prefix, randi(), Time.get_ticks_msec()]
