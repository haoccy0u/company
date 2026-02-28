# Character Data Structure And Flow

## 1. 目的

本文说明当前远征系统里“角色相关数据”是如何组织的，以及它们如何从配队流转到战斗，再回写到远征运行态。

适用范围：
- `squad/`
- `actor/`
- `battle/`
- `expedition/` 中与战斗衔接有关的部分

## 2. 设计原则

当前链路遵循这几个原则：

1. `ActorTemplate` 描述角色“是什么”。
2. `MemberConfig` 描述玩家“出发前选了什么”。
3. `MemberRuntime` / `SquadRuntime` 保存远征中的跨战斗状态。
4. `ActorEntry` / `ActorRuntime` 只服务单场战斗。
5. 基础数值权威来源已经切到 `AttributeSet`。

## 3. 数据分层

### 3.1 静态模板层：`ActorTemplate`

文件：
- `src/expedition_system/actor/ActorTemplate.gd`

职责：
- 保存角色模板 ID、显示名、基础属性、默认行动、被动、AI、标签

关键字段：
- `template_id`
- `display_name`
- `base_attr_set`
- `action_ids`
- `passive_ids`
- `ai_id`
- `tags`

说明：
- 当前 `hp_max` 等基础属性都来自 `base_attr_set`
- `get_base_attr_value()` 用于读取模板基础属性

### 3.2 出发前配置层：`MemberConfig` / `SquadConfig`

文件：
- `src/expedition_system/squad/MemberConfig.gd`
- `src/expedition_system/squad/SquadConfig.gd`

职责：
- 保存玩家出发前的配队选择

当前主要配置项：
- 角色模板
- 装备
- 可选的初始 HP 覆盖

当前约定：
- `action_ids`
- `passive_ids`
- `ai_id`

这些默认来自 `ActorTemplate`，不是玩家直接填写。

### 3.3 远征运行态层：`MemberRuntime` / `SquadRuntime`

文件：
- `src/expedition_system/squad/MemberRuntime.gd`
- `src/expedition_system/squad/SquadRuntime.gd`
- `src/expedition_system/squad/SquadRuntimeFactory.gd`

职责：
- 保存跨战斗的小队状态
- 作为远征层和战斗层之间的稳定持久桥梁

`MemberRuntime` 当前保存：
- 身份快照：`member_id`、`actor_template_id`
- 配置快照：装备、行动、被动、AI
- 远征状态：`current_hp`、`max_hp`、`alive`
- 长期状态占位：`injury_flags`、`resources`

### 3.4 战斗输入层：`ActorEntry` / `BattleStart`

文件：
- `src/expedition_system/actor/ActorEntry.gd`
- `src/expedition_system/battle/BattleStart.gd`
- `src/expedition_system/battle/BattleBuilder.gd`

职责：
- 把远征层状态装配成单场战斗开局快照

`ActorEntry` 当前包含：
- 身份：`actor_id`、`camp`、`member_id`、`actor_template_id`
- 数值：`hp`、`max_hp`、`base_attr_set`
- 行为：`ai_id`、`action_ids`、`passive_ids`
- 装备：`equipment_container`、`equipment_ids`
- 其他附加数据：`extra`

说明：
- `BattleStart` 现在同时保留字典字段和强类型条目，用于兼容现有测试入口

### 3.5 战斗运行时层：`ActorRuntime` / `CombatEngine`

文件：
- `src/expedition_system/actor/ActorRuntime.gd`
- `src/expedition_system/actor/ActorRuntime.tscn`
- `src/expedition_system/battle/CombatEngine.gd`

职责：
- `ActorRuntime`：单个战斗单位的瞬态状态、属性接口、行为输出
- `CombatEngine`：统一推进 tick、调度行动、应用跨 Actor 影响、记录日志

当前边界：
- `ActorRuntime` 只管理自身状态
- `CombatEngine` 不应把角色专属规则重新拉回去

