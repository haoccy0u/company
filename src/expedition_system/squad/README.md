# Squad Module

## 1. 目标

`src/expedition_system/squad` 负责“小队配置（出发前）”与“远征期小队运行态（跨战斗）”。

输入：
- `SquadConfig`

输出：
- `SquadRuntime`

本目录不负责：
- 战斗结算
- 远征事件推进
- UI 交互实现（测试 UI 在 `devtest`）

## 2. 文件职责（当前）

- `ActorTemplate.gd`
  - 角色模板资源（基础属性、行动、被动、AI、标签）
  - 基础数值权威来源是 `base_attr_set: AttributeSet`

- `MemberConfig.gd`
  - 玩家配置的单成员项（当前阶段：角色 + 装备 + 可选 init_hp 覆盖）

- `SquadConfig.gd`
  - 玩家配置的小队（成员列表、小队标识等）

- `MemberRuntime.gd`
  - 远征期单成员运行态（跨战斗保存）
  - 包括当前 HP、存活、模板派生的行动/被动/AI 等

- `SquadRuntime.gd`
  - 远征期小队运行态（成员集合 + 小队级长期状态/资源占位）

- `SquadRuntimeFactory.gd`
  - `SquadConfig -> SquadRuntime` 初始化入口
  - 集中管理初始化规则，避免逻辑散落

## 3. 当前配置约束（已确定）

当前阶段玩家只配置：
- 角色（`actor_template_id` / `actor_template`）
- 装备（`equipment_ids`）

以下内容从 `ActorTemplate` 加载（不是玩家手动配置）：
- `action_ids`
- `passive_ids`
- `ai_id`
- 基础属性（通过 `base_attr_set`）

## 4. 初始化规则（MVP）

`SquadRuntimeFactory` 当前规则：
- `max_hp`：优先从 `ActorTemplate.base_attr_set.hp_max` 读取
- `current_hp`：
  - `MemberConfig.init_hp >= 0` 时使用并 clamp 到 `[0, max_hp]`
  - 否则使用 `max_hp`
- `alive = current_hp > 0`

## 5. 持久 / 瞬态边界（关键）

保留到 `SquadRuntime`（跨战斗）：
- `alive`
- `current_hp`
- `max_hp`
- 装备选择
- 由模板加载的行动/被动/AI（供后续组装战斗输入）
- 长期状态、资源占位字段

不保留到 `SquadRuntime`（战斗瞬态）：
- 冷却剩余
- 临时 buff/debuff
- 战斗 tick 状态
- 当前行动进度

## 6. 与战斗模块的关系

- `SquadRuntime` 是远征层持久状态
- `BattleBuilder` 从 `SquadRuntime` 读取并生成 `BattleStart`
- 战斗结束后 `ResultApplier` 再把 `BattleResult` 回写到 `SquadRuntime`

## 7. 手动验证建议

1. 在 `TestHub -> Squad Config` 选择角色与装备
2. 点击 `Build Config` 和 `Build Runtime`
3. 确认输出中：
   - 成员数量正确
   - `HP / max_hp / alive` 初始化正确
   - `passives` / `actions` / `ai` 来自角色模板
