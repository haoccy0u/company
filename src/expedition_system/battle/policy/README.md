# Battle HP Policy Module

`src/expedition_system/battle/policy` 负责战后 HP 回写策略。

## 当前脚本

- `PostBattleHpPolicy.gd`
  - 策略基类 / 接口约定

- `CarryOverHpPolicy.gd`
  - 战后 HP 按 `BattleResult` 结果继承（当前默认策略）

- `ResetFullHpPolicy.gd`
  - 战后 HP 回满（测试与策略对比用）

## 为什么单独拆目录

- 战后 HP 规则是经常变动的设计点
- 抽成策略可以避免把规则写死在 `ExpeditionSession` 或 `ResultApplier`
- 方便测试面板快速切换对比

## 当前调用位置

- `ResultApplier.gd` 根据 `hp_policy_id` 选择策略
- `ExpeditionSessionTestPanel` 可覆盖测试用 `hp_policy_id`
