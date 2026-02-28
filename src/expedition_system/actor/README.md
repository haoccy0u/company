# Actor Module

## 1. 目标

`src/expedition_system/actor` 负责角色相关的 4 层对象：

- `ActorTemplate`
  - 静态模板，定义角色基础属性、动作、被动、AI 和标签
- `ActorEntry`
  - 单场战斗的输入数据，由上层战斗构建流程组装
- `ActorResult`
  - 单场战斗结束后的结果数据
- `ActorRuntime`
  - 战斗中的角色运行时实例

这个模块当前回答的问题是：

- 角色是什么：`ActorTemplate`
- 这场战斗以什么数据参战：`ActorEntry`
- 战后回写什么：`ActorResult`
- 角色在战斗中如何存在和行动：`ActorRuntime`

## 2. 文件职责

- `ActorTemplate.gd`
  - 角色静态模板资源
- `ActorEntry.gd`
  - 单场战斗开局输入条目
- `ActorResult.gd`
  - 单个参战单位的战后结果
- `ActorRuntime.gd`
  - 角色运行时主体
  - 持有自身状态、属性集、组件引用和对外接口
- `ActorRuntime.tscn`
  - 统一的角色运行时场景
- `ActorInventoryComponent.gd`
  - 角色装备容器和装备效果接入层
- `behavior/`
  - 被动解析、执行和行为辅助逻辑
- `test/`
  - `ActorRuntime` 的 devtest 支撑脚本

## 3. 当前场景结构

`ActorRuntime.tscn` 当前是最小可运行骨架，挂了这些节点：

- `AttributeComponent`
- `ActorInventoryComponent`
- `VisualRoot`
- `StateFxRoot`
- `UiAnchor`

其中：

- `AttributeComponent` 负责把 `AttributeSet` 接到场景树上
- `ActorInventoryComponent` 负责装备容器与属性联动
- `VisualRoot / StateFxRoot / UiAnchor` 目前主要是正式表现层的预留挂点

## 4. 职责边界

### 应保留在 `ActorRuntime` 的内容

- 从 `ActorEntry` 初始化自身状态
- 持有本 actor 的运行时属性集
- 推进本 actor 的本地 tick
- 判断是否可行动、是否冷却结束
- 选择动作
- 选择目标
- 生成回合计划
- 生成攻击 payload
- 提供目标侧攻击结算入口
- 导出状态快照和战斗结果

### 应保留在 `attribute_framework` 的内容

- 单角色内部数值关系
- 派生属性
- clamp
- buff / modifier 运算
- 作用在 `hp` 上的一次性 operation 计算

### 应保留在 `CombatEngine` 的内容

- 全局时间推进
- 多 actor 调度顺序
- 跨 actor 效果真正落地
- 事件日志
- 胜负判定

## 5. 当前实现进度

### 已完成

- `CombatEngine` 已统一实例化 `ActorRuntime.tscn`
- `ActorRuntime` 已收敛为场景实例，不再依赖散的构造方式
- 当前主链路需要的运行时属性已补齐：
  - `hp`
  - `cooldown_total`
- `RuntimeHpAttribute` 已负责：
  - `hp -> hp_max` clamp
  - 对 `hp` 的单次 damage / heal operation 结算
- `RuntimeCooldownTotalAttribute` 已负责：
  - `cooldown_total <- spd` 的派生关系
- `ActorRuntime` 当前已具备：
  - 默认动作选择
  - 默认目标选择
  - 回合计划生成
  - 攻击 payload 生成
  - 目标侧攻击结算入口
  - follow-up effect 意图生成
  - 状态快照导出
  - 状态移除事件导出
  - 单 actor 战斗结果导出
- 当前保留了手动测试入口：
  - `scenes/devtest/panels/ActorRuntimeTestPanel.tscn`

### 部分完成

- `ActorRuntime.gd` 已明显瘦身，但还没完全通用化
- `PassiveExecutor` 已模板化一部分被动执行逻辑
- `observer / robot` 已接入当前 runtime 链路，但仍然只是 devtest 资源

### 未完成

- 通用状态系统还没完全收口，状态仍主要依赖 buff 命名约定
- 行动模板 `ActionTemplate` 还没完整建立
- 更完整的目标选择策略还没建立
- 敌人模板资源化还没完成
- 视觉层仍是空壳结构，尚未接正式表现

## 6. 当前已知不足

- `ActorRuntime.is_usable()`
  - 当前保留为兼容别名
  - 实际语义已开始拆分到 `can_act()` 和 `is_targetable()`
- `ActorRuntime.has_status()`
  - 当前已改成通用查询
  - 但状态记录仍依赖 `status_id -> buff_name` 对齐
- `ActorRuntime.select_action_id()`
  - 目前是“没有动作就回退 `basic_attack`，否则取第一个”
- `ActorRuntime.select_attack_target()`
  - 目前是“返回第一个可用目标”
- `ActorInventoryComponent`
  - 仍保留 devtest 过渡型 fallback
- 视觉节点已在场景中预留，但还没有正式表现逻辑

## 7. 当前结论

`ActorRuntime` 现在已经过了“能不能作为统一角色场景存在”的阶段，进入“怎么把策略层、状态层和资源层继续收口”的阶段。

更直接地说：

- 骨架已经立住
- 主链路已经能跑
- 现在最需要避免的是把新规则继续硬塞回 `ActorRuntime.gd`

## 8. 相关文档

- `src/expedition_system/docs/plans/actor_runtime_plan.md`
- `src/expedition_system/docs/plans/actor_runtime_test_plan.md`
- `src/expedition_system/docs/plans/actor_autonomy_test_plan.md`
- `src/expedition_system/docs/architecture/CHARACTER_DATA_FLOW.md`
- `src/expedition_system/docs/architecture/TARGET_ARCHITECTURE.md`
- `src/attribute_framework/README.md`
