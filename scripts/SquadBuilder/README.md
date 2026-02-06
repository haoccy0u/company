# SquadBuilder 代码功能说明

本目录当前包含两个核心脚本：`BuildSession.gd` 与 `WareHouseService.gd`（类名 `WarehouseService`）。

## 1) BuildSession：单次编队编辑会话的数据模型

`BuildSession` 是一个轻量会话对象，负责记录“当前编队草稿”对仓库资源的预占用状态：

- 会话元信息：`session_id`、创建时间 `created_at_msec`、状态 `state`（编辑中 / 已提交 / 已取消）。
- 物品预占用：`reserved_items`（`item_id -> qty`）。
- 人员预占用：`reserved_employees`（`employee_id -> true`）。

它提供最小操作集：

- `reserve_item` / `release_item`：增加或减少某个物品的预占数量。
- `reserve_employee` / `release_employee`：在会话内预占或释放某个员工。

> 该类本身不做跨会话冲突校验，只维护“本会话局部数据”；冲突控制由 `WarehouseService` 负责。

## 2) WarehouseService：真实库存 + 全局预占用的协调器

`WarehouseService` 是核心服务，维护三层状态：

1. **真实资源池**
   - `_real_items`：真实物品库存。
   - `_real_employees`：真实员工池。
2. **会话池**
   - `_sessions`：所有进行中的 `BuildSession`。
3. **全局预占用汇总**
   - `_reserved_items_total`：所有会话的物品预占总和。
   - `_reserved_employees_total`：所有会话里已被占用的员工集合。

并通过 `warehouse_changed` 信号对 UI/系统广播状态变化。

## 3) 可用量计算逻辑

查询接口采用统一规则：

- 物品可用量 = `real - reserved_total`（下限 0）。
- 员工可用性 = 在真实员工池中且不在全局预占集合中。

这使得多个并发编辑会话能看到一致的“剩余可选资源”。

## 4) 会话生命周期

- `create_session()`：创建并返回新 session id。
- `cancel_session(session_id)`：释放该会话全部预占资源、标记取消并移出会话池。

取消或提交都会触发统一的“释放预占用”流程，确保总量账目恢复正确。

## 5) 编辑期的预占用规则

### 物品

- `reserve_item` 只允许正数，且不能超过当前可用量。
- `release_item` 只允许正数，且释放量不能超过该会话当前预占量。
- 每次增减都会同步更新 `_reserved_items_total`。

### 员工

- `reserve_employee` 需要员工存在于真实员工池。
- 同一会话重复占用同一员工是幂等成功。
- 若员工已被其他会话占用，则返回不可用错误。
- `release_employee` 要求该员工确实由该会话占用。

## 6) 提交流程（commit_session）

`commit_session(session_id, squad_build)` 的关键目标是保证“草稿内容”和“会话预占状态”强一致：

1. 从 `squad_build` 汇总所需物品与成员集合。
2. 与会话中记录的 `reserved_items` / `reserved_employees` 做严格比对。
   - 不一致即拒绝提交（避免 UI 草稿与底层预占脱节）。
3. 二次兜底检查真实库存是否足够。
4. 扣减真实库存。
5. 释放该会话的全部预占用。
6. 标记会话为 `COMMITTED` 并移除。
7. 产出 `manifest`（包含 `build_id`、`vehicle_id`、items 与 employees）。

该设计将“编辑期锁定资源”和“最终扣减资源”分离，降低并发编辑的冲突风险。

## 7) 远征回收接口

`add_items(items)` 用于在远征结算后把资源加回真实仓库，不影响会话结构，只更新真实库存并广播变化。

## 8) 内部辅助函数

- `_release_all_reserved_of_session`：统一释放一个会话的物品与员工预占。
- `_recalc_reserved_totals`：根据 `_sessions` 全量重算预占汇总（seed 后保持一致性）。
- `_sum_items_from_build` / `_sum_employees_from_build`：从 `squad_build` 抽取需求。
- `_dict_equal_int` / `_set_equal`：提交前一致性比较。
- `_ok` / `_err`：统一返回结构。
- `_new_id`：生成 session/build id。

## 9) 返回结构与错误风格

该服务接口返回统一字典：

- 成功：`{"ok": true, "payload": {...}}`
- 失败：`{"ok": false, "reason": "...", "details": {...}}`

便于上层 UI 或流程系统进行稳定分支处理。

## 10) 总体设计总结

SquadBuilder 这部分代码本质上实现了一个“带预占用锁定机制的编队构建库存服务”：

- 支持并行会话编辑。
- 防止同一员工被多队同时选中。
- 防止物品超卖。
- 在提交时通过强一致校验保障最终结果可靠。

适合作为“编队 UI 编辑器”与“仓库/远征结算系统”之间的资源一致性中间层。
