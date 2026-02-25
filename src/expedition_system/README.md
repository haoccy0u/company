# Expedition System / CombatEngine 工程文档（MVP 规划）

## 1. 文档目的

本文件用于把“远征系统需求说明”整理成可编码的工程落地方案，重点是：

- 明确模块边界（远征层 / 战斗会话层 / CombatEngine）
- 明确数据形态（配置态 / 持久态 / 战斗瞬态）
- 给出最小可实现路径（MVP）
- 给出后续扩展时不容易推翻的接口边界

当前默认规则（已确认）：

- 战后 HP 暂时继承到下一场战斗
- 该规则未来会替换为其他计算策略，因此本阶段要保留策略接口/边界，避免写死在 `ExpeditionSession`


## 2. 本阶段目标与非目标

### 2.1 本阶段目标（MVP）

1. 可以配置并保存 `SquadConfig`
2. 远征能创建 `ExpeditionSession` 并推进到事件
3. 地点能触发 `CombatEvent`
4. `CombatEvent` 能创建 `BattleSession`
5. `BattleSession` 能运行 `CombatEngine` 完成自动战斗
6. 产出 `BattleResult` 并回写 `SquadRuntime`
7. 有结构化战斗事件日志（用于调试/未来 UI）

### 2.2 本阶段非目标

- 手操技能、点击干预、打断条
- 复杂站位/地形/射程/掩体
- 完整非战斗事件逻辑（只留占位）
- 完整掉落经济闭环


## 3. 总体职责边界（必须遵守）

### 3.1 `ExpeditionSession`（远征层）

负责：

- 持有地点与推进状态
- 持有 `SquadRuntime`（跨战斗）
- 选择/触发事件
- 在 `CombatEvent` 时创建 `BattleSession`
- 消费 `BattleResult` 并回写持久态
- 判断远征继续/结束

不负责：

- 不写战斗数值结算公式
- 不直接改战斗内 Actor 运行状态

### 3.2 `BattleSession`（单场战斗会话）

负责：

- 接收 `BattleStart`
- 创建 `CombatEngine`
- 把 payload 转换为 `ActorRuntime`
- 驱动战斗到结束
- 产出 `BattleResult`

不负责：

- 不管理远征地图/事件池
- 不持久化跨战斗状态

### 3.3 `CombatEngine`（战斗内核）

负责：

- 管理本场 `ActorRuntime` 列表
- 推进时间/冷却
- 在 Actor ready 时触发 AI 选择行动
- 统一裁决行动效果（伤害/治疗/状态）
- 输出结构化事件流
- 判定战斗结束

硬规则：

- Actor 不得直接修改其他 Actor
- 跨 Actor 影响必须通过 `CombatEngine` 统一裁决并落地


## 4. 核心数据模型（先定义边界，再写代码）

下面先用“职责 + 关键字段”定义，MVP 可先用 `Resource` 或 `RefCounted`，后续再细化。

### 4.1 小队配置态（出发前）

#### `SquadConfig`

作用：

- 玩家在基地配置的出战小队
- 是远征开始时生成持久态的唯一输入

建议字段（MVP）：

- `squad_id: StringName`
- `members: Array[MemberConfig]`
- `formation_slots: Array[int]`（可选，先占位）
- `strategy_tag: StringName`（可选，AI 预设占位）

#### `MemberConfig`

建议字段（MVP）：

- `member_id: StringName`（角色实例 id）
- `actor_template_id: StringName`（战斗原型引用）
- `equipment_ids: Array[StringName]`
- `action_ids: Array[StringName]`
- `passive_ids: Array[StringName]`
- `ai_id: StringName`

说明：

- 这里保存“选择了什么”
- 不保存战斗瞬态（如剩余冷却）

### 4.2 小队持久态（远征期间）

#### `SquadRuntime`

作用：

- 一次远征会话期间跨多场战斗保存状态

建议字段（MVP）：

- `source_squad_id: StringName`
- `members: Array[MemberRuntime]`
- `shared_res: Dictionary`（先占位）
- `long_states: Dictionary`（先占位）

#### `MemberRuntime`

建议字段（MVP）：

- `member_id: StringName`
- `alive: bool = true`
- `current_hp: float`
- `max_hp: float`（初始化时记录，便于回写和校验）
- `injury_flags: Dictionary`（先占位）
- `resources: Dictionary`（弹药/耐久等占位）

