# Character Data Structure And Flow（当前实现说明）

## 1. 目的

这份文档单独解释当前远征系统里“角色相关数据”是怎么组织的，以及它们从配队到战斗（stub）是如何被调用和传递的。

适用范围：
- `squad/`（角色模板、配队配置、远征运行态）
- `battle/`（战斗开局输入、战斗运行时 Actor、战斗结果）

## 2. 当前设计原则（重要）

1. `ActorTemplate` 是角色静态模板（角色“是什么”）
2. `MemberConfig` 是玩家配队选择（玩家“选了什么”）
3. `MemberRuntime` / `SquadRuntime` 是远征中跨战斗保留状态（远征路上“现在还剩什么”）
4. `ActorEntry` / `ActorRuntime` 是单场战斗内对象（战斗中“这场要怎么打”）
5. 角色基础数值权威来源已切到 `AttributeSet`

## 3. 角色数据结构（分层）

### 3.1 静态模板层：`ActorTemplate`

文件：`src/expedition_system/actor/ActorTemplate.gd`

作用：
- 定义一个角色模板的静态信息（名称、基础属性、默认行动、被动、AI）
- 被 `MemberConfig` 引用
- 被 `SquadRuntimeFactory` 用于生成 `MemberRuntime`

当前关键字段：
- `template_id: StringName`
- `display_name: String`
- `base_attr_set: AttributeSet`
  - 当前权威基础属性来源
  - 至少应包含 `hp_max`
- `action_ids: Array[StringName]`
- `passive_ids: Array[StringName]`
- `ai_id: StringName`
- `tags: Dictionary`

当前提供的辅助方法：
- `get_base_attr_value(attr_name, fallback)`
  - 从 `base_attr_set` 按属性名读取基础值

### 3.2 被动定义层（数据层）：`PassiveTemplate`

文件：`src/expedition_system/battle/PassiveTemplate.gd`

作用：
- 用于描述被动的配置数据（不是执行逻辑）
- 给后续 M3/M4 实现 CombatEngine 被动触发时提供参数来源

当前关键字段：
- `passive_id`
- `display_name`
- `description`
- `trigger_id`
- `effect_tags`
- `params`

说明：
- 当前被动逻辑尚未在 `CombatEngine` 中真正执行
- 现在主要用于“先把规则数据定义清楚”

### 3.3 配队配置层：`MemberConfig` / `SquadConfig`

文件：
- `src/expedition_system/squad/MemberConfig.gd`
- `src/expedition_system/squad/SquadConfig.gd`

作用：
- 存玩家在出发前的选择（角色模板、装备、可选初始 HP 覆盖）

`MemberConfig` 当前关键字段：
- `member_id`
- `actor_template_id`
- `actor_template`
- `equipment_ids`
- `init_hp`（调试/测试覆盖，`< 0` 表示使用模板 `hp_max`）

注意：
- 玩家当前不直接配置 `action_ids/passive_ids/ai_id`
- 这些默认内容来自 `ActorTemplate`

### 3.4 远征运行态层：`MemberRuntime` / `SquadRuntime`

文件：
- `src/expedition_system/squad/MemberRuntime.gd`
- `src/expedition_system/squad/SquadRuntime.gd`

作用：
- 远征期间跨战斗保存状态
- 由 `SquadRuntimeFactory` 从 `SquadConfig` 初始化
- 战后由 `ResultApplier` 回写更新（当前基于 stub 战斗结果）

`MemberRuntime` 当前关键字段：
- 身份与配置快照：`member_id`, `actor_template_id`, `equipment_ids`
- 战斗输入默认集合：`action_ids`, `passive_ids`, `ai_id`
- 远征状态：`alive`, `current_hp`, `max_hp`
- 占位字段：`injury_flags`, `resources`

### 3.5 战斗输入层：`ActorEntry` / `BattleStart`

文件：
- `src/expedition_system/actor/ActorEntry.gd`
- `src/expedition_system/battle/BattleStart.gd`
- `src/expedition_system/battle/BattleBuilder.gd`

