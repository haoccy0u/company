extends Node
class_name WarehouseService

# =========================
# Real (真实库存/员工池)
# =========================
# item_id -> qty
var _real_items: Dictionary = {}
# employee_id -> true
var _real_employees: Dictionary = {}

# =========================
# Sessions (预占用会话)
# =========================
# session_id -> BuildSession
var _sessions: Dictionary = {}

# 全局预占用汇总：item_id -> qty
var _reserved_items_total: Dictionary = {}
# 全局预占用员工：employee_id -> true
var _reserved_employees_total: Dictionary = {}

signal warehouse_changed

# ------------------------------------------------------------
# Seed 初始化（后续可替换为存档载入）
# ------------------------------------------------------------
func seed_items(real_items: Dictionary) -> void:
	_real_items = real_items.duplicate(true)
	_recalc_reserved_totals()
	emit_signal("warehouse_changed")

func seed_employees(real_employee_ids: Array[String]) -> void:
	_real_employees.clear()
	for eid in real_employee_ids:
		_real_employees[String(eid)] = true
	_recalc_reserved_totals()
	emit_signal("warehouse_changed")

# ------------------------------------------------------------
# Query 查询（available = real - reserved_total）
# ------------------------------------------------------------
func get_available_item_qty(item_id: String) -> int:
	item_id = String(item_id)
	var real := int(_real_items.get(item_id, 0))
	var reserved := int(_reserved_items_total.get(item_id, 0))
	return max(real - reserved, 0)

func is_employee_available(employee_id: String) -> bool:
	employee_id = String(employee_id)
	if not _real_employees.has(employee_id):
		return false
	return not _reserved_employees_total.has(employee_id)

# 可选：给 UI 一次性刷新用
func get_available_items_snapshot() -> Dictionary:
	var out := {}
	for item_id in _real_items.keys():
		out[item_id] = get_available_item_qty(item_id)
	return out

# ------------------------------------------------------------
# Session 生命周期
# ------------------------------------------------------------
func create_session() -> String:
	var sid := _new_id("sess")
	_sessions[sid] = BuildSession.new(sid)
	return sid

func cancel_session(session_id: String) -> Dictionary:
	var s: BuildSession = _sessions.get(session_id, null)
	if s == null:
		return _err("session_not_found")

	_release_all_reserved_of_session(s)

	s.state = BuildSession.State.CANCELED
	_sessions.erase(session_id)
	emit_signal("warehouse_changed")
	return _ok()

# ------------------------------------------------------------
# Reserve/Release 物品
# ------------------------------------------------------------
func reserve_item(session_id: String, item_id: String, delta_qty: int) -> Dictionary:
	if delta_qty <= 0:
		return _err("bad_qty")

	var s: BuildSession = _sessions.get(session_id, null)
	if s == null:
		return _err("session_not_found")
	if s.state != BuildSession.State.EDITING:
		return _err("session_not_editing")

	item_id = String(item_id)
	var avail := get_available_item_qty(item_id)
	if avail < delta_qty:
		return _err("insufficient_item", {"item_id": item_id, "need": delta_qty, "avail": avail})

	s.reserve_item(item_id, delta_qty)
	_reserved_items_total[item_id] = int(_reserved_items_total.get(item_id, 0)) + delta_qty

	emit_signal("warehouse_changed")
	return _ok()

func release_item(session_id: String, item_id: String, delta_qty: int) -> Dictionary:
	if delta_qty <= 0:
		return _err("bad_qty")

	var s: BuildSession = _sessions.get(session_id, null)
	if s == null:
		return _err("session_not_found")
	if s.state != BuildSession.State.EDITING:
		return _err("session_not_editing")

	item_id = String(item_id)
	var cur := int(s.reserved_items.get(item_id, 0))
	if cur < delta_qty:
		return _err("release_exceeds_reserved", {"item_id": item_id, "reserved": cur, "release": delta_qty})

	s.release_item(item_id, delta_qty)

	var tot := int(_reserved_items_total.get(item_id, 0)) - delta_qty
	if tot <= 0:
		_reserved_items_total.erase(item_id)
	else:
		_reserved_items_total[item_id] = tot

	emit_signal("warehouse_changed")
	return _ok()

# ------------------------------------------------------------
# Reserve/Release 员工（编辑期防止多队选同一人）
# ------------------------------------------------------------
func reserve_employee(session_id: String, employee_id: String) -> Dictionary:
	var s: BuildSession = _sessions.get(session_id, null)
	if s == null:
		return _err("session_not_found")
	if s.state != BuildSession.State.EDITING:
		return _err("session_not_editing")

	employee_id = String(employee_id)
	if not _real_employees.has(employee_id):
		return _err("employee_not_found", {"employee_id": employee_id})

	# 幂等：该 session 已占用则直接 ok
	if s.reserved_employees.has(employee_id):
		return _ok()

	# 不能被别的 session 占用
	if _reserved_employees_total.has(employee_id):
		return _err("employee_unavailable", {"employee_id": employee_id})

	s.reserve_employee(employee_id)
	_reserved_employees_total[employee_id] = true

	emit_signal("warehouse_changed")
	return _ok()

func release_employee(session_id: String, employee_id: String) -> Dictionary:
	var s: BuildSession = _sessions.get(session_id, null)
	if s == null:
		return _err("session_not_found")
	if s.state != BuildSession.State.EDITING:
		return _err("session_not_editing")

	employee_id = String(employee_id)
	if not s.reserved_employees.has(employee_id):
		return _err("employee_not_reserved_in_session", {"employee_id": employee_id})

	s.release_employee(employee_id)
	_reserved_employees_total.erase(employee_id)

	emit_signal("warehouse_changed")
	return _ok()