必须明确：

- 跨战斗保留：`alive`、`current_hp`、长期状态/资源
- 不跨战斗保留：`cooldown_remaining`、临时 buff/debuff、当前行动进度

### 4.3 远征事件层

#### `ExpeditionEvent`（基类/通用结构）

建议字段（MVP）：

- `event_id: StringName`
- `event_type: StringName`（如 `combat`、`non_combat`）
- `location_id: StringName`
- `payload: Dictionary`

#### `CombatEvent`

建议字段（MVP）：

- `enemy_group_id: StringName` 或 `enemy_spawn_table_id: StringName`
- `difficulty_seed: int`（可选）

### 4.4 战斗开局输入与结果

#### `BattleStart`

作用：

- 单场战斗开局快照，只包含本战需要的数据

建议字段（MVP）：

- `battle_id: StringName`
- `location_id: StringName`
- `players: Array[ActorEntry]`
- `enemies: Array[ActorEntry]`
- `rules: Dictionary`

`rules` 最少包含：

- `hp_policy_id`
- `cooldown_stagger: bool`

#### `ActorEntry`

建议字段（MVP）：

- `actor_id: StringName`
- `camp: StringName`（`player` / `enemy`）
- `member_id: StringName`（敌人可为空）
- `actor_template_id: StringName`
- `ai_id: StringName`
- `starting_hp: float`
- `base_attribute_set`（或模板引用）
- `initial_modifiers: Array`（装备/被动转换结果）
- `action_defs: Array`

#### `BattleResult`

建议字段（MVP）：

- `victory: bool`
- `end_reason: StringName`（`all_enemies_dead` / `all_players_dead`）
- `players: Array[ActorResult]`
- `log: Array[Dictionary]`
- `res_changes: Dictionary`（占位）

#### `ActorResult`

建议字段（MVP）：

- `member_id: StringName`
- `alive: bool`
- `ending_hp: float`
- `long_states: Dictionary`（占位）


## 5. 建议目录结构（`src/expedition_system/`）

以下是建议结构，优先保证职责清晰，不追求一次性建全：

```text
src/expedition_system/
  README.md
  squad/
    SquadConfig.gd
    MemberConfig.gd
    SquadRuntime.gd
    MemberRuntime.gd
    SquadRuntimeFactory.gd
  expedition/
    ExpeditionSession.gd
    ExpeditionLocationDef.gd
    ExpeditionEventDef.gd
    CombatEventDef.gd
    NonCombatEventStub.gd
    EventSelector.gd
  battle/
    BattleSession.gd
    CombatEngine.gd
    ActorRuntime.gd
    BattleStart.gd
    BattleResult.gd
    ActorEntry.gd
    ActorResult.gd
    CombatLog.gd
    BattleBuilder.gd
    ResultApplier.gd
  battle/ai/
    ActorAI.gd
    BasicAutoAI.gd
  battle/action/
    ActionDef.gd
    ActionResolver.gd
  battle/policy/
    PostBattleHpPolicy.gd
    CarryOverHpPolicy.gd
```

说明：

- `SquadRuntimeFactory`：专门负责 `SquadConfig -> SquadRuntime` 初始化，避免逻辑散在 `ExpeditionSession`
- `BattleBuilder`：专门负责 `SquadRuntime + CombatEvent -> BattleStart`
- `ResultApplier`：专门负责 `BattleResult -> SquadRuntime` 回写
- `battle/policy/`：为之后替换 HP 规则预留位置，避免后期大改


## 6. 与现有属性系统（`src/attribute_framework`）的对接方案

项目已有：

- `AttributeSet`
- `Attribute`
- `AttributeModifier`
- `AttributeBuff`

MVP 推荐做法：

1. `ActorRuntime` 持有一个运行时 `AttributeSet`
2. 战斗开局时从模板复制 `AttributeSet`（或按模板构建）
3. 装备/被动/状态都尽量转成 `AttributeModifier` 或 `AttributeBuff`
4. `CombatEngine` 只做：
   - 读取最终属性值（例如攻击、速度、HP）
   - 调用属性方法应用数值变化（`add/sub/set` 等）
   - 挂/卸 buff
5. buff 持续时间推进采用“属性系统自身 tick”，由 `CombatEngine` 驱动调用 `attribute_set.run_process(delta)`

