# ActorRuntime Test Plan

## 1. 目标

`ActorRuntime` 的测试要先验证角色本体，再验证远征/战斗整链路。

优先检查：
- 属性权威是否正确
- 装备是否通过 inventory 正确影响属性
- 被动模板是否能生成正确的行为意图
- `ActorRuntime` 是否已经具备独立可测性

## 2. 测试入口

### 手动面板
- `scenes/devtest/panels/ActorRuntimeTestPanel.tscn`

用途：
- 快速构建单个 actor
- 直接查看属性、buff、行为输出
- 手动施加 damage / heal / weaken / tick
- 手动查看 `build_turn_plan()` 的结果

### MCP 自动回归
- `scenes/devtest/actor_runtime_smoke.tscn`

用途：
- 无 UI 交互
- 启动后直接跑固定 smoke suite
- 输出结构化结果，便于 MCP 调试自动化读取

## 3. 当前 smoke case

1. `hp_clamp`
- 大量治疗后不会超过 `hp_max`
- 大量受伤后会降到 `0`

2. `equipment_apply`
- 装备通过 `ActorInventoryComponent` 影响属性
- 当前检查：
  - `iron_sword`
  - `wood_shield`

3. `observer_weaken_intent`
- 观者能生成 `weaken` 施加意图
- 目标处于 `weaken` 时，额外伤害效果能进入伤害计算通道

4. `robot_heal_intent`
- 机器人能为受伤友方生成治疗 follow-up effect

## 4. 当前面板重点输出

### Actor Snapshot
- 当前 HP / HP Max
- 运行时属性快照
- 当前 buff 快照
- 当前装备列表

### Behavior Output
- 当前 turn plan
- damage 变化
- follow-up effects
- smoke suite 结果

### Validation Report
- 只显示当前最关键的 PASS / FAIL / WAIT

## 5. 约定

- 面板逻辑只做展示和触发
- 真正测试逻辑统一放在：
  - `src/expedition_system/actor/test/ActorRuntimeTestService.gd`
- smoke 场景与面板必须共用同一套 service，避免标准分叉

## 6. 后续扩展建议

后面可继续追加的 case：
- `hp_max` 动态变化时 `RuntimeHpAttribute` 的自动 clamp
- `damage` 属性通道的临时 buff 生效与清理
- `tick()` 后状态过期与移除
- 装备变化时旧 modifier 是否正确移除
- `cooldown_total <- spd` 下沉后是否正确更新