作用：
- `BattleStart` 是远征层传给战斗层的“开战快照”
- `ActorEntry` 是 `BattleStart` 内的强类型参战条目

`ActorEntry` 当前关键字段：
- `actor_id`, `camp`, `member_id`, `actor_template_id`
- `hp`, `max_hp`
- `ai_id`, `action_ids`, `passive_ids`, `equipment_ids`
- `extra`（敌方占位信息等）

说明：
- 当前 `BattleStart` 同时保留了旧字典字段（`players/enemies`）和强类型字段（`player_entries/enemy_entries`），用于兼容测试面板

### 3.6 战斗运行时层：`ActorRuntime` / `CombatEngine`

文件：
- `src/expedition_system/actor/ActorRuntime.gd`
- `src/expedition_system/battle/CombatEngine.gd`

作用：
- `ActorRuntime`：单场战斗中的运行时对象（每个参战单位一个）
- `CombatEngine`：战斗内规则引擎（当前 M2 为骨架 + stub）

`ActorRuntime` 当前关键字段：
- 身份：`actor_id`, `camp`, `member_id`, `actor_template_id`
- 状态：`current_hp`, `max_hp`, `alive`
- 占位战斗字段：`cooldown_total`, `cooldown_remaining`
- 行为配置：`ai_id`, `action_ids`, `passive_ids`, `equipment_ids`
- `tags`（当前用于记录 `hp_start` 等临时信息）

说明：
- 当前 `CombatEngine` 已可执行一条 stub 流程并输出事件日志
- 还未实现真正 tick / AI / 行动结算 / modifier

### 3.7 战斗结果层：`ActorResult` / `BattleResult`

文件：
- `src/expedition_system/actor/ActorResult.gd`
- `src/expedition_system/battle/BattleResult.gd`
- `src/expedition_system/battle/ResultApplier.gd`

作用：
- `ActorResult`：单角色战斗结果条目（强类型）
- `BattleResult`：单场战斗整体结果
- `ResultApplier`：把 `BattleResult` 回写到 `SquadRuntime`

当前关键字段（`ActorResult`）：
- `member_id`
- `hp_before`
- `hp_after`
- `max_hp`
- `alive`

说明：
- 当前 `BattleResult` 也保留 `player_results` 字典数组用于兼容旧路径
- `ResultApplier` 已优先兼容 `player_actor_results`

## 4. 属性框架在角色模板里的位置（当前版本）

当前做法（已切换）：
- 角色模板基础数值存放在 `ActorTemplate.base_attr_set`
- `SquadRuntimeFactory` 初始化角色最大生命时，从 `base_attr_set.hp_max` 读取

当前约定的基础属性名（建议继续沿用）：
- `hp_max`
- `atk`
- `def`
- `spd`
- `dmg_out_mul`
- `dmg_in_mul`
- `heal_out_mul`
- `heal_in_mul`

当前状态：
- `hp_max` 已实际参与 `SquadRuntime` 初始化
- 其他属性（`atk/def/spd/...`）已进入数据结构，但尚未在 `CombatEngine` 结算中使用

## 5. 调用流程（从配队到战斗）

下面是当前“角色数据”的主链路。

### 5.1 配队阶段（TestHub / SquadConfigTestPanel）

入口：
- `scenes/devtest/panels/SquadConfigTestPanel.gd`

流程：
1. 面板加载角色模板资源（当前优先从 `data/devtest/expedition/actors/*.tres`）
2. 玩家选择角色模板 + 装备
3. 面板生成 `SquadConfig`
4. 调用 `SquadRuntimeFactory.from_config(config)` 生成 `SquadRuntime`
5. 发布到 `TestHub` 共享上下文（`expedition.squad_runtime`）

### 5.2 `SquadConfig -> SquadRuntime` 初始化过程

入口：
- `src/expedition_system/squad/SquadRuntimeFactory.gd`

