# Actor Runtime Plan

## 1. 目标

把 `ActorRuntime` 从“能工作的战斗节点”整理成“可长期维护的角色本体”。

最终目标：
- `ActorRuntime.tscn` 是统一的战斗角色场景
- `ActorRuntime.gd` 暴露稳定、易理解的角色接口
- `AttributeComponent` 与 `ActorInventoryComponent` 通过 `ActorRuntime` 协作
- `CombatEngine` 只做全局调度、跨 Actor 裁决、日志与胜负判定

## 2. 当前进度确认

### 已完成

#### 场景与组件层
- `ActorRuntime` 已改为场景实例化
- `CombatEngine` 统一实例化 `ActorRuntime.tscn`
- `ActorRuntime.tscn` 已挂：
  - `AttributeComponent`
  - `ActorInventoryComponent`
  - `VisualRoot`
  - `StateFxRoot`
  - `UiAnchor`

#### 运行时属性层
- 运行时属性已补齐当前主链路需要的 4 类：
  - `hp`
  - `damage`
  - `heal`
  - `cooldown_total`
- 已落地的自定义属性类：
  - `RuntimeHpAttribute`
  - `RuntimeDamageAttribute`
  - `RuntimeHealAttribute`
  - `RuntimeCooldownTotalAttribute`

#### Actor 自治层
- 已下沉到 `ActorRuntime`：
  - 默认行动选择
  - 攻击目标选择
  - 回合计划生成
  - 攻击计算
  - 攻击后效果意图生成
  - 状态快照导出
  - 状态移除事件导出
  - 单 Actor 战斗结果导出
- `CombatEngine` 现在主要负责：
  - 推进时间
  - 统一调度
  - 跨 Actor 效果落地
  - 日志记录
  - 胜负判定

#### 测试层
- 已有 `ActorRuntime` 专用测试面板：
  - `scenes/devtest/panels/ActorRuntimeTestPanel.tscn`
- 已有无 UI smoke runner：
  - `scenes/devtest/actor_runtime_smoke.tscn`
- 当前 smoke 通过项：
  - `hp_clamp`
  - `equipment_apply`
  - `cooldown_total_derived`
  - `observer_weaken_intent`
  - `robot_heal_intent`

### 部分完成

- `ActorRuntime.gd` 已明显瘦身，但仍有继续拆分空间
- `PassiveExecutor` 已模板化一部分被动执行，但主动行为模板还没完整落地
- `observer / robot` 已切到当前通用属性和被动资源链路，但仍只是 devtest 测试资源

### 未完成

- 主动行为模板（`ActionTemplate`）未完整建立
- 敌人模板仍未资源化
- `ActorRuntime` 视觉层仍是空壳结构，尚未接正式表现

## 3. 当前明确边界

### 应继续保留在属性框架的内容
- 单角色内部数值关系
- 派生属性
- 属性 clamp
- buff / modifier 运算
- 单次 `damage / heal` 通道的数值后处理

### 应继续保留在 actor 行为层 / combat 层的内容
- 触发时机
- 目标选择
- 跨 Actor 效果意图生成
- 跨 Actor 影响的真正落地

## 4. 下一阶段建议顺序

1. 重做 `observer / robot` 的模板和被动资源
- 目标：让测试角色尽量表达“模板数据”，少依赖行为层里的角色专用假设

2. 回归测试
- `ActorRuntimeTestPanel`
- `actor_runtime_smoke.tscn`
- `ExpeditionSessionTestPanel`

3. 再考虑下一轮通用化
- `ActionTemplate`
- 更完整的敌人模板资源化
- 进一步清理 `CombatEngine` 中残留的角色细节

## 5. 当前判断

`ActorRuntime` 重构已经过了“骨架验证”阶段，进入“模板与资源收敛”阶段。

更直接地说：
- 角色本体结构：基本立住了
- 通用运行时属性：当前主链路已补齐
- 下一步最该做的不是继续堆逻辑，而是重做测试角色资源并验证这套底座是否足够干净

## 6. 继续工作前建议先读

继续推进 `ActorRuntime` 之前，建议先回看这些文档：

- `src/attribute_framework/README.md`
  - 看属性框架职责边界、运行时属性约定、当前已下沉的通用属性
- `src/expedition_system/actor/README.md`
  - 看 actor 模块边界、当前重构进度与当前不足
- `src/expedition_system/docs/plans/actor_runtime_test_plan.md`
  - 看 `ActorRuntime` 的手动面板与 smoke runner 测试范围
- `scenes/devtest/README.md`
  - 看当前 devtest 场景入口，尤其是 `ActorRuntimeTestPanel` 和 `TestHub`
- `src/expedition_system/README.md`
  - 看整个远征系统当前阶段结论，确认 `ActorRuntime` 在全局中的位置
- `src/expedition_system/battle/README.md`
  - 看 `CombatEngine` 与 `ActorRuntime` 的职责边界，避免继续混层
- `src/expedition_system/docs/architecture/CHARACTER_DATA_FLOW.md`
  - 看角色数据从模板到战斗实例的流转过程

如果下一步要重做 `observer / robot`，至少要先读前 3 项。
