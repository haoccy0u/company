# Squad Module（Step 1：小队配置）

## 1. 目标

本目录只负责远征系统的“小队配置与远征期运行态”。

- 输入：`SquadConfig`
- 输出：`SquadRuntime`
- 本阶段不负责：战斗逻辑、事件推进、UI 交互


## 2. 文件职责（MVP）

- `SquadConfig.gd`
  - 小队出发前配置（成员列表、小队标签）

- `MemberConfig.gd`
  - 单成员配置（角色选择、装备选择、可选初始 HP 覆盖）

- `ActorTemplate.gd`
  - 角色模板（主动技能、被动技能、AI、基础 HP 等默认内容）

- `SquadRuntime.gd`
  - 远征会话期间的小队运行态（跨战斗保留）

- `MemberRuntime.gd`
  - 单成员运行态（包含从角色模板加载后的行动/被动/AI）

- `SquadRuntimeFactory.gd`
  - `SquadConfig -> SquadRuntime` 初始化入口
  - 集中管理初始化规则，避免散落在 `ExpeditionSession`
  - 从 `ActorTemplate` 加载主动/被动/AI/基础 HP


## 3. 边界规则（本阶段必须明确）

- 保留到 `SquadRuntime` 的内容：
  - `alive`
  - `current_hp`
  - `max_hp`
  - 角色选择、装备选择
  - 从模板加载后的行动/被动/AI（供后续组装战斗输入）
  - 长期状态与资源占位字段

- 不写入 `SquadRuntime` 的内容：
  - 冷却剩余
  - 临时 buff/debuff
  - 战斗行动进度


## 4. 当前默认初始化规则（MVP）

配置约束（当前假设）：

- 玩家在 `MemberConfig` 中只选择：
  - 角色（`actor_template_id/actor_template`）
  - 装备（`equipment_ids`）
- 主动技能 / 被动技能 / AI 由 `ActorTemplate` 提供，不在 `MemberConfig` 手动配置

- `MemberRuntime.max_hp` 来自 `ActorTemplate.max_hp`
- `MemberRuntime.current_hp`：
  - 若 `MemberConfig.init_hp >= 0`，使用并 clamp 到 `[0, max_hp]`
  - 否则默认使用 `max_hp`
- `MemberRuntime.alive = current_hp > 0`

说明：

- 这里的规则只用于“远征开始时初始化”
- 战后 HP 继承/恢复策略在后续 `ResultApplier + HP Policy` 中处理，不放在本目录


## 5. 手动验证清单（Step 1）

1. 创建一个 `SquadConfig`，包含 2 个 `MemberConfig`
2. 给每个 `MemberConfig` 绑定 `ActorTemplate`
3. 调用 `SquadRuntimeFactory.from_config(config)`
4. 检查返回对象不为空
5. 检查 `members.size()` 与配置一致
6. 检查每个成员 `current_hp/max_hp/alive` 初值正确
7. 检查成员的行动/被动/AI 来自模板而不是 `MemberConfig`


## 6. 下一步（不在本次实现）

- `ExpeditionSession` 与事件触发骨架
- `BattleBuilder` 组装 `BattleStart`
- `CombatEngine` 自动战斗
