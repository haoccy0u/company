# Inventory Framework README

## 1. 模块总览
本目录是项目的库存系统核心。当前结构已经支持“可继承扩展”。

- `InventoryComponent.gd`
  - 容器组件主入口（挂在场景节点上）。
  - 对外发出唯一库存变更信号：`changed`。
  - 提供统一操作 API：插入、拿取、放入、交换。

- `ItemContainer.gd`
  - 底层格子数据容器。
  - 负责插入规则和 slot 管理。

- `InventorySession.gd`
  - 输入编排层（左键/右键逻辑）。
  - 调用 `InventoryComponent`，不直接处理复杂业务规则。

- `Slot.gd`
  - 单格数据结构与基本操作（`take/place_from/swap_with`）。

- `ItemStack.gd`
  - 鼠标或临时堆栈数据结构。
  - 提供 `clear()`，统一空栈规范化。

- `ItemData.gd`
  - 物品定义（id、图标、最大堆叠等）。

- `ui/BaseInventoryUIPanel.gd`
  - 面板基类（会话、打开/关闭、刷新、信号连接）。

- `ui/BaseInventorySlot.gd`
  - 格子 UI 基类（绑定、刷新、输入分发）。

## 2. 主要调用链
以“点击格子”为例：

1. `BaseInventorySlot._gui_input` 捕获点击。
2. 调用 `InventorySession.left_click/right_click`。
3. `InventorySession` 调用 `InventoryComponent` 的动作 API。
4. `InventoryComponent` 在发生变化时 `changed.emit()`。
5. `BaseInventoryUIPanel` 监听 `changed` 后执行 `refresh_all()`。

## 3. 常用 API 速查
以下接口都在 `InventoryComponent.gd`：

- `try_insert(item, amount) -> int`
  - 返回剩余数量（0 表示全部放入）。

- `try_insert_result(item, amount) -> Dictionary`
  - 返回结构化结果（见下节）。

- `place_from_cursor(index, cursor_stack, amount=-1) -> Dictionary`
  - 将鼠标堆栈放入指定格（支持合并）。

- `take_to_cursor(index, cursor_stack, amount=-1) -> Dictionary`
  - 从指定格拿到鼠标堆栈（`-1` 通常表示整堆）。

- `swap_with_cursor(index, cursor_stack) -> Dictionary`
  - 与鼠标堆栈交换。

## 4. 统一结果结构
当前结果对象采用 Dictionary（过渡版抽象）：

- `changed: bool` 是否发生实际变化
- `moved: int` 本次移动数量
- `remainder: int` 剩余数量
- `reason: StringName` 结果原因（如 `ok`、`invalid_input`）
- `meta: Dictionary` 扩展信息（默认空）

建议：

- UI 和 Session 只依赖这些固定 key。
- 新增特殊规则时，额外信息放在 `meta`，不要改核心 key 名。

## 5. 如何扩展
### 5.1 扩展特殊容器组件
继承 `InventoryComponent`，在子类中增加规则判断（例如限制某类物品）。
保持返回结构不变，避免上层 UI 适配成本。

### 5.2 扩展特殊库存面板
继承 `BaseInventoryUIPanel`：

- 实现 `_on_open_components(...)`
- 实现 `_refresh_views()`
- 按需覆写 `_get_default_close_target()`

### 5.3 扩展特殊格子样式
继承 `BaseInventorySlot`：

- 实现 `_apply_empty_view()`
- 实现 `_apply_stack_view(slot)`

输入分发无需重复写。

## 6. 手动回归清单（建议每次改动后执行）
1. 左键拿整堆
2. 右键拿半堆
3. 同类合并
4. 不同类交换
5. 超上限溢出处理
6. 关闭界面回退成功
7. 跨容器移动
8. 满包回退失败（阻止关闭）

## 7. 当前约束
- `scenes/invtest/` 为临时测试场景。
- 长期维护核心在 `scripts/inventory/`。
- 保持“单一通知源”：对外只使用 `InventoryComponent.changed`。
