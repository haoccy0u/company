# Expedition Module（Step 2：远征骨架）

## 1. 目标

本目录负责远征层最小骨架：

- 持有 `SquadRuntime`
- 持有地点定义
- 推进远征步骤
- 生成/触发下一个事件（本阶段优先 `CombatEvent`）

本阶段不负责：

- 战斗数值结算
- `BattleSession` / `CombatEngine`
- 战后结果回写


## 2. 文件职责（MVP）

- `ExpeditionLocationDef.gd`
  - 地点定义（最小版）
  - 提供可用敌人组列表（供战斗事件生成）

- `CombatEventDef.gd`
  - 远征层生成的战斗事件数据对象（运行时）

- `NonCombatEventStub.gd`
  - 非战斗事件占位对象（当前仅预留结构）

- `EventSelector.gd`
  - 远征事件选择器
  - 当前默认优先生成 `CombatEvent`

- `ExpeditionSession.gd`
  - 远征会话状态与推进入口
  - 管理当前事件、步数、结束状态


## 3. 当前默认规则（Step 2）

- 每次 `advance()` 最多生成一个事件
- 当前事件未完成前，不允许继续 `advance()`
- 当前优先生成 `CombatEvent`
- 若地点没有可用敌人组：
  - 且允许非战斗占位，则生成 `NonCombatEventStub`
  - 否则返回 `null`


## 4. 手动验证清单（Step 2）

1. 创建一个 `ExpeditionLocationDef`，填入 `location_id` 和至少一个 `combat_enemy_groups`
2. 创建 `SquadRuntime`（可复用现有 `SquadRuntimeFactory`）
3. `ExpeditionSession.setup(location, squad)`
4. 调用 `advance()`
5. 检查返回对象为 `CombatEventDef`
6. 再次调用 `advance()`（未完成当前事件）应被阻止并返回 `null`
7. 调用 `complete_current_event()`
8. 再次 `advance()` 应可生成下一事件


## 5. 下一步（不在本次实现）

- `BattleSession` 与 `BattleStart` 装配
- `CombatEngine` 自动战斗
- `BattleResult -> SquadRuntime` 回写
