# SquadBuilder 代码功能说明

本目录当前包含两个核心脚本：`BuildSession.gd` 与 `WareHouseService.gd`（类名 `WarehouseService`）。

## 1) BuildSession：单次编队编辑会话的数据模型

`BuildSession` 负责记录编队编辑期对资源的预占状态：

- 会话元信息：`session_id`、创建时间 `created_at_msec`、状态 `state`（编辑中 / 已提交 / 已取消）。
- 会话预占用：`reserved_resources`（`resource_id -> qty`）。

其中资源采用统一抽象：

- 普通物品可为任意正整数数量。
- 员工也被视为资源，数量只允许 0/1。

## 2) WarehouseService：真实库存 + 全局预占用协调器

`WarehouseService` 维护四类核心状态：

1. 真实物品库存：`_real_item_quantities`
2. 真实员工池（0/1 量化）：`_real_employee_quantities`
3. 会话池：`_sessions`
4. 全局预占总量：`_reserved_item_quantities_total` / `_reserved_employee_quantities_total`

并通过 `warehouse_changed` 信号通知 UI 刷新。

## 3) 统一资源规则

- 物品可用量：`real_item - reserved_item`
- 员工可用量：`real_employee(0/1) - reserved_employee(0/1)`

因此 UI 可按“资源是否可用（数量 > 0）”进行统一筛选。

## 4) 会话生命周期

- `create_session()`：创建会话。
- `cancel_session(session_id)`：释放该会话预占用并取消。
- `commit_session(session_id, squad_build)`：校验一致性后提交并扣减真实资源。

## 5) 提交流程要点

提交时会把 `squad_build` 汇总为：

- 物品需求：`_sum_items_from_build`
- 员工需求：`_sum_employees_from_build`（每人固定 1）

再合并成统一资源需求并与会话预占量做强一致校验，不一致则拒绝提交。

校验通过后：

1. 扣减真实库存 / 真实员工池
2. 释放会话预占
3. 标记会话为 `COMMITTED`
4. 返回 `build_id` 与 `manifest`

## 6) 返回结构

- 成功返回：`{"ok": true, ...}`
- 失败返回：`{"ok": false, "reason": "...", "details": {...}}`

当前仅保留 `_err` 错误构造函数，成功结果按场景直接返回。