# ------------------------------------------------------------
# Commit：扣除 real，并返回 manifest（远征系统保存）
# 强一致：提交内容必须与该 session 的预占用一致
# ------------------------------------------------------------
func commit_session(session_id: String, squad_build: Dictionary) -> Dictionary:
	var s: BuildSession = _sessions.get(session_id, null)
	if s == null:
		return _err("session_not_found")
	if s.state != BuildSession.State.EDITING:
		return _err("session_not_editing")

	var need_items := _sum_items_from_build(squad_build)       # item_id->qty
	var need_employees := _sum_employees_from_build(squad_build) # employee_id->true

	# 强一致校验：避免 UI draft 与 session 占用不同步
	if not _dict_equal_int(need_items, s.reserved_items):
		return _err("commit_mismatch_items", {"need": need_items, "reserved": s.reserved_items})
	if not _set_equal(need_employees, s.reserved_employees):
		return _err("commit_mismatch_employees", {"need": need_employees.keys(), "reserved": s.reserved_employees.keys()})

	# 扣除真实库存（兜底检查，理论上不会失败）
	for item_id in need_items.keys():
		var qty := int(need_items[item_id])
		var real := int(_real_items.get(item_id, 0))
		if real < qty:
			return _err("real_stock_inconsistent", {"item_id": item_id, "real": real, "need": qty})

		_real_items[item_id] = real - qty
		if int(_real_items[item_id]) <= 0:
			_real_items.erase(item_id)

	# 释放预占用（因为已扣 real）
	_release_all_reserved_of_session(s)

	s.state = BuildSession.State.COMMITTED
	_sessions.erase(session_id)

	var build_id := _new_id("build")
	var manifest := {
		"build_id": build_id,
		"vehicle_id": String(squad_build.get("vehicle_id", "")),
		"items": need_items,                   # item_id -> qty
		"employees": need_employees.keys()     # Array[employee_id]
	}

	emit_signal("warehouse_changed")
	return _ok({"build_id": build_id, "manifest": manifest})

# ------------------------------------------------------------
# 远征结算：加回仓库（远征系统调用）
# ------------------------------------------------------------
func add_items(items: Dictionary) -> Dictionary:
	for item_id in items.keys():
		var qty := int(items[item_id])
		if qty <= 0:
			continue
		item_id = String(item_id)
		_real_items[item_id] = int(_real_items.get(item_id, 0)) + qty
	emit_signal("warehouse_changed")
	return _ok()

# ------------------------------------------------------------
# 内部：释放 session 的全部预占用（更新 totals）
# ------------------------------------------------------------
func _release_all_reserved_of_session(s: BuildSession) -> void:
	# items
	for item_id in s.reserved_items.keys():
		var qty := int(s.reserved_items[item_id])
		var tot := int(_reserved_items_total.get(item_id, 0)) - qty
		if tot <= 0:
			_reserved_items_total.erase(item_id)
		else:
			_reserved_items_total[item_id] = tot
	s.reserved_items.clear()

	# employees
	for eid in s.reserved_employees.keys():
		_reserved_employees_total.erase(eid)
	s.reserved_employees.clear()

func _recalc_reserved_totals() -> void:
	_reserved_items_total.clear()
	_reserved_employees_total.clear()
	for sid in _sessions.keys():
		var s: BuildSession = _sessions[sid]
		for item_id in s.reserved_items.keys():
			_reserved_items_total[item_id] = int(_reserved_items_total.get(item_id, 0)) + int(s.reserved_items[item_id])
		for eid in s.reserved_employees.keys():
			_reserved_employees_total[eid] = true

# ------------------------------------------------------------
# 内部：从 SquadBuild 汇总需求
# ------------------------------------------------------------
func _sum_items_from_build(sb: Dictionary) -> Dictionary:
	var out := {}
	if sb.has("cargo_items"):
		for e in sb["cargo_items"]:
			var item_id := String(e["item_id"])
			var qty := int(e["qty"])
			out[item_id] = int(out.get(item_id, 0)) + qty

	if sb.has("member_loadouts"):
		var ml: Dictionary = sb["member_loadouts"]
		for eid in ml.keys():
			for e in ml[eid]:
				var item_id := String(e["item_id"])
				var qty := int(e["qty"])
				out[item_id] = int(out.get(item_id, 0)) + qty

	for k in out.keys():
		if int(out[k]) <= 0:
			out.erase(k)
	return out

func _sum_employees_from_build(sb: Dictionary) -> Dictionary:
	var out := {}
	if sb.has("member_ids"):
		for eid in sb["member_ids"]:
			out[String(eid)] = true
	return out

# ------------------------------------------------------------
# 内部：工具
# ------------------------------------------------------------
func _dict_equal_int(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in a.keys():
		if not b.has(k):
			return false
		if int(a[k]) != int(b[k]):
			return false
	return true

func _set_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in a.keys():
		if not b.has(k):
			return false
	return true

func _ok(payload: Dictionary = {}) -> Dictionary:
	return {"ok": true, "payload": payload}

func _err(reason: String, details: Dictionary = {}) -> Dictionary:
	return {"ok": false, "reason": reason, "details": details}

func _new_id(prefix: String) -> String:
	return "%s_%d_%d" % [prefix, randi(), Time.get_ticks_msec()]
