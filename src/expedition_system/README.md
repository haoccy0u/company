# Expedition System

## 1. 目录定位

`src/expedition_system` 负责远征系统与战斗内核的实现。

当前主目标：
- 支持小队配置与远征运行态
- 支持远征事件推进
- 支持单场战斗会话与自动战斗 MVP
- 支持战斗结果回写到小队运行态
- 提供 devtest 工作台用于联调

## 2. 当前状态

已实现：
- `squad/`：`SquadConfig -> SquadRuntime`
- `expedition/`：远征会话骨架、事件选择、CombatEvent 触发
- `battle/`：战斗输入组装、自动战斗 MVP、战后回写
- `actor/`：角色模板、战斗输入条目、场景化运行时、行为测试基建
- `battle/policy/`：HP 策略

未完全收敛：
- `observer / robot` 测试资源仍偏 devtest
- 装备效果与被动资源入口仍有过渡实现
- 敌人模板还未完全资源化
- 缺少更稳定的整链路自动回归

## 3. 文档结构

```text
src/expedition_system/
  README.md
  docs/
    architecture/
      TARGET_ARCHITECTURE.md
      CHARACTER_DATA_FLOW.md
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
- 根 `README.md`：总览和阅读入口
- `docs/architecture/`：跨模块的长期说明
- `docs/plans/`：阶段计划与测试方案
- 各模块 `README.md`：只写该模块职责、边界、入口

## 4. 推荐阅读顺序

如果要快速建立全局上下文，建议按这个顺序读：

1. `src/expedition_system/docs/architecture/TARGET_ARCHITECTURE.md`
2. `src/expedition_system/docs/architecture/CHARACTER_DATA_FLOW.md`
3. `src/expedition_system/actor/README.md`
4. `src/expedition_system/squad/README.md`
5. `src/expedition_system/expedition/README.md`
6. `src/expedition_system/battle/README.md`
7. `src/expedition_system/docs/plans/actor_runtime_plan.md`

如果当前重点是 `ActorRuntime`，再补读：
- `src/expedition_system/docs/plans/actor_runtime_test_plan.md`
- `src/expedition_system/docs/plans/actor_autonomy_test_plan.md`
- `src/attribute_framework/README.md`

## 5. 模块边界

### `actor/`

- 管理角色模板、战斗输入条目、战斗运行时实例与角色战斗组件
- 是 `squad/` 和 `battle/` 之间的角色层桥梁

### `squad/`

- 管理出发前配置与远征期小队状态
- 不做战斗结算

### `expedition/`

- 管理远征推进、事件触发、战斗入口
- 不做战斗数值结算

### `battle/`

- 管理单场战斗输入、运行、结果、回写策略
- `CombatEngine` 是单场规则裁决者

## 6. 当前阶段结论

`ActorRuntime` 已经进入“模板与资源收敛”阶段。

可以继续推进，但当前更值得优先处理的是：
- 收敛文档与阅读入口
- 清理 devtest 级资源入口
- 补整链路验证
