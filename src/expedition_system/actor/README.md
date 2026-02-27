# Actor Module

## 1. 目标

`src/expedition_system/actor` 负责角色相关的静态模板、战斗输入条目、战斗运行时实例，以及角色自身持有的战斗组件。

本目录回答的是同一类问题：
- 角色是什么（`ActorTemplate`）
- 这场战斗要以什么数据参战（`ActorEntry`）
- 战后该回写什么结果（`ActorResult`）
- 战斗中这个角色实例如何存在（`ActorRuntime`）

## 2. 文件职责

- `ActorTemplate.gd`
  - 角色静态模板资源
  - 提供基础属性模板、默认行动、被动、AI、标签

- `ActorEntry.gd`
  - 单场战斗开局输入条目
  - 由 `BattleBuilder` 从 `SquadRuntime` 或敌人生成规则装配

- `ActorResult.gd`
  - 单个参战单位的战后结果
  - 由 `CombatEngine / BattleSession` 产出，再交给 `BattleResult`

- `ActorRuntime.gd`
  - 单场战斗中的角色运行时节点脚本
  - 持有自身状态、属性集、组件引用和基础信号

- `ActorRuntime.tscn`
  - 统一战斗角色基础场景
  - 当前由 `CombatEngine` 统一实例化

- `ActorInventoryComponent.gd`
  - 继承 `InventoryComponent`
  - 负责角色装备容器与装备效果解算

## 3. 职责边界

- `ActorTemplate` 是数据模板，不直接决定战斗场景怎么实例化
- `ActorRuntime` 只管理自身状态与自身组件，不直接修改其它 Actor
- `CombatEngine` 仍然是唯一战斗裁决者
- `SquadRuntime` 是跨战斗持久层，`ActorRuntime` 是单场战斗瞬态层

## 4. 当前实现约定

- `CombatEngine` 从 `BattleStart / ActorEntry` 读取数据后，统一实例化 `ActorRuntime.tscn`
- `ActorRuntime.tscn` 当前已挂：
  - `AttributeComponent`
  - `ActorInventoryComponent`
- 装备链路优先使用 `equipment_container: ItemContainer`
- `equipment_ids` 仅作为过渡期 fallback

## 5. 后续演进方向

- 补充 `ActorRuntime.tscn` 的视觉节点结构（如 `VisualRoot` / `UiAnchor` / `StateFxRoot`）
- 继续把更多角色内部逻辑下沉到 `ActorRuntime`
- 保持 `CombatEngine` 只做统一调度、时序推进和跨 Actor 裁决
