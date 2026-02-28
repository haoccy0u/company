# CombatEngine MVP Plan

## 1. 阶段目标

这一阶段的目标不是一次做完整战斗系统，而是先把 `battle/` 模块的输入、输出、主链路稳定下来，为后续 `CombatEngine` 演进打基础。

本阶段完成后应具备：
- `BattleStart` / `BattleResult` 的强类型条目
- 现有 `devtest` 面板继续可用
- 不改远征层接口的前提下继续推进战斗内核

## 2. 本阶段包含

1. 新增强类型 DTO：
   - `ActorEntry`
   - `ActorResult`
2. `BattleBuilder` 输出强类型条目，同时保留旧字典字段兼容
3. `BattleSession` 输出强类型结果，同时保留旧字典字段兼容
4. `ResultApplier` 兼容强类型结果和旧字典结果

## 3. 本阶段不包含

- 完整 tick 循环
- 完整 AI 行动选择
- 全量属性 / modifier 接入
- 完整事件系统实现
- 完整表现层

## 4. 建议里程碑

### M1. 战斗输入输出类型化

- `BattleStart.player_entries / enemy_entries`
- `BattleResult.player_actor_results`
- 保留 `players / enemies / player_results` 兼容旧面板

### M2. CombatEngine 骨架

- 新建 `CombatEngine.gd`
- 统一战斗入口
- 可以跑完最小自动战斗回合

### M2.5. 测试角色与被动数据准备

- 明确 2 个测试角色模板
- 明确被动数据结构与占位参数
- 让 `SquadConfigTestPanel` 尽量使用资源化模板

### M3. 最小自动战斗

- 基础攻击行为
- 冷却推进
- 最简单 AI
- 全灭判定

### M4. 属性系统第一轮接入

- 通过 `attribute_framework` 构建 `AttributeSet`
- 装备 / 被动转初始 modifier
- HP / 攻击 / 防御 / 速度开始统一走属性系统

## 5. 当前默认规则

- 战后 HP 由策略决定：
  - `carry_over`
  - `reset_full`
- debuff / status 不跨战斗保留
- 当前仍以单一 `ActorTemplate` 作为角色模板入口

## 6. 验证方式

- 运行 `TestHub`
- 在 `ExpeditionSessionTestPanel` 中执行：
  - `Advance`
  - `Build BattleStart`
  - `Resolve Combat`

重点确认：
- 面板输出仍正常
- 结果回写不回归
- Godot 运行无脚本错误

## 7. 完成标准

- `BattleStart` 与 `BattleResult` 已具有强类型条目
- 现有测试面板无需重写交互流程即可继续工作
- 远征层到战斗层的接口没有被破坏
