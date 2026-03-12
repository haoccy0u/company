# data 目录规范（文档轮次）

## 1. 本文档用途
- 本文档用于先对齐目录职责与迁移顺序。
- 当前仅做规范沉淀，不代表目录已经迁移完成。

## 2. 边界约定
- `res://data` 只放系统静态资源（system data）。
- 玩家运行态数据不进入 `res://data`，统一进入 `user://saves/save_slot_*.json`。
- 开发调试需要的玩家状态，也通过 save slot 建立和恢复，不再新增 `res://data` 下玩家资源。

## 3. 当前现状（过渡态）
当前仓库目录仍为旧结构：
- `res://data/devtest/expedition_v2/*`
- `res://data/devtest/inventory/*`

说明：
- 这两套目录暂时保留，直到 save 链路完善后再迁移。
- 本文档阶段不移动 `.tres`，不改资源路径常量。

## 4. 目标目录蓝图（未来态）
目标是先表达数据语义，再表达环境维度：
- `res://data/system/devtest/expedition/...`
- `res://data/system/devtest/inventory/...`

建议子目录（未来态）：
- `res://data/system/devtest/expedition/actors/catalogs`
- `res://data/system/devtest/expedition/actors/definitions`
- `res://data/system/devtest/expedition/events/pools`
- `res://data/system/devtest/expedition/items`
- `res://data/system/devtest/expedition/locations`
- `res://data/system/devtest/inventory/items`
- `res://data/system/devtest/inventory/containers`

## 5. 旧路径到新路径映射（规划）
- `data/devtest/expedition_v2/actors` -> `data/system/devtest/expedition/actors/*`
- `data/devtest/expedition_v2/events` -> `data/system/devtest/expedition/events/pools`
- `data/devtest/expedition_v2/items` -> `data/system/devtest/expedition/items`
- `data/devtest/expedition_v2/locations` -> `data/system/devtest/expedition/locations`
- `data/devtest/expedition_v2/players` -> 删除（玩家态改由 `user://saves` 提供）
- `data/devtest/inventory/*.tres` -> `data/system/devtest/inventory/{items|containers}`

## 6. 实施顺序（两阶段）
1. 先完善 save 可用链路：
   - 玩家 roster 可通过 `save_slot` 读取与恢复。
   - 远征起局不再依赖 `res://data/.../players/*.tres`。
2. 再执行 data 目录迁移：
   - 批量迁移资源路径与硬编码常量。
   - 清理旧目录与旧引用。

## 7. 风险与回滚
- 主要风险：
  - 资源路径失效导致 missing resource。
  - 调试入口仍依赖旧路径常量。
  - 存档读取链路未打通时删除玩家资源会导致起局失败。
- 回滚方式：
  - 迁移提交按阶段拆分（save 接入 / 路径迁移）。
  - 任一阶段回归失败时，只回退对应阶段提交，不回退全部。

## 8. 本轮禁止事项
- 不移动现有 `.tres`。
- 不改 `project.godot`、场景资源引用、代码默认路径常量。
- 不删除 `data/devtest/expedition_v2` 与 `data/devtest/inventory`。