这样做的好处（给新手的解释）：

- 战斗内核不需要知道每个状态怎么计算，只需要“挂上去”和“读结果”
- 以后你改属性公式，大部分情况下不用重写战斗流程


## 7. CombatEngine（MVP）运行模型

### 7.1 时间推进方式（建议）

MVP 先用固定步长模拟，易于调试：

- `SIM_TICK_SEC = 0.1`（建议值，可调整）

每 tick 做的事：

1. 更新全局战斗时间
2. 对每个存活 Actor：
   - 推进自身冷却计时
   - 推进属性/buff 计时（调用 `AttributeSet.run_process(delta)`）
3. 收集 “已 ready 的 Actor”
4. 按规则排序（先简单按 `ready_time` / 数组顺序）
5. 逐个让 AI 选行动
6. 由 `CombatEngine` 统一结算
7. 记录结构化事件
8. 检查结束条件

### 7.2 ActorRuntime 最小职责

负责：

- 保存本 Actor 的运行时状态（camp、alive、cooldown、AttributeSet、actions、AI）
- 提供“声明意图”的接口（例如返回想执行的 action + target）

不负责：

- 不直接改目标 Actor
- 不自行写战斗日志（交给 `CombatEngine`）

### 7.3 AI（MVP 简化）

`BasicAutoAI` 建议规则：

1. 从可用行动中选第一个可释放行动
2. 若无可用行动则使用普通攻击
3. 目标选择：
   - 攻击：敌方存活列表中第一个
   - 治疗：己方存活且 HP 最低（后续再做）

先保证稳定可跑，再优化“聪明程度”。


## 8. 行动结算与事件流（MVP）

### 8.1 结算原则

- AI 只负责“选什么”
- `CombatEngine` 负责“怎么算”
- `ActorRuntime` 不得直接改目标 Actor 属性

### 8.2 事件流结构（建议先用 Dictionary）

参考库存系统当前风格，MVP 可先用 `Dictionary`，后续再升级为强类型对象。

通用字段建议：

- `type: StringName`（`action` / `value` / `status` / `death`）
- `time: float`
- `src_id: StringName`
- `dst_id: StringName`
- `data: Dictionary`

示例：

```gdscript
{
  "type": &"action",
  "time": 1.2,
  "src_id": &"p_01",
  "dst_id": &"e_01",
  "data": {
    "action_id": &"basic_attack"
  }
}
```

最少覆盖事件类型：

- 行动事件（执行了什么）
- 数值事件（伤害/治疗）
- 状态事件（施加/移除）
- 死亡事件


## 9. 战后 HP 回写策略（当前默认 + 可替换设计）

### 9.1 当前默认规则（已确认）

- 战后 HP 继承到下一场战斗
- 不自动恢复

### 9.2 为什么要做成策略边界

你已经明确后续会替换策略。如果现在把规则写死在 `ExpeditionSession`，以后会出现：

- 多处散落判断
- 回写规则难以测试
- 切换规则时容易漏改

### 9.3 推荐接口（MVP 即可占位）

建议新增策略接口概念（可先用简单类/方法）：

- `PostBattleHpPolicy.apply(member_runtime, actor_result) -> float`

本阶段只实现：

- `CarryOverHpPolicy`（直接使用 `ending_hp`）

以后可替换为：

- `ResetHpPolicy`（战后满血）
- `RecoverPercentHpPolicy`（按比例恢复）
- `ClampByInjuryPolicy`（受伤上限）

回写位置建议：

- `ResultApplier` 内部调用 `PostBattleHpPolicy`
- `ExpeditionSession` 只负责“调用回写器”，不负责公式


## 10. 代码落地顺序（建议按小步推进）

下面是适合当前项目的 4 步实现顺序（每步都能单独验证）。

### Step 1：数据模型与工厂（不进入战斗）

目标：

- 建立 `SquadConfig / SquadRuntime`
- 实现 `SquadRuntimeFactory`

完成标准：

- 能从固定 `SquadConfig` 生成 `SquadRuntime`
- 明确持久字段和瞬态字段边界

优先文件：

- `src/expedition_system/squad/SquadConfig.gd`
- `src/expedition_system/squad/SquadRuntime.gd`
- `src/expedition_system/squad/SquadRuntimeFactory.gd`

### Step 2：远征骨架与 CombatEvent 触发

目标：

