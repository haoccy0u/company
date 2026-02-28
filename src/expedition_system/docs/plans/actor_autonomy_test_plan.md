# Actor Autonomy Test Plan

## 1. 目标

这份方案用于验证“Actor 尽可能自治”的改造是否成立。

要验证的不是单纯“能不能打起来”，而是下面 4 个边界是否成立：

1. `ActorRuntime` 是否能自己管理行为配置
2. `ActorRuntime` 是否能自己解释被动规则
3. `ActorRuntime` 是否能自己管理伤害 / 治疗数值通道
4. `CombatEngine` 是否已经退回到“调度 + 落地 + 记录”的职责

## 2. 本轮要验证的自治能力

### A. 行动选择自治

验证点：
- `CombatEngine` 不再直接从 `action_ids[0]` 读取默认行动
- 默认行动由 `ActorRuntime.select_action_id()` 决定

### B. 被动规则自治

验证点：
- `CombatEngine` 不再直接解析角色被动参数
- 被动存在判断、参数读取、效果意图生成由 `ActorRuntime` 及其行为层决定

当前已下沉：
- `build_on_attack_effects()`
- `build_attack_payload()`
- `resolve_attack_payload()`
- 被动 effect 的解析与执行入口

### C. 数值通道自治

验证点：
- 战斗内 HP 权威是运行时 `hp` 属性
- 单次伤害 / 治疗通过 `RuntimeHpAttribute` 的 operation 入口结算
- `ActorRuntime.apply_damage()` / `apply_heal()` 只组织事件，不直接做 `current_hp +/- amount`

### D. 状态语义自治

验证点：
- `CombatEngine` 不再知道具体状态挂在哪条属性上
- 当前至少 `weaken` 已通过 `ActorRuntime.has_status()` 封装

## 3. 现有测试入口

使用：
- `scenes/devtest/TestHub.tscn`
- `scenes/devtest/panels/SquadConfigTestPanel.tscn`
- `scenes/devtest/panels/ExpeditionSessionTestPanel.tscn`

## 4. 推荐手动验证流程

### Case 1：基础链路不回归

步骤：
1. 打开 `TestHub`
2. 进入 `Squad Config`
3. 选择 `observer + robot`
4. 点击 `Build Runtime`
5. 切到 `Expedition Session`
6. 点击 `Build Session`
7. 点击 `Advance`
8. 点击 `Resolve Combat`

期望：
- 无脚本报错
- 战斗正常结束
- 小队状态可回写

### Case 2：观者被动自治

目标：
- 验证 `crush_joints` 的规则已由 `ActorRuntime` 侧解释

关注日志：
- `passive_trigger`：`bonus_damage_vs_weakened`
- `status_applied`：`weaken`
- `status_removed`：`weaken`

期望：
- 观者命中后能施加 `weaken`
- 目标处于 `weaken` 时再次受击有额外伤害
- `CombatEngine` 只负责记录和落地，不负责查参数

### Case 3：机器人被动自治

目标：
- 验证 `attack_heal_ally` 的目标选择和治疗量由 `ActorRuntime` 生成意图

关注日志：
- `passive_trigger`：`heal_one_ally_on_attack`
- `value_change`：友方 `hp` 上升

期望：
- 攻击后会治疗一个友方
- 治疗目标优先是当前血量比例最低的友方

### Case 4：伤害通道验证

目标：
- 验证伤害先经过 `RuntimeHpAttribute` 的 operation 计算，再应用到 `hp`

间接验证方式：
- 战斗结果与当前预期一致
- `ActorRuntime.apply_damage()` / `apply_heal()` 不直接执行 `current_hp` 算术
- `CombatEngine` 的伤害 / 治疗结算最终落到 `hp`

## 5. 推荐代码边界检查

### CombatEngine 边界

检查 `src/expedition_system/battle/CombatEngine.gd`：
- 不再有被动参数读取逻辑
- 不再有默认行动选择逻辑
- 不再直接写 `cooldown_remaining`
- 不再直接改 actor 起始 HP tag

### ActorRuntime 边界

检查 `src/expedition_system/actor/ActorRuntime.gd`：
- 有行动选择接口
- 有攻击计算接口
- 有攻击后效果意图生成接口
- 有 `hp` 与 `cooldown_total` 运行时属性
- 有作用在 `hp` 上的 damage / heal operation 入口

## 6. 通过标准

通过需要同时满足：
- `TestHub` 可启动
- 基础远征战斗链路不回归
- `observer` / `robot` 两个被动都继续生效
- `CombatEngine` 职责收缩明显
- `ActorRuntime` 已成为角色内部规则的主要承载者

## 7. 下一阶段测试方向

如果本轮通过，下一轮应继续扩展到：
- actor 自定义 action 选择
- 更多状态语义封装
- UI 直接绑定 `ActorRuntime` 场景节点

## 8. 被动模板化回归补充

本轮新增重点：
- `ActorRuntime.gd` 中不再直接按 `crush_joints / attack_heal_ally` 分支执行被动
- 被动资源 `.tres` 中应存在 `effects` 定义
- 伤害附加效果应通过 `RuntimeHpAttribute` 的 operation 输入 + `AttributeBuff` 完成
