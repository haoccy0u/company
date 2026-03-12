# Data Reorg Plan（预实施清单）

## 目标
- 先完成 save 链路，再重组 `data` 目录。
- 本文件只定义执行顺序和验收点，不包含本轮代码改动。

## 阶段 1：先让 Save 可用
- [ ] 玩家 roster 接入 `SaveManager`（可保存/读取）。
- [ ] 远征起局改为从 `save_slot` 获取玩家数据。
- [ ] 起局流程不再依赖 `res://data/.../players/*.tres`。
- [ ] 回归：`save_slot` 缺失时有明确失败提示。

验收：
- [ ] `save_slot` JSON 包含玩家角色数据。
- [ ] 修改玩家状态后可通过 `load_slot` 正确恢复。

## 阶段 2：迁移 data 目录
- [ ] 将 expedition 静态资源迁移到 `res://data/system/devtest/expedition/...`。
- [ ] 将 inventory 静态资源迁移到 `res://data/system/devtest/inventory/...`。
- [ ] 替换代码/场景中的旧路径常量与资源引用。
- [ ] 删除 `res://data/devtest/expedition_v2/players`。
- [ ] 清理旧目录残留引用。

验收：
- [ ] 全局检索无 `res://data/devtest/expedition_v2` 引用（允许迁移文档中提及）。
- [ ] 全局检索无 `res://data/devtest/inventory` 运行时引用。
- [ ] 远征/库存调试路径可正常启动，无 missing resource。

## 本轮明确不做
- 不移动 `.tres`。
- 不改默认路径常量。
- 不删旧目录。
