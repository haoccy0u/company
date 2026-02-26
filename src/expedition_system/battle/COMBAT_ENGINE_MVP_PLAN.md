# CombatEngine MVP 下一阶段规划（Phase 1 Kickoff）

## 1. 目标（本阶段）

本阶段目标不是直接做完整战斗，而是把 `battle` 模块的输入/输出结构先稳定下来，
为后续 `CombatEngine` 最小循环落地做准备。

本阶段完成后应具备：
- `BattleStart` / `BattleResult` 有强类型条目对象（不再只靠 Dictionary）
- 现有 `devtest` 面板继续可用（保持字典字段兼容）
- 后续可在不改远征层接口的前提下接入 `CombatEngine`

## 2. 范围（本阶段要做）

1. 新增强类型 DTO（战斗输入/结果条目）
   - `ActorEntry`
   - `ActorResult`
2. `BattleBuilder` 输出强类型条目（同时保留旧字典字段）
3. `BattleSession`（stub）输出强类型结果（同时保留旧字典字段）
4. `ResultApplier` 兼容强类型结果（保留对旧字典的兼容）

## 3. 范围（本阶段不做）

- `CombatEngine` tick 循环
- `ActorRuntime` 真正战斗实例
- AI 行动选择
- 属性系统 / modifier 结算接入
- 战斗事件流（action / damage / status / death）完整实现

## 4. 里程碑（建议顺序）

### M1. 类型化战斗输入/结果（当前开始做）
- `BattleStart.player_entries / enemy_entries`
- `BattleResult.player_actor_results`
- 保持 `players / enemies / player_results` 字典字段兼容

### M2. CombatEngine 骨架
- `CombatEngine.gd`
- `ActorRuntime.gd`
- `CombatEventLog`（或事件数组约定）
- 可运行到“回合结束/战斗结束”的空心循环

### M2.5 角色模板与被动测试数据（建议先做）
- 明确 2 个测试角色模板（便于后续 M3/M4 回归）
- 明确被动数据结构与占位参数（先数据化，后实现逻辑）
- 让 `SquadConfigTestPanel` 优先使用资源化模板，减少脚本硬编码

### M3. 最小自动战斗
- 基础攻击行动
- 冷却推进
- 简单 AI（选第一个有效目标）
- 全灭判定

### M4. 属性系统接入（第一轮）
- 从 `attribute_framework` 构建 `AttributeSet`
- 装备/被动转初始 modifiers
- HP/攻击/防御读取走属性系统

## 5. 当前默认规则（已确认）

- 战后 HP：默认由策略决定，当前已支持
  - `carry_over`
  - `reset_full`（测试用）
- debuff/status 不跨战斗（后续保留接口）
- 角色模板层：当前保持单一 `ActorTemplate`，不拆职业/单位子类模板（可先用 `tags` 表达分类）

## 6. 验证方式（本阶段）

- 运行 `TestHub`
- 在 `ExpeditionSessionTestPanel`：
  - `Advance`
  - `Build BattleStart`
  - `Resolve Combat (Stub)`
- 确认面板输出仍正常，且回写行为未回归

## 7. 完成标准（本阶段）

- `BattleStart` 和 `BattleResult` 内部已有强类型条目对象
- 现有测试面板不需要改交互流程即可继续工作
- Godot 运行无脚本报错
