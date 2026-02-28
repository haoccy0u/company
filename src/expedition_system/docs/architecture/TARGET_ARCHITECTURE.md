# Expedition System Target Architecture

## 1. 目的

本文件记录远征系统与战斗系统的长期架构方向。

它是设计约束与未来重构参考，不表示所有内容都已经实现。

## 2. 当前已确认方向

### 已确认

- `ActorRuntime` 继续走场景化路线，由统一的 `ActorRuntime.tscn` 实例化。
- `ActorRuntime` 同时承载角色运行时状态和表现挂点。
- `CombatEngine` 继续作为单场战斗的唯一裁决者。
- `ActorTemplate` 继续保持纯数据模板，不回塞 `runtime_scene`。

### 暂缓决定

- `CombatEngine` 未来是否要加 `Node` / 场景包装层。
- `ExpeditionSession` 是否需要进入场景树。
- `ActorRuntime` 内是继续直接持有 `AttributeSet`，还是进一步完全经 `AttributeComponent` 转发。

## 3. 推荐分层

建议按 3 层理解当前系统：

### A. 数据状态层

关注点：
- 持久状态
- 可序列化
- 跨系统传递的稳定数据

典型类型：
- `Resource`
- `RefCounted`

当前对象：
- `SquadRuntime`
- `ExpeditionSession`
- `BattleStart`
- `BattleResult`
- `ActorEntry`
- `ActorResult`

### B. 运行时调度层

关注点：
- 时间推进
- 系统调度
- 跨对象协作

典型类型：
- `RefCounted`
- `Node` 管理器

当前对象：
- `CombatEngine`

未来可能新增：
- `ExpeditionManager`
- `CombatEngineNode`

### C. 运行时实例 / 表现层

关注点：
- 单个战斗单位的瞬态状态
- 信号
- 可视化挂点

典型类型：
- 场景化 `Node`

当前对象：
- `ActorRuntime.tscn`
- `ActorRuntime.gd`

## 4. 为什么不要求全部都变成 Node

一个对象场景化，不代表整条链路都必须场景化。

当前推荐分工：
- `ActorRuntime`：场景化，便于 UI、特效、动画、信号绑定。
- `CombatEngine`：保持规则层核心，统一驱动战斗时序。
- `ExpeditionSession`：保持数据会话对象，避免和场景生命周期耦合。

这样做的好处：
- 不把持久逻辑强绑到场景树。
- 后续做后台远征或多远征并行时更轻。
- 非可视对象不会承担不必要的 Node 生命周期成本。

## 5. 多远征并行的推荐方向

如果未来要支持多个远征同时存在，建议：

- `ExpeditionSession` 继续保持数据对象。
- 新增 `ExpeditionManager` 作为场景内管理器。

未来 `ExpeditionManager` 可以负责：
- 保存多个活动中的 `ExpeditionSession`
- 推进远征时间
- 触发远征事件
- 协调 UI 与当前选中的远征
- 决定哪场远征需要进入可视战斗场景

## 6. 战斗运行时的两种形态

### 方案 A：近期推荐

- `CombatEngine` 继续保持 `RefCounted`
- `CombatEngine` 统一实例化 `ActorRuntime.tscn`
- `CombatEngine` 手动推进 `actor.tick(delta)`

优点：
- 改动小
- 当前实现已经贴近这个方案
- 战斗时序更集中，不容易重复驱动

### 方案 B：以后再评估

- 增加 `CombatEngineNode` 包装层
- 战斗 UI、Actor 宿主节点、调试入口由 Node 包起来
- 规则核心仍可继续放在 `CombatEngine`

优点：
- 和战斗场景、UI、编辑器调试更自然

风险：
- 生命周期与场景切换复杂度会上升

## 7. ActorRuntime 的目标形态

`ActorRuntime` 的长期目标是“统一战斗角色场景”。

建议包含：
- 根节点 + `ActorRuntime.gd`
- 属性访问桥接
- `VisualRoot`
- `StateFxRoot`
- `UiAnchor`
- 后续需要时再接动画节点

必须保持的规则：
- `ActorRuntime` 只管理自己
- `CombatEngine` 负责跨 Actor 裁决与最终落地

## 8. 当前实现与目标的对齐情况

已经对齐的部分：
- `ActorRuntime` 已改为 `Node`
- `ActorRuntime.tscn` 已作为统一实例化入口
- `CombatEngine` 已通过 `ActorEntry` 初始化 `ActorRuntime`
- `CombatEngine` 已支持把 Actor 挂到宿主节点下

仍未完成的部分：
- `ActorRuntime.tscn` 的表现层仍较薄
- UI 友好的信号/事件接口还可继续补
- 装备效果链路仍存在 devtest 级占位实现
- 是否需要 `CombatEngineNode` 仍未到必须落地的阶段

## 9. 当前阶段的优先顺序

在重新讨论更上层架构前，当前优先事项仍然是收敛 `ActorRuntime`：

1. 保持 `ActorRuntime` 作为统一角色本体入口。
2. 收敛装备效果入口与被动资源入口，减少 devtest 级硬编码。
3. 补远征整链路 smoke，降低后续推进回归成本。
4. 在此基础上再推进 `ActionTemplate`、敌人模板资源化等工作。