- 建立 `ExpeditionSession`
- 地点事件选择器最小实现（先只出 CombatEvent）

完成标准：

- 调用一次推进后能返回/触发一个 `CombatEvent`

优先文件：

- `src/expedition_system/expedition/ExpeditionSession.gd`
- `src/expedition_system/expedition/EventSelector.gd`
- `src/expedition_system/expedition/CombatEventDef.gd`

### Step 3：BattleSession + CombatEngine 最小自动战斗

目标：

- 输入 `BattleStart`
- 实例化我方/敌方 Actor
- 自动战斗直到一方全灭

完成标准：

- 产出 `BattleResult`
- 有基础事件日志

优先文件：

- `src/expedition_system/battle/BattleSession.gd`
- `src/expedition_system/battle/CombatEngine.gd`
- `src/expedition_system/battle/ActorRuntime.gd`
- `src/expedition_system/battle/ai/BasicAutoAI.gd`

### Step 4：结果回写与远征继续/结束

目标：

- `BattleResult -> SquadRuntime`
- 支持当前 HP 继承策略

完成标准：

- 战斗结束后小队状态变化可用于下一次战斗
- 我方全灭时远征结束

优先文件：

- `src/expedition_system/battle/ResultApplier.gd`
- `src/expedition_system/battle/policy/CarryOverHpPolicy.gd`
- `src/expedition_system/expedition/ExpeditionSession.gd`


## 11. 测试与验证建议（每步都能验）

### 11.1 验证优先级

- 优先验证当前改动直接相关的链路
- 不一次性追求完整 UI
- 先用日志/测试场景证明逻辑成立

### 11.2 建议的手动验证用例（MVP）

1. `SquadConfig -> SquadRuntime` 初始化是否正确（HP 初值、alive 初值）
2. 远征推进是否能产出 `CombatEvent`
3. 战斗是否能创建我方/敌方 Actor
4. 自动战斗是否会结束（无死循环）
5. `BattleResult` 是否正确标记胜负
6. 战后 HP 是否回写并被下一场战斗读取（当前默认继承）
7. 我方全灭是否触发远征结束
8. 战斗日志事件是否覆盖 action/value/death（status 可后补）

### 11.3 建议的最小调试输出

- 每次行动打印：时间、施法者、行动、目标
- 每次数值变更打印：目标、变化量、剩余 HP
- 战斗结束打印：胜负与原因


## 12. 风险与实现注意点（结合当前项目）

### 12.1 中文注释乱码风险

已知终端可能有中文显示乱码。建议：

- 文档与新代码尽量保持 UTF-8
- 注释短句为主
- 关键字段名用英文，避免日志排查困难

### 12.2 节点路径/组名耦合风险

当前项目已知存在对节点路径和组名的耦合。`expedition_system` 建议尽量做成“纯逻辑模块”，减少对场景树依赖：

- `ExpeditionSession` / `BattleSession` / `CombatEngine` 优先 `RefCounted` 或纯脚本逻辑
- UI 层只订阅事件日志，不直接持有并修改内核状态

### 12.3 一次远征多场战斗的常见错误

常见错误是把战斗瞬态写回持久态，例如：

- 剩余冷却
- 临时 debuff
- 临时护盾

这些都不该进 `SquadRuntime`，否则后续会很难维护。


## 13. 当前假设（上下文不足时的明确声明）

以下假设用于本阶段设计，后续可调整：

- 地点与敌人数据先使用固定表/简单随机
- 战斗先使用自动 AI，不做玩家输入
- 战斗结束条件先仅支持“一方全灭”
- 掉落、奖励、交易仅保留字段接口，不做完整逻辑
- HP 回写策略当前为继承，但通过策略接口封装，后续可替换


## 14. 下一步建议（从这里开始写代码）

推荐你先实现 Step 1（数据模型与工厂），因为这是后续所有流程的输入基础，且最容易验证、回归风险最低。

建议先做的最小文件集合：

- `src/expedition_system/squad/SquadConfig.gd`
- `src/expedition_system/squad/MemberConfig.gd`
- `src/expedition_system/squad/SquadRuntime.gd`
- `src/expedition_system/squad/MemberRuntime.gd`
- `src/expedition_system/squad/SquadRuntimeFactory.gd`

这样完成后，再接 `ExpeditionSession` 和 `CombatEvent`，整体推进会更稳。