### 3.6 战斗结果层：`ActorResult` / `BattleResult`

文件：
- `src/expedition_system/actor/ActorResult.gd`
- `src/expedition_system/battle/BattleResult.gd`
- `src/expedition_system/battle/ResultApplier.gd`

职责：
- 输出单场战斗结果
- 回写到 `SquadRuntime`

`ActorResult` 当前关注：
- `member_id`
- `hp_before`
- `hp_after`
- `max_hp`
- `alive`

## 4. 属性框架在这条链路中的位置

当前约定：
- 模板基础属性放在 `ActorTemplate.base_attr_set`
- `SquadRuntimeFactory` 从 `base_attr_set.hp_max` 初始化成员生命
- `ActorRuntime` 在战斗期复制 `base_attr_set`
- 运行时再补充：
  - `hp`
  - `damage`
  - `heal`
  - `cooldown_total`

当前常用基础属性名：
- `hp_max`
- `atk`
- `def`
- `spd`
- `dmg_out_mul`
- `dmg_in_mul`
- `heal_out_mul`
- `heal_in_mul`

## 5. 主要调用链路

### 5.1 配队阶段

入口：
- `scenes/devtest/panels/SquadConfigTestPanel.gd`

流程：
1. 加载角色模板资源。
2. 选择角色与装备。
3. 生成 `SquadConfig`。
4. 调用 `SquadRuntimeFactory.from_config()` 生成 `SquadRuntime`。

### 5.2 远征阶段

入口：
- `src/expedition_system/expedition/ExpeditionSession.gd`

流程：
1. `ExpeditionSession` 持有 `SquadRuntime`。
2. `advance()` 生成 `CombatEventDef` 或其他事件。
3. 当前事件进入待处理状态。

### 5.3 开战装配

入口：
- `src/expedition_system/battle/BattleBuilder.gd`

流程：
1. 读取 `SquadRuntime.members`
2. 为每个存活成员生成 `ActorEntry`
3. 生成敌方 `ActorEntry`
4. 组装 `BattleStart`

### 5.4 战斗执行

入口：
- `src/expedition_system/battle/BattleSession.gd`
- `src/expedition_system/battle/CombatEngine.gd`

流程：
1. `BattleSession` 通过 `BattleBuilder` 获得 `BattleStart`
2. `CombatEngine.setup()` 把 `ActorEntry` 转为 `ActorRuntime`
3. 推进自动战斗
4. 输出 `BattleResult`

### 5.5 战后回写

入口：
- `src/expedition_system/battle/ResultApplier.gd`

流程：
1. 读取 `BattleResult.player_actor_results`
2. 按 `member_id` 找到对应 `MemberRuntime`
3. 应用 HP 策略
4. 更新 `current_hp` 与 `alive`

## 6. 当前 devtest 资源

当前主要测试资源：
- `data/devtest/expedition/actors/observer.tres`
- `data/devtest/expedition/actors/robot.tres`
- `data/devtest/expedition/passives/crush_joints.tres`
- `data/devtest/expedition/passives/attack_heal_ally.tres`

说明：
- 这些资源目前仍承担了一部分底座验证职责
- 它们不应被长期当成正式资源目录契约

## 7. 当前已实现与未实现的边界

已实现：
- 从模板到配队、远征、战斗输入、自动战斗、战后回写的基本数据链路
- `AttributeSet` 已成为角色基础数值权威来源
- `ActorRuntime` 已承担部分角色自治逻辑

仍未完全收敛：
- 被动资源入口仍偏 devtest 目录约定
- 装备效果仍存在 devtest 级映射
- 敌人模板尚未完全资源化
- 远征整链路缺少更稳定的无 UI smoke

## 8. 建议阅读顺序

1. `src/expedition_system/docs/architecture/TARGET_ARCHITECTURE.md`
2. `src/expedition_system/README.md`
3. `src/expedition_system/actor/README.md`
4. `src/expedition_system/battle/README.md`
