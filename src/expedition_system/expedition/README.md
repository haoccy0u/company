# Expedition Module

## 1. 目标

`src/expedition_system/expedition` 负责远征层最小骨架：
- 持有 `SquadRuntime`
- 持有地点定义
- 推进远征进度
- 生成/触发事件（当前重点是 `CombatEventDef`）

本目录不负责：
- 战斗数值结算
- `CombatEngine` 内部逻辑
- 战后回写细节（由 `battle/ResultApplier` 负责）

## 2. 文件职责（当前）

- `ExpeditionLocationDef.gd`
  - 地点定义（最小版）
  - 提供敌人组来源（供 CombatEvent 生成）

- `CombatEventDef.gd`
  - 远征层运行时战斗事件对象

- `NonCombatEventStub.gd`
  - 非战斗事件占位对象（便于后续扩展）

- `EventSelector.gd`
  - 事件选择器（当前优先生成 CombatEvent）

- `ExpeditionSession.gd`
  - 远征会话状态与推进入口
  - 管理当前事件、步数、结束状态

## 3. 当前行为规则（MVP）

- `advance()` 每次最多生成一个事件
- 当前事件未完成前，不允许再次 `advance()`
- 当前优先生成 `CombatEventDef`
- 若地点无可用敌人组且允许非战斗占位，则可回退 `NonCombatEventStub`

## 4. 关键边界

- `ExpeditionSession` 不写战斗结算公式
- `ExpeditionSession` 不直接修改战斗中 Actor
- 远征层与战斗层通过 `BattleStart / BattleResult`（以及调用链）衔接

## 5. 当前测试方式

通过 `scenes/devtest/panels/ExpeditionSessionTestPanel.tscn` 验证：
- `setup()`
- `advance()`
- `complete_current_event()`
- 与 `BattleBuilder / BattleSession` 的对接流程

## 6. 后续扩展方向

- 地点事件权重与事件池
- 非战斗事件真实逻辑
- 多场战斗远征结束条件细化（撤退、资源耗尽等）
- 更正式的 BattleResult 消费流程（目前测试面板已先串通）
