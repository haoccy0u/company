# Expedition System

`src/expedition_system` 负责远征、队伍、战斗输入组装、战斗执行以及结果回写。

当前主线已经建立：
- `squad/`: 配队配置与远征期小队状态
- `expedition/`: 远征事件推进与战斗入口
- `battle/`: 单场战斗输入、执行、结果
- `actor/`: 战斗 Actor 模板、战斗输入条目、运行时 Actor

当前仍在收敛的部分：
- 角色定义与跨模块角色实例的分层
- 敌人模板资源化
- 文档入口统一

## Docs

```text
src/expedition_system/
  README.md
  docs/
    architecture/
      TARGET_ARCHITECTURE.md
      CHARACTER_DATA_FLOW.md
      CHARACTER_ROLE_STRUCTURE.md
    plans/
      actor_runtime_plan.md
      actor_runtime_test_plan.md
      actor_autonomy_test_plan.md
      combat_engine_mvp_plan.md
  actor/
    README.md
  squad/
    README.md
  expedition/
    README.md
  battle/
    README.md
    policy/
      README.md
```

文档约定：
- 根 `README.md`：总览与阅读入口
- `docs/architecture/`：长期结构、模块分层、数据流
- `docs/plans/`：阶段计划与测试方案
- 各模块 `README.md`：模块职责、边界、入口

## Reading Order

如果要先建立整体上下文，建议按这个顺序读：

1. `src/expedition_system/docs/architecture/TARGET_ARCHITECTURE.md`
2. `src/expedition_system/docs/architecture/CHARACTER_ROLE_STRUCTURE.md`
3. `src/expedition_system/docs/architecture/CHARACTER_DATA_FLOW.md`
4. `src/expedition_system/actor/README.md`
5. `src/expedition_system/squad/README.md`
6. `src/expedition_system/expedition/README.md`
7. `src/expedition_system/battle/README.md`

如果当前重点是 `ActorRuntime`，再补读：
- `src/expedition_system/docs/plans/actor_runtime_plan.md`
- `src/expedition_system/docs/plans/actor_runtime_test_plan.md`
- `src/expedition_system/docs/plans/actor_autonomy_test_plan.md`
- `src/attribute_framework/README.md`

## Module Boundaries

### `actor/`

- 定义战斗侧可复用的 Actor 数据入口与运行时对象
- 包含 `ActorTemplate`、`ActorEntry`、`ActorRuntime`
- 不承担跨模块角色持久状态

### `squad/`

- 管理远征模块里的队伍与成员运行时视图
- 负责跨战斗的 HP、装备结果等远征内状态
- 不直接执行战斗数值结算

### `expedition/`

- 管理远征推进、事件触发、战斗入口
- 不做单场战斗规则裁决

### `battle/`

- 负责 `BattleStart` 组装、战斗执行、结果生成、结果回写
- `CombatEngine` 是单场战斗的统一裁决层

## Current Direction

当前明确方向：
- 玩家角色需要跨模块使用，后续应引入独立的持久角色实例层
- 敌人不需要跨模块使用，应与玩家角色分开建模
- 战斗层继续统一消费 `ActorEntry -> ActorRuntime`
- `attribute_framework` 继续作为统一数值查询与计算管线
