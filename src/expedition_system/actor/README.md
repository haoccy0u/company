# Actor Module

## 1. 目标

`src/expedition_system/actor` 负责角色相关的 4 层内容：
- 静态模板：`ActorTemplate`
- 单场战斗输入：`ActorEntry`
- 单场战斗结果：`ActorResult`
- 战斗中的角色实例：`ActorRuntime`

当前模块回答的问题是：
- 角色是什么：`ActorTemplate`
- 这场战斗以什么数据参战：`ActorEntry`
- 战后回写什么：`ActorResult`
- 战斗中的角色如何存在：`ActorRuntime`

## 2. 文件职责

- `ActorTemplate.gd`
  - 角色静态模板资源
  - 提供基础属性模板、默认行动、被动、AI、标签
- `ActorEntry.gd`
  - 单场战斗开局输入条目
  - 由 `BattleBuilder` 组装
- `ActorResult.gd`
  - 单个参战单位的战后结果
- `ActorRuntime.gd`
  - 战斗中的角色运行时节点
  - 持有自身状态、属性集、组件引用和对外接口
- `ActorRuntime.tscn`
  - 统一的战斗角色基础场景
- `ActorInventoryComponent.gd`
  - 继承 `InventoryComponent`
  - 负责角色装备容器与装备效果解算

## 3. 职责边界

- `ActorTemplate` 是纯数据模板，不直接决定战斗场景如何实例化
- `ActorRuntime` 只管理自身状态，不直接修改其他 Actor
- `CombatEngine` 仍然是唯一的跨 Actor 裁决者
- `SquadRuntime` 是跨战斗持久层，`ActorRuntime` 是单场战斗瞬态层

## 4. 当前实现约定

- `CombatEngine` 统一实例化 `ActorRuntime.tscn`
- `ActorRuntime.tscn` 当前挂载：
  - `AttributeComponent`
  - `ActorInventoryComponent`
  - `VisualRoot`
  - `StateFxRoot`
  - `UiAnchor`
- 装备链路优先使用 `equipment_container: ItemContainer`
- `equipment_ids` 仅作为过渡期 fallback
- 单次伤害通过运行时 `damage` 属性通道结算，再落到 `hp`
- 单次治疗通过运行时 `heal` 属性通道结算，再落到 `hp`
- `cooldown_total` 通过运行时派生属性从 `spd` 计算
- 运行时 `hp` 通过 `RuntimeHpAttribute` 依赖 `hp_max`，由属性框架统一做 clamp

## 5. 当前重构进度

### 已完成

- `ActorRuntime` 场景化
- `AttributeComponent + ActorInventoryComponent` 接入
- 通用运行时属性补齐：
  - `hp`
  - `damage`
  - `heal`
  - `cooldown_total`
- actor 自治逻辑已下沉：
  - 行动选择
  - 目标选择
  - 回合计划生成
  - 攻击计算
  - 攻击后效果意图
  - 状态快照/状态移除事件
  - 单 Actor 战斗结果导出
- 已建立专用测试入口：
  - `ActorRuntimeTestPanel`
  - `actor_runtime_smoke`

### 仍待继续

- 重做 `observer / robot` 测试资源
- 把更多行为定义进一步模板化
- 清理 `ActorInventoryComponent` 中的 devtest 级装备映射
- 逐步补齐视觉层的正式挂点与表现逻辑

## 6. 属性框架与行为层分工

优先放进 `attribute_framework` 的内容：
- 单角色内部的数值关系
- 属性钳制
- buff / modifier 运算
- 派生属性关系

当前已下沉：
- `hp -> hp_max` clamp
- `damage` 通道
- `heal` 通道
- `cooldown_total <- spd`

仍应保留在 actor 行为层 / combat 层的内容：
- 触发时机
- 目标选择
- 跨 Actor 效果意图生成
- 跨 Actor 影响的统一落地

## 7. 当前不足

- `ActorRuntime.tscn` 仍是最小场景，视觉层还很薄
- `ActorInventoryComponent.gd` 仍包含 devtest 级装备映射
- `ActorRuntime.gd` 虽已瘦身，但还有继续拆分空间
- `observer / robot` 资源还没按当前底座重做

## 8. 相关文档

- 规划：`src/expedition_system/docs/plans/actor_runtime_plan.md`
- 自治测试：`src/expedition_system/docs/plans/actor_autonomy_test_plan.md`
- 本体测试：`src/expedition_system/docs/plans/actor_runtime_test_plan.md`
- 总体架构：`src/expedition_system/docs/architecture/TARGET_ARCHITECTURE.md`
- 数据流：`src/expedition_system/docs/architecture/CHARACTER_DATA_FLOW.md`
- 属性框架：`src/attribute_framework/README.md`
