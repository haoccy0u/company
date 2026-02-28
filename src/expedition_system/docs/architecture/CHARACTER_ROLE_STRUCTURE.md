# Character Role Structure

## 1. Purpose

这份文档专门回答两个问题：

1. 玩家角色要跨多个模块使用时，数据应该怎么分层
2. 敌人只服务于战斗时，应该怎么避免和玩家角色共用一套过重的结构

当前前提：
- 玩家角色需要在远征之外继续复用
- 敌人不需要跨模块持久存在
- 战斗层仍然希望统一消费 `ActorEntry -> ActorRuntime`

## 2. Core Decision

角色系统拆成两条上游链路、一个统一的战斗落点：

1. 玩家角色链路
2. 敌人链路
3. 战斗统一投影链路

也就是说：
- 玩家角色走“静态定义 + 持久实例 + 模块状态 + 模块运行时”
- 敌人走“战斗专用模板 + 战斗输入”
- 两者最后都汇总成 `ActorEntry`，再进入 `ActorRuntime`

## 3. Recommended Layers

### 3.1 Player Static Definition

文件方向：
- `src/expedition_system/actor/ActorTemplate.gd`

职责：
- 定义“这个角色天生是什么”
- 保存基础属性模板、默认动作、默认被动、默认 AI、标签、表现入口

这层是静态资源，不保存存档进度。

建议长期字段：
- `template_id`
- `display_name`
- `base_attr_set`
- 默认动作
- 默认被动
- 默认 AI
- tags

### 3.2 Player Persistent Instance

建议新增：
- `src/expedition_system/character/CharacterRecord.gd`

职责：
- 定义“这个角色在当前存档里变成什么样了”
- 只保存跨模块、可存档、长期存在的数据

建议长期字段：
- `character_id`
- `actor_template_id`
- `level`
- `exp`
- 当前装备结果
- 长期 HP / 伤势
- 已学技能 / 天赋
- 永久解锁项

这层不放单场战斗冷却，不放战斗内 buff。

### 3.3 Module State

建议新增：
- `src/expedition_system/character/modules/ExpeditionCharacterState.gd`

职责：
- 保存某个模块专属、但需要跨该模块多个步骤持续存在的数据

远征模块适合放：
- 疲劳
- 远征伤势
- 探索临时标记
- 远征专属资源

当前只做 `ExpeditionCharacterState` 即可，不急着先做通用模块字典框架。

### 3.4 Expedition Runtime View

现有文件：
- `src/expedition_system/squad/MemberRuntime.gd`
- `src/expedition_system/squad/SquadRuntime.gd`
- `src/expedition_system/squad/SquadRuntimeFactory.gd`

职责：
- 表示“这个角色在当前远征里的运行时视图”
- 对战斗层输出稳定的远征成员状态

长期方向：
- `SquadRuntimeFactory` 主要输入应从 `CharacterRecord` 来
- `MemberRuntime` 保留为远征模块运行时对象，而不是跨模块角色实体

### 3.5 Battle Projection

现有文件：
- `src/expedition_system/actor/ActorEntry.gd`
- `src/expedition_system/actor/ActorRuntime.gd`
- `src/expedition_system/battle/BattleBuilder.gd`
- `src/expedition_system/battle/CombatEngine.gd`

职责：
- 把玩家角色或敌人都投影成统一的战斗输入
- 进入统一的战斗运行时与战斗规则链路

边界：
- `ActorEntry` 是单场战斗输入快照
- `ActorRuntime` 是单场战斗运行时对象
- `CombatEngine` 是单场战斗的统一裁决层

## 4. Enemy Structure

敌人不需要跨模块使用，所以不需要：
- `CharacterRecord`
- 模块状态
- 远征外持久实例

敌人只需要两层：

### 4.1 Enemy Static Definition

建议新增：
- `src/expedition_system/enemy/EnemyTemplate.gd`

职责：
- 定义“这个敌人在战斗里是什么”
- 保存战斗专用基础属性、动作、被动、AI、标签

### 4.2 Enemy Battle Projection

建议新增：
- `src/expedition_system/enemy/EnemyEntryBuilder.gd`

职责：
- 根据 `EnemyTemplate` 或敌群配置生成 `ActorEntry`

这样 `BattleBuilder` 的职责会更干净：
- 玩家侧：从 `MemberRuntime` 生成 `ActorEntry`
- 敌人侧：从 `EnemyTemplate` 生成 `ActorEntry`

## 5. Unified Battle Landing Point

玩家角色和敌人上游不同，但战斗落点保持统一：

```text
Player:
  ActorTemplate
    -> CharacterRecord
    -> ExpeditionCharacterState
    -> MemberRuntime
    -> ActorEntry
    -> ActorRuntime

Enemy:
  EnemyTemplate
    -> ActorEntry
    -> ActorRuntime
```

这个统一落点的意义：
- `CombatEngine` 不需要知道“上游是不是持久角色”
- 战斗规则只消费统一输入
- 玩家和敌人只在战斗前的组装方式不同

## 6. Recommended Directory Structure

建议长期目录结构：

```text
src/expedition_system/
  actor/
    ActorTemplate.gd
    ActorEntry.gd
    ActorRuntime.gd
    README.md

  character/
    CharacterRecord.gd
    README.md
    modules/
      ExpeditionCharacterState.gd

  enemy/
    EnemyTemplate.gd
    EnemyEntryBuilder.gd
    README.md

  squad/
    MemberRuntime.gd
    SquadRuntime.gd
    SquadRuntimeFactory.gd
    README.md

  battle/
    BattleBuilder.gd
    BattleStart.gd
    BattleSession.gd
    BattleResult.gd
    CombatEngine.gd
    README.md
```

## 7. Mapping From Current Files

当前代码可先按下面方式理解：

- `ActorTemplate.gd`
  - 继续保留为玩家角色静态定义
- `MemberRuntime.gd`
  - 当前同时承担了“远征成员视图”和部分持久状态
  - 这是后续最需要拆分的点
- `BattleBuilder.gd`
  - 当前同时负责玩家侧和敌人侧 `ActorEntry` 组装
  - 敌人侧仍是硬编码 spec，后续应逐步迁出
- `ActorEntry.gd`
  - 继续保留为统一战斗输入快照
- `ActorRuntime.gd`
  - 继续保留为统一战斗运行时

## 8. Minimal Migration Order

建议按最小成本推进：

1. 先补 `CharacterRecord.gd`
2. 再补 `ExpeditionCharacterState.gd`
3. 让 `SquadRuntimeFactory` 支持从 `CharacterRecord` 构建 `MemberRuntime`
4. 保留当前 `ActorTemplate -> MemberRuntime` 入口做兼容
5. 把敌人从 `BattleBuilder.gd` 的硬编码 spec 逐步迁到 `EnemyTemplate`
6. 最后再评估 `ActorTemplate` 是否从 ID 数组升级成直接资源引用

## 9. Current Rule

当前阶段的约束可以明确为：

- `ActorTemplate` 不是跨模块角色实例
- `MemberRuntime` 不是长期的角色总状态容器
- 敌人不走玩家角色的持久状态链路
- `ActorEntry` / `ActorRuntime` 继续作为玩家与敌人的统一战斗投影
