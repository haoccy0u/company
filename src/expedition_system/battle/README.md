# Battle Module

## 1. 目标与当前阶段

`src/expedition_system/battle` 负责单场战斗的输入组装、战斗运行、结果产出与战后回写规则。

当前状态：
- 已从“纯 stub”推进到“自动战斗 MVP（M3/M4 第一轮）”
- 已接入属性框架进行主要数值读取与 HP 增减
- 已支持最小被动效果与状态日志（观者/机器人测试用）

## 2. 子模块划分（当前脚本按职责）

### A. 战斗输入/输出数据（DTO）
- `BattleStart.gd`：单场战斗开局输入快照
- `BattleResult.gd`：单场战斗结果（含日志、我方结果）
- `ActorEntry.gd`：已迁移到 `src/expedition_system/actor/ActorEntry.gd`
- `ActorResult.gd`：已迁移到 `src/expedition_system/actor/ActorResult.gd`

### B. 战斗装配与会话
- `BattleBuilder.gd`：`CombatEvent + SquadRuntime -> BattleStart`
- `BattleSession.gd`：单场战斗会话包装（调用 `CombatEngine` 并产出 `BattleResult`）

### C. 战斗运行内核
- `CombatEngine.gd`：自动战斗 MVP 规则裁决者（tick、冷却、AI、结算、日志）
- `ActorRuntime.gd`：已迁移到 `src/expedition_system/actor/ActorRuntime.gd`
- `ActorRuntime.tscn`：已迁移到 `src/expedition_system/actor/ActorRuntime.tscn`
- `ActorInventoryComponent.gd`：已迁移到 `src/expedition_system/actor/ActorInventoryComponent.gd`

### D. 战后回写与策略
- `ResultApplier.gd`：`BattleResult -> SquadRuntime` 回写（当前最小版）
- `policy/PostBattleHpPolicy.gd`：HP 策略基类
- `policy/CarryOverHpPolicy.gd`：战后 HP 继承策略
- `policy/ResetFullHpPolicy.gd`：战后 HP 回满策略（测试用）

### E. 战斗资源定义（当前最小版）
- `PassiveTemplate.gd`：被动模板数据（当前用于观者/机器人被动参数）

## 3. Runtime Boundary（关键）

- `SquadRuntime`：远征级持久状态（跨战斗）
- `ActorRuntime`：单场战斗运行时状态（本场结束销毁）

必须遵守：
- 不跨战斗复用 `ActorRuntime`（即使是玩家角色也不复用）
- 跨战斗保留通过 `BattleResult -> ResultApplier -> SquadRuntime` 实现

原因：
- 冷却、临时 buff/debuff、战斗 tags、tick 状态都属于战斗瞬态
- 这些状态泄漏到下一场会导致难排查 bug

## 4. `CombatEngine` 当前能力（MVP）

已实现：
- 固定 tick 自动推进
- 基于 `spd` 的冷却推进与错峰
- 最简单 AI（默认基础攻击）
- 基础攻击结算（读取 `atk / def / dmg_out_mul / dmg_in_mul`）
- 全灭判定（敌方全灭胜利 / 我方全灭失败）
- 结构化事件日志（`combat_start`、`combat_tick`、`action`、`value_change`、`status_applied`、`status_removed`、`passive_trigger`、`death`、`combat_end`）
- 两个测试被动的最小逻辑：
  - `crush_joints`
  - `attack_heal_ally`

## 5. `ActorRuntime` 当前状态（节点化过渡版）

当前已做：
- `ActorRuntime` 从 `RefCounted` 改为 `Node`
- 新增 `ActorRuntime.tscn` 作为统一实例化入口（当前为基础空场景 + 逻辑脚本）
- `ActorRuntime.tscn` 已挂载：
  - `AttributeComponent`（属性访问/后续表现桥接）
  - `ActorInventoryComponent`（继承 `InventoryComponent`，负责装备容器与装备解算）
- 仍由 `CombatEngine` 手动调用 `tick(delta)`（暂不依赖 `_process`）
- 增加 UI 友好信号：
  - `hp_changed`
  - `alive_changed`
  - `cooldown_changed`
- `CombatEngine` 支持可选 `actor_host_root`，会把本场 Actor 挂到 `CombatActors` 容器下（便于 UI 观察/绑定）

当前场景创建策略（已确定）：
- `ActorTemplate` 继续保持“数据模板”职责，不持有 `runtime_scene`
- `CombatEngine` 从 `BattleStart/ActorEntry` 获取数据后，统一实例化 `ActorRuntime.tscn`
- 后续如确有需要，可再增加独立的场景映射层（而不是把场景引用塞回模板）

当前组件驱动约定（已确定）：
- `AttributeComponent` 会挂在 `ActorRuntime` 场景中，但其 `_physics_process` 自动推进已在 `ActorRuntime` 中禁用
- 属性 tick 仍由 `CombatEngine -> ActorRuntime.tick(delta)` 统一驱动（避免重复推进）
- `ActorInventoryComponent` 当前会把 `equipment_ids` 转成占位 `ItemData` 放入 inventory，再从 inventory 读取 `item_id` 解算属性 buff
- 现已支持优先从 `equipment_container`（`ItemContainer` 快照）加载角色配装；`equipment_ids` 仅作为兼容 fallback
- 当前物品效果映射仍是 devtest 级最小表（后续替换为真实 item 数据驱动）

## 6. 与属性框架（`attribute_framework`）的关系

当前已接入：
- `ActorTemplate.base_attr_set` 作为角色基础属性模板
- `ActorRuntime.attr_set` 作为战斗期属性实例
- `ActorRuntime.attribute_component.attribute_set` 与 `attr_set` 同步
- `ActorRuntime.inventory_component` 会根据 `equipment_ids` 重建装备属性 buff（通过 inventory 中的 `item_id`）
- `ActorRuntime.inventory_component` 优先根据 `equipment_container` 重建装备属性 buff（通过 inventory 中的 `item_id`）
- `ActorRuntime` 在运行期注入 `hp` 属性
- `CombatEngine` 读取属性值进行结算
- `ActorRuntime.heal()/take_damage()` 优先走属性框架（`Attribute.add/sub/set_value`）
- `weaken` 通过 `AttributeBuff` 挂到 `dmg_out_mul`

详细说明见：`src/attribute_framework/README.md`

## 7. 测试与联调入口

主要通过 `TestHub` 联调：
- `scenes/devtest/TestHub.tscn`
- `scenes/devtest/panels/SquadConfigTestPanel.tscn`
- `scenes/devtest/panels/ExpeditionSessionTestPanel.tscn`

推荐流程：
1. `Squad Config` 构建并发布 `SquadRuntime`
2. `Expedition Session` 建立会话并 `Advance`
3. `Build BattleStart`
4. `Resolve Combat (Stub)`（当前实际已走自动战斗 MVP）
5. 观察 `BattleResult.log` 与小队实时状态变化

## 8. 当前已知不足（下一阶段重点）

- 被动执行仍有 `passive_id` 分支，尚未完全抽象为通用执行器
- 敌人生成仍偏程序化（未全面资源化）
- 状态跟踪日志尚未完全通用化
- `ActorRuntime` 节点化后是否引入 `AttributeComponent` 仍需进一步设计

## 9. 相关文档

- `src/expedition_system/actor/README.md`
- `src/expedition_system/battle/COMBAT_ENGINE_MVP_PLAN.md`
- `src/expedition_system/TARGET_ARCHITECTURE.md`
- `src/expedition_system/CHARACTER_DATA_FLOW.md`
- `src/attribute_framework/README.md`
- `src/expedition_system/battle/policy/README.md`
