# Battle Module（Step 3 骨架占位）

## 1. 目标（当前小步）

本目录先提供最小 `BattleSession` 骨架，用于把远征层的 `CombatEvent` 接成一条可测试链路：

- `CombatEventDef` -> `BattleSession`（stub）
- 产出 `BattleResult`（stub）

本阶段不做：

- `CombatEngine`
- Actor 实例化
- 自动战斗数值结算
- 战后回写 `SquadRuntime`


## 2. 当前用途

- 给 `scenes/devtest/panels/ExpeditionSessionTestPanel` 提供“战斗占位解析”
- 验证远征事件消费流程与边界


## 3. 后续演进方向

后续会逐步补充：

- `BattleStart`
- `BattleBuilder`
- `ActorRuntime`
- `CombatEngine`
- `BattleResult` 真实字段（成员结果、日志、资源变化等）
