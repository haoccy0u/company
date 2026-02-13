# 存档系统说明（V1）

## 1. 目标与原则
- 目标：提供可复用、可扩展的通用存档框架，支持后续模块持续接入。
- 存储格式：JSON（便于调试、定位问题、人工排查）。
- 存档路径：`user://saves/`。
- 设计原则：业务模块只负责“导出/恢复自身状态”，文件读写统一由 `SaveManager` 处理。

## 2. 当前目录结构
- `src/save/SaveManager.gd`：存档总控（Autoload 单例）。
- `src/save/Saveable.gd`：Saveable 协议校验（鸭子类型检查）。
- `src/save/SaveReport.gd`：存档结果对象（report）构建与字段访问工具。
- `src/save/codecs/InventorySaveCodec.gd`：库存编解码逻辑。
- `src/save/README.md`：本文档。

## 3. 核心架构

### 3.1 SaveManager（统一编排）
- 负责收集可存档节点、序列化 JSON、写盘、读盘、分发恢复数据。
- 对外主入口：
  - `SaveManager.save_slot(save_slot_id)`
  - `SaveManager.load_slot(save_slot_id)`
  - `SaveManager.delete_slot(save_slot_id)`
  - `SaveManager.list_save_slots()`

### 3.2 Saveable 协议（模块接入标准）
- 任意节点加入 `saveable` 组后，如果实现以下方法，即可被框架接入：
  - `get_save_id() -> String`
  - `capture_state() -> Dictionary`
  - `apply_state(data: Dictionary) -> bool`
- 可选：
  - `get_save_type() -> String`（用于日志和调试分类）

### 3.3 Codec 层（推荐）
- 编解码逻辑放在 `src/save/codecs/*`，避免把复杂序列化代码堆到业务组件里。
- 业务组件保持薄层：
  - `capture_state()` 只委托给 codec
  - `apply_state(data)` 只委托给 codec

## 4. 命名约定（避免与 Inventory 的 slot 混淆）
- 存档槽位统一命名为 `save_slot`。
- 默认文件命名：
  - `user://saves/save_slot_1.json`
  - `user://saves/save_slot_2.json`
- 方法参数统一使用 `save_slot_id`（而不是 `slot`）。

## 5. JSON 结构（V1）
```json
{
  "version": 1,
  "saved_at_unix": 1739400000,
  "nodes": [
    {
      "id": "player_inventory",
      "type": "inventory",
      "state": {
        "slot_count": 27,
        "container_id": "backpack",
        "slots": [
          { "index": 0, "item_id": "red", "item_path": "res://data/item_red.tres", "count": 32 }
        ]
      }
    }
  ]
}
```

## 6. 在项目中如何使用
1. 在 `project.godot` 中将 `SaveManager.gd` 配置为 Autoload，名称为 `SaveManager`。
2. 需要存档的节点加入 `saveable` 组。
3. 调用：
   - 保存：`SaveManager.save_slot(1)`
   - 读取：`SaveManager.load_slot(1)`

说明：
- `SaveManager.gd` 作为 Autoload 使用即可，不需要 `class_name`。

## 7. 新模块接入流程（面向后续扩展）

以“玩家属性模块”或“任务模块”为例，推荐按以下步骤：
1. 在业务组件中实现 Saveable 协议方法（`get_save_id/capture_state/apply_state`）。
2. 新建对应 codec（例如 `AttributeSaveCodec.gd`），封装模块的状态转换。
3. 组件方法内只委托 codec，不直接写复杂序列化细节。
4. 为该组件设置稳定且唯一的 `save_id`（同场景树内不可重复）。
5. 在测试场景做保存-修改-读取回归验证。

## 8. 库存模块接入约定（当前实现）
- 存纯数据，不存对象引用。
- 关键字段：
  - `slot_count`
  - `container_id`
  - `slots[index, item_id, item_path, count]`
- 读档恢复顺序：
  - 先按 `item_path` 恢复
  - 再按 `item_id` 兜底查找

## 9. 版本与兼容策略
- 当前版本：`version = 1`
- 后续如果存档结构变更，建议在 `SaveManager` 增加版本迁移流程。
- 旧文件名若是 `slot_*.json`，请迁移或重命名为 `save_slot_*.json` 才能被当前版本识别。

## 10. 测试建议

### 10.1 功能验证
1. 进入测试场景，调整库存状态。
2. 执行 `save_slot` 保存。
3. 再次改动状态。
4. 执行 `load_slot` 读取。
5. 确认状态回到保存时。

### 10.2 异常验证
1. 人工破坏 JSON（如删除 `state` 字段）。
2. 执行读取，确认不会崩溃且有错误报告。
3. 制造重复 `save_id`，确认日志能提示冲突。
