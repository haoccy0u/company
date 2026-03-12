# 存档系统说明（V2）

## 1. 目标
- 当前目标：先把单文件 JSON 的存档/读档行为做稳，不做分片。
- 重点：正确性、可诊断性、可回滚。

## 2. 存储与结构
- 存档目录：`user://saves/`
- 文件命名：`save_slot_{id}.json`
- 文件结构（V2）：

```json
{
  "meta": {
    "version": 2,
    "saved_at_unix": 1739400000
  },
  "domains": {},
  "scene_nodes": [
    {
      "id": "player_inventory",
      "type": "inventory",
      "state": {}
    }
  ]
}
```

说明：
- `scene_nodes`：由 `saveable` 组节点导出/恢复。
- `domains`：预留的全局域数据入口（本轮先保留空对象）。

## 3. SaveManager 行为（V2）
对外入口保持不变：
- `SaveManager.save_slot(save_slot_id)`
- `SaveManager.load_slot(save_slot_id)`
- `SaveManager.load_slot_filtered(save_slot_id, allowed_save_ids)`
- `SaveManager.delete_slot(save_slot_id)`
- `SaveManager.list_save_slots()`

### 3.1 保存阶段
`collect -> validate -> build_payload -> atomic_write -> finalize_report`

### 3.2 读取阶段
`read_text -> parse_with_error -> validate_schema/version -> apply -> finalize_report`

### 3.3 原子写入
- 先写临时文件：`*.json.tmp`
- 再提交覆盖正式文件
- 写入失败时保留旧正式文件

## 4. SaveReport 契约（工程化）
主字段：
- `status`: `succeeded | partial | failed`
- `success`: 布尔兼容字段，规则：`status != failed`
- `ok`: 兼容字段（已弃用，值与 `success` 同步）

诊断字段：
- `errors`: `Array[Dictionary]`
- `warnings`: `Array[Dictionary]`
- `saved_ids / loaded_ids / missing_ids / skipped_nodes`
- `metrics`:
  - `saved_count`
  - `loaded_count`
  - `missing_count`
  - `skipped_count`
- `meta`:
  - `action`
  - `save_slot_id`
  - `path`
  - `schema_version`
  - `generated_at_unix`

错误/警告项结构：
```json
{
  "code": "SAVE.PARSE.JSON_PARSE_FAILED",
  "stage": "parse",
  "message": "具体错误信息",
  "context": {}
}
```

## 5. Saveable 接入要求
节点加入 `saveable` 组后，需要实现：
- `get_save_id() -> String`
- `capture_state() -> Dictionary`
- `apply_state(data: Dictionary) -> bool`

可选：
- `get_save_type() -> String`

建议：
- 关键模块必须提供稳定 `save_id`，不要依赖动态节点路径。

### 5.1 save_id 命名规范（路径式）
推荐格式：`<system>/<object>/<instance>`（全局单例可 2 段）

规则：
- 全小写
- 分段使用 `/`
- 每段只允许 `a-z0-9_`
- 推荐 3 段，允许 2 段

示例（推荐）：
- `inventory/player/main_bag`
- `inventory/chest/chest_01`
- `progress/player/roster`
- `progress/player/item_vault`

反例（不推荐）：
- `/root/Inventorytest/player/PlayerInv`（节点路径，不稳定）
- `Inventory/Player/MainBag`（大写）
- `inventory-player-main`（分隔符不规范）

说明：
- 当前版本对非标准格式只记 `warning`（`SAVE.COLLECT.NON_STANDARD_SAVE_ID`），不阻断保存。
- `save_id` 仍必须满足“非空 + 同场景唯一”。

### 5.2 手动配置 saveable（检查器）
1. 在场景树选中目标节点。  
2. 右侧 `Node` 面板 -> `Groups` -> 添加组名 `saveable`。  
3. 确认脚本实现：
   - `get_save_id() -> String`
   - `capture_state() -> Dictionary`
   - `apply_state(data: Dictionary) -> bool`
4. 在检查器里设置稳定 `save_id`（例如 `inventory/player/main_bag`）。  
5. 运行后执行一次 `save_slot -> load_slot` 回归，确认 report 无重复/空 id 错误。

## 6. Codec 约定模板
- 工具骨架：`src/save/codecs/SaveCodecUtils.gd`
  - `ok(...) / fail(...) / make_issue(...)`
  - `dict_or_empty(...) / array_or_empty(...)`
- 模板文件：`src/save/codecs/SaveCodecTemplate.gd`
  - 约定结构：`capture -> validate_and_prepare -> apply`
  - 新系统建议复制该模板，再替换为自己的组件类型和字段。

## 7. Inventory 行为约束（V2）
- `InventorySaveCodec.apply()` 采用“先完整校验，再清空并应用”的策略。
- 校验失败时返回 `false`，避免坏档把运行态清空。
- 物品恢复优先使用缓存/解析器，避免反复递归全目录扫描。

## 8. PlayerProgress（场景化 Autoload）
- 全局入口：`/root/PlayerProgressRoot`（`res://src/player_progress/PlayerProgressRoot.tscn`）。
- 启动自举（默认 `save_slot=1`）：
  - 若 slot 存在：调用 `load_slot_filtered`，仅加载 `progress/player/*`。
  - 若 slot 不存在：创建空 roster，并立即 `save_slot(1)` 生成首档。
  - 若加载失败：回退到空 roster，并记录 `boot_status=load_failed_fallback_empty`。
- 子模块按 saveable 独立接入：
  - `progress/player/roster`（`PlayerRosterState`）
  - `progress/player/item_vault`（`PlayerItemVaultState`，当前为空壳）
- `PlayerRosterState` 使用 `PlayerProgressCodec` 的 `roster` 分支：
  - 结构：`schema_version + roster.players`
  - 读档行为：先完整校验再提交，失败时返回 `false`，不覆盖当前运行态。
- `PlayerRosterState` 初始化不再依赖默认 `.tres`，统一为空模板初始化（`reset_to_empty_roster`）。

## 9. 兼容策略
- 当前只接受 `meta.version == 2`。
- V1/非法结构读取会返回 `failed` 与 `unsupported_version`（不做自动迁移）。
- `ok` 字段暂时保留一版，后续可删除。
- 旧档中缺失 `progress/player/*` 条目时，不会导致崩溃；对应模块保持默认运行态。

## 10. 人工验证清单
1. 正常回归：
   - invtest 保存 -> 改库存 -> 读取，状态应恢复，`status = succeeded`。
   - roster 保存 -> 修改运行态 roster -> 读取，`progress/player/roster` 恢复正确。
   - 删除 `save_slot_1.json` 后启动，自动创建空 roster 并生成首档。
2. 坏档防污染：
   - 人工破坏 `scene_nodes` 或 `slots` 字段，读取后状态不应被清空，`status = failed`。
   - 人工破坏 `progress/player/roster` 的 `players`，读取后 roster 不应被坏档覆盖。
3. 原子写入：
   - 模拟写入失败，确认旧档仍可读取。
4. 重复/缺失 ID：
   - 造重复 `save_id`、缺失节点，检查 `errors/warnings/metrics`。
5. 版本门禁：
   - 喂入 `version != 2` 的存档，返回明确错误码。
6. 过滤加载隔离：
   - 在 slot 中加入非 `progress/player/*` 条目，启动阶段应被过滤且不产生无关 `missing` warning。
