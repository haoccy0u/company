# Battle Module

## 1. 目标与当前阶段

`src/expedition_system/battle` 负责单场战斗的输入组装、战斗运行、结果产出与战后回写规则。

当前状态：
- 已从“纯 stub”推进到“自动战斗 MVP（M3/M4 第一轮）”
- 已接入属性框架进行主要数值读取与 HP 增减
- 已支持最小被动效果与状态日志（观者/机器人测试用）

## 2. 子模块划分

### A. 战斗输入/输出数据

- `BattleStart.gd`：单场战斗开局输入快照
- `BattleResult.gd`：单场战斗结果
- `ActorEntry.gd`：位于 `src/expedition_system/actor/ActorEntry.gd`
- `ActorResult.gd`：位于 `src/expedition_system/actor/ActorResult.gd`

### B. 战斗装配与会话

- `BattleBuilder.gd`：`CombatEvent + SquadRuntime -> BattleStart`
- `BattleSession.gd`：调用 `CombatEngine` 并产出 `BattleResult`

### C. 战斗运行内核

- `CombatEngine.gd`：自动战斗 MVP 规则裁决者
- `ActorRuntime.gd`：位于 `src/expedition_system/actor/ActorRuntime.gd`
- `ActorRuntime.tscn`：位于 `src/expedition_system/actor/ActorRuntime.tscn`
- `ActorInventoryComponent.gd`：位于 `src/expedition_system/actor/ActorInventoryComponent.gd`

### D. 战后回写与策略

- `ResultApplier.gd`：`BattleResult -> SquadRuntime`
- `policy/PostBattleHpPolicy.gd`
- `policy/CarryOverHpPolicy.gd`
- `policy/ResetFullHpPolicy.gd`

## 3. Runtime Boundary

- `SquadRuntime`：远征级持久状态
- `ActorRuntime`：单场战斗运行时状态

必须遵守：
- 不跨战斗复用 `ActorRuntime`
- 跨战斗保留通过 `BattleResult -> ResultApplier -> SquadRuntime` 实现

## 4. CombatEngine 当前能力

已实现：
- 固定 tick 自动推进
- 基于 `spd` 的冷却推进与错峰
- 最简单 AI（默认基础攻击）
- 基础攻击结算（读取 `atk / def / dmg_out_mul / dmg_in_mul`）
- 全灭判定
- 结构化事件日志
- 两个测试被动的最小逻辑：
  - `crush_joints`
  - `attack_heal_ally`

## 5. 当前已知不足

- 被动资源入口仍偏 devtest 约定
- 敌人生成仍偏程序化
- 状态跟踪日志仍可继续通用化
- 整链路自动化验证还不够稳

## 6. 相关文档

- `src/expedition_system/actor/README.md`
- `src/expedition_system/docs/plans/combat_engine_mvp_plan.md`
- `src/expedition_system/docs/architecture/TARGET_ARCHITECTURE.md`
- `src/expedition_system/docs/architecture/CHARACTER_DATA_FLOW.md`
- `src/attribute_framework/README.md`
- `src/expedition_system/battle/policy/README.md`

## 7. Actor Turn Plan Boundary

当前约定：
- `ActorRuntime` 负责生成本回合计划：`action_id / primary_target / attack_ctx / follow_up_effects`
- `CombatEngine` 负责统一应用这个计划造成的跨 Actor 影响
- actor 可以决定打谁，但不能直接修改目标状态
- `ActorRuntime` 负责导出状态移除事件与 `ActorResult`
