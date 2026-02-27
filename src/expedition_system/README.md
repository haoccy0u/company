# Expedition System / CombatEngine

## 1. 目标与定位

`src/expedition_system` 是远征系统（Expedition）与战斗内核（CombatEngine）的实现目录。

当前目标：
- 支持小队配置与远征运行态
- 支持远征事件推进（至少能触发 CombatEvent）
- 支持单场战斗会话（BattleSession）与自动战斗 MVP（CombatEngine）
- 支持战斗结果回写到远征小队状态（通过 `ResultApplier`）
- 提供 `devtest` 测试工作台进行模块联调

## 2. 当前实现状态（概览）

已实现（可测试）：
- `squad/`：小队配置态与远征运行态（`SquadConfig -> SquadRuntime`）
- `expedition/`：远征会话骨架、事件选择、CombatEvent 触发
- `battle/`：战斗输入组装、战斗会话、自动战斗 MVP、战后回写（最小版）
- `battle/policy/`：战后 HP 策略（`carry_over` / `reset_full`）
- `devtest`：通用测试工作台 + 小队配置面板 + 远征面板

未完成（后续阶段）：
- 更完整的动作系统（技能选择、目标规则扩展）
- 通用被动执行器（当前仍有部分 `passive_id` 分支）
- 敌人模板资源化（当前敌方生成仍有程序化占位）
- 更完整的 BattleResult 字段（长期状态、资源、掉落等）

## 3. 目录结构（当前实际）

```text
src/expedition_system/
  README.md
  CHARACTER_DATA_FLOW.md
  actor/
    README.md
    ActorTemplate.gd
    ActorEntry.gd
    ActorResult.gd
    ActorRuntime.gd
    ActorRuntime.tscn
    ActorInventoryComponent.gd
  squad/
    README.md
    MemberConfig.gd
    MemberRuntime.gd
    SquadConfig.gd
    SquadRuntime.gd
    SquadRuntimeFactory.gd
  expedition/
    README.md
    ExpeditionSession.gd
    ExpeditionLocationDef.gd
    EventSelector.gd
    CombatEventDef.gd
    NonCombatEventStub.gd
  battle/
    README.md
    COMBAT_ENGINE_MVP_PLAN.md
    BattleSession.gd
    CombatEngine.gd
    BattleBuilder.gd
    BattleStart.gd
    BattleResult.gd
    ResultApplier.gd
    PassiveTemplate.gd
    policy/
      README.md
      PostBattleHpPolicy.gd
      CarryOverHpPolicy.gd
      ResetFullHpPolicy.gd
```

## 4. 模块边界（必须遵守）

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
- 当前统一由 `CombatEngine` 实例化 `ActorRuntime.tscn`（`ActorTemplate` 保持纯数据模板）

## 5. 核心数据流（当前实现）

1. `SquadConfigTestPanel` 构建 `SquadConfig`
2. `SquadRuntimeFactory.from_config()` 生成 `SquadRuntime`
3. `ExpeditionSession.setup(location, squad_runtime)` 建立远征
4. `ExpeditionSession.advance()` 触发 `CombatEventDef`
5. `BattleBuilder.from_combat_event()` 组装 `BattleStart`
6. `BattleSession` 调用 `CombatEngine` 跑自动战斗
7. `BattleResult` 产出后由 `ResultApplier` 回写 `SquadRuntime`

说明（当前过渡期）：
- 装备数据推荐通过 `ItemContainer`（`equipment_container`）在 `squad -> battle` 链路传递
- `equipment_ids` 仍保留为兼容字段，后续可移除

更多细节见：`src/expedition_system/CHARACTER_DATA_FLOW.md`

## 6. 相关阅读

- `src/expedition_system/actor/README.md`
- `src/expedition_system/squad/README.md`
- `src/expedition_system/expedition/README.md`
- `src/expedition_system/battle/README.md`
- `src/expedition_system/battle/COMBAT_ENGINE_MVP_PLAN.md`
- `src/expedition_system/TARGET_ARCHITECTURE.md`
- `src/attribute_framework/README.md`