每个成员的关键步骤：
1. 读取 `MemberConfig.actor_template`
2. 复制 `action_ids/passive_ids/ai_id`（来自 `ActorTemplate`）
3. 从 `ActorTemplate.base_attr_set` 读取 `hp_max`
4. 用 `MemberConfig.init_hp` 计算 `current_hp`
5. 计算 `alive`
6. 写入 `MemberRuntime`

### 5.3 远征阶段（ExpeditionSession）

入口：
- `src/expedition_system/expedition/ExpeditionSession.gd`

与角色数据相关的点：
- `ExpeditionSession` 持有 `SquadRuntime`
- `advance()` 生成 `CombatEventDef` 后，后续战斗会基于当前 `SquadRuntime` 生成 `BattleStart`

### 5.4 开战装配（BattleBuilder）

入口：
- `src/expedition_system/battle/BattleBuilder.gd`

流程：
1. 读取 `SquadRuntime.members`
2. 为每个存活成员创建 `ActorEntry`（`camp=player`）
3. 复制当前战斗需要的 HP/行动/被动/AI/装备信息
4. 生成敌方 `ActorEntry`（当前仍是 stub 占位）
5. 生成 `BattleStart`

### 5.5 战斗运行（CombatEngine，当前 M2 stub）

入口：
- `src/expedition_system/battle/CombatEngine.gd`
- `src/expedition_system/battle/BattleSession.gd`

当前流程：
1. `BattleSession` 通过 `BattleBuilder` 生成 `BattleStart`
2. `CombatEngine.setup(start)` 把 `ActorEntry` 转成 `ActorRuntime`
3. `run_stub_until_end()` 执行最小 stub 逻辑（对首个存活玩家造成固定伤害）
4. 产出 `player_actor_results` + `event_log`
5. `BattleSession` 组装成 `BattleResult`

### 5.6 战后回写（ResultApplier）

入口：
- `src/expedition_system/battle/ResultApplier.gd`

流程：
1. 读取 `BattleResult.player_actor_results`（若为空则回退 `player_results`）
2. 按 `member_id` 找到 `SquadRuntime` 中对应成员
3. 按 HP 策略（`carry_over` / `reset_full`）计算战后 HP
4. 更新 `current_hp` / `alive`

## 6. 当前测试角色与数据资源（devtest）

角色模板资源：
- `data/devtest/expedition/actors/observer.tres`（观者）
- `data/devtest/expedition/actors/robot.tres`（机器人）

属性模板资源：
- `data/devtest/expedition/actors/attrs/observer_attr_set.tres`
- `data/devtest/expedition/actors/attrs/robot_attr_set.tres`

被动资源（数据定义）：
- `data/devtest/expedition/passives/crush_joints.tres`
- `data/devtest/expedition/passives/attack_heal_ally.tres`

说明：
- 当前 `ActorTemplate.passive_ids` 与 `PassiveTemplate` 通过 ID/路径约定关联（未建立正式注册表）
- 后续可增加 `PassiveRegistry` 或数据表管理映射关系

## 7. 当前已实现 / 未实现边界（避免误解）

已实现：
- 角色模板 -> 配队 -> 远征运行态 -> 战斗输入 -> 战斗 stub -> 战后回写 的完整数据链路
- `AttributeSet` 已作为角色基础数值模板权威来源（至少 `hp_max` 生效）
- 被动配置数据已可表达（资源化）

未实现（后续 M3/M4）：
- `CombatEngine` 真实 tick/cooldown/AI 行为
- `atk/def/spd` 实际参与伤害/治疗计算
- 被动逻辑触发（例如“虚弱 2 秒”“攻击时治疗友方”）
- 通过属性框架给目标施加状态 buff 并结算持续时间

## 8. 后续建议（与本文档相关）

1. 在 `CombatEngine` 中增加“属性读取入口”函数（统一读取 `atk/def/spd/...`）
2. 增加 `PassiveRegistry`（`passive_id -> PassiveTemplate`）
3. 把 `ActorRuntime` 挂接战斗期 `AttributeSet`（由 `ActorEntry` 初始化）
4. 实现第一个完整被动案例：`crush_joints`
