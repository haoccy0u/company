# ActorRuntime Test Plan

## 1. 目标

先验证 `ActorRuntime` 本体，再验证它和战斗主链路的连接。
当前优先检查：
- 属性权威是否正确
- 装备是否能通过 inventory 正确影响属性
- 被动模板是否能生成正确的行为意图
- `ActorRuntime` 是否已经具备独立可测性

## 2. 测试入口

### 手动面板

- `scenes/devtest/panels/ActorRuntimeTestPanel.tscn`

用途：
- 快速构建单个 actor
- 直接查看属性、buff、行为输出
- 手动施加 hp 伤害 / 治疗 / weaken / tick
- 手动查看 `build_turn_plan()` 结果

## 3. 当前面板重点输出

### Actor Snapshot

- 当前 HP / HP Max
- 运行时属性快照
- 当前 buff 快照
- 当前装备列表

### Behavior Output

- 当前 turn plan
- damage 变化
- follow-up effects

### Validation Report

- 只显示当前最关键的 `PASS / FAIL / WAIT`

## 4. 约定

- 面板逻辑只做展示和触发
- 真正测试逻辑统一放在：
  - `src/expedition_system/actor/test/ActorRuntimeTestService.gd`

## 5. 后续扩展建议

后面可继续补充的 case：
- `hp_max` 动态变化时，`RuntimeHpAttribute` 的自动 clamp
- 作用在 `hp` 上的 damage operation 临时 buff 生效与清理
- `tick()` 后状态过期与移除
- 装备变化时旧 modifier 是否正确移除
- `cooldown_total <- spd` 在更多来源修改下是否稳定更新
