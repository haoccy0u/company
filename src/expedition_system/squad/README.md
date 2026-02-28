# Squad Module

## 1. Purpose

`src/expedition_system/squad` 负责：
- 出发前的小队配置
- 远征期的小队运行时状态
- 跨战斗保留的成员 HP / 装备结果

本目录不负责：
- 单场战斗数值结算
- 战斗 Actor 组装细节
- 远征事件推进

## 2. Files

- `MemberConfig.gd`
  - 单个成员的出发前配置
  - 当前只保存：
    - `member_id`
    - `actor_template_id`
    - `equipment_container`
    - `equipment_ids`
    - `init_hp`

- `SquadConfig.gd`
  - 小队配置资源

- `MemberRuntime.gd`
  - 远征模块里的成员运行时状态
  - 当前只保存跨战斗需要持续的数据：
    - `member_id`
    - `actor_template_id`
    - `equipment_container`
    - `equipment_ids`
    - `current_hp`
    - `max_hp`
    - `alive`
    - 长期状态占位字段

- `SquadRuntime.gd`
  - 小队运行时资源

- `SquadRuntimeFactory.gd`
  - `SquadConfig -> SquadRuntime` 的入口
  - 当前不再手工复制模板里的动作 / 被动 / AI / 基础属性
  - 玩家角色装配统一交给 `PlayerActorAssembler`

## 3. Current Rule

当前链路的关键约束：

1. `MemberConfig` 只保存玩家选择结果，不直接内嵌模板资源
2. `MemberRuntime` 只保存远征期需要持续的状态
3. 模板里的动作 / 被动 / AI / 基础属性不缓存到 `MemberRuntime`
4. 进入战斗前，再根据 `actor_template_id` 统一加载模板并组装 `ActorEntry`

## 4. Why This Is Simpler

这次收敛后的目的，是删除玩家侧重复缓存。

旧问题：
- `SquadRuntimeFactory` 会把 `ActorTemplate` 拆成 `MemberRuntime`
- `BattleBuilder` 又把 `MemberRuntime` 再拆成 `ActorEntry`
- 同一批字段被复制两次

现在：
- `SquadRuntime` 只保留远征状态
- 战斗输入由统一装配入口生成
- 模板数据只有一份权威来源：`ActorTemplate`

## 5. Initialization Rule

`SquadRuntimeFactory` 当前只做这些事：

- 通过 `actor_template_id` 解析模板
- 从模板读取 `hp_max`
- 根据 `init_hp` 决定初始 HP
- 复制装备相关配置
- 设置 `alive = current_hp > 0`

## 6. Relation With Battle

关系现在更明确：

- `SquadRuntime` 保存远征状态
- `BattleBuilder` 不再手工拼玩家角色字段
- `PlayerActorAssembler` 负责：
  - `MemberConfig -> MemberRuntime`
  - `MemberRuntime -> ActorEntry`
- `ResultApplier` 只负责把战斗结果回写到 `SquadRuntime`

## 7. Manual Check

1. 在 `TestHub -> Squad Config` 选择角色和装备
2. 点击 `Build Config`
3. 点击 `Build Runtime`
4. 确认输出中：
   - `member_id / actor_template_id` 正确
   - `HP / max_hp / alive` 初始化正确
   - 运行时里不再直接显示模板派生字段
