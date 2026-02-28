# Actor Runtime Plan

## 1. 目标

把 `ActorRuntime` 从“能工作的战斗节点”整理成“可长期维护的角色本体”。

最终目标：
- `ActorRuntime.tscn` 是统一的战斗角色场景
- `ActorRuntime.gd` 暴露稳定、易理解的角色接口
- `AttributeComponent` 与 `ActorInventoryComponent` 通过 `ActorRuntime` 协作
- `CombatEngine` 只做全局调度、跨 Actor 裁决、日志与胜负判定

## 2. 当前进度确认

### 已完成

#### 场景与组件层
- `ActorRuntime` 已改为场景实例化
- `CombatEngine` 统一实例化 `ActorRuntime.tscn`
- `ActorRuntime.tscn` 已挂：
  - `AttributeComponent`
  - `ActorInventoryComponent`
  - `VisualRoot`
  - `StateFxRoot`
  - `UiAnchor`

#### 运行时属性层
- 运行时属性已补齐当前主链路需要的 2 类：
  - `hp`
  - `cooldown_total`
- 已落地的自定义属性类：
  - `RuntimeHpAttribute`
  - `RuntimeCooldownTotalAttribute`

#### Actor 自治层
- 已下沉到 `ActorRuntime`：
  - 默认行动选择
  - 攻击目标选择
  - 回合计划生成
  - 攻击计算
  - 攻击后效果意图生成
  - 状态快照导出
  - 状态移除事件导出
  - 单 Actor 战斗结果导出
- `CombatEngine` 现在主要负责：
  - 推进时间
  - 统一调度
  - 跨 Actor 效果落地
  - 日志记录
  - 胜负判定

#### 测试层
- 已有 `ActorRuntime` 专用测试面板：
  - `scenes/devtest/panels/ActorRuntimeTestPanel.tscn`
- 当前保留手动验证入口，不再维护无 UI 自动 smoke

### 部分完成

- `ActorRuntime.gd` 已明显瘦身，但仍有继续拆分空间
- `PassiveExecutor` 已模板化一部分被动执行，但主动行为模板还没完整落地
- `observer / robot` 已切到当前通用属性和被动资源链路，但仍只是 devtest 测试资源

### 未完成

- 主动行为模板（`ActionTemplate`）未完整建立
- 敌人模板仍未资源化
- `ActorRuntime` 视觉层仍是空壳结构，尚未接正式表现

## 3. 当前明确边界

### 应继续保留在属性框架的内容
- 单角色内部数值关系
- 派生属性
- 属性 clamp
- buff / modifier 运算
- 单次作用在 `hp` 上的 modifier / operation 计算

### 应继续保留在 actor 行为层 / combat 层的内容
- 触发时机
- 目标选择
- 跨 Actor 效果意图生成
- 跨 Actor 影响的真正落地

## 4. 实现约束

后续继续推进 `ActorRuntime` 时，优先遵守这条规则：

- 如果发现某段逻辑“理论上应该由现有职责点负责，但当前能力不够”，优先扩展那个职责点，不要在别的位置临时补一层逻辑把问题糊过去。

具体到 actor / battle 当前链路，按下面方式判断：

- 如果问题属于“数值解算 / 数值通道 / clamp / buff / modifier 运算”，优先扩展 `attribute_framework` 或对应运行时属性类，不要在 `ActorRuntime` 里再补一层解算方法。
- 如果问题属于“攻击解算入口需要组织更多输入”，优先扩展 `build_attack_payload` / `resolve_attack_payload` 或后续替代它们的统一攻击解算接口，但不要把最终数值计算重新写回 actor 脚本。
- 如果问题属于“状态系统不够通用”，优先扩展状态记录 / 查询入口，不要在 `ActorRuntime` 里追加状态名硬编码。
- 如果问题属于“目标选择 / 触发时机 / 跨 Actor 效果”，优先扩展行为层或 `CombatEngine`，不要塞进属性层。

这条规则的目的不是“少改代码”，而是避免在错误职责层里继续堆补丁，导致后面越来越难拆。

## 5. Actor 模块复查结果

这次按上面的规则重新看了一遍 `src/expedition_system/actor`，当前最像“在错误位置补逻辑”的点有这些：

1. `ActorRuntime.build_attack_payload / resolve_attack_payload`
- 当前同时负责：
  - 攻击方输出基础攻击值
  - 读取目标 `def / dmg_in_mul`
  - 合并被动伤害修正
  - 产出最终伤害
- 这会把“攻击输入组织”和“最终数值解算”混在一起。
- 后续应把真正的数值计算继续下沉到 `attribute_framework`，actor 侧只保留攻击输入组织和目标侧结算入口职责。

2. `hp` 一次性结算入口
- 这类逻辑不应继续留在 `ActorRuntime`。
- 当前如果发现还需要在 actor 脚本里拼装 `raw_amount + multiplier + temp_buffs` 这一类流程，应继续下沉到 `RuntimeHpAttribute` 或对应的框架入口。
- 后续如果继续扩展伤害/治疗规则，应优先扩展“作用于 `hp` 的 operation 输入”，而不是把 `damage / heal` 重新建成并列属性。

3. `ActorRuntime.has_status`
- 这一项已从硬编码 `weaken -> dmg_out_mul` 改成通用状态查询。
- 当前剩余风险不是 actor 本体分支，而是状态记录仍依赖 `status_id -> buff_name` 的一致性。
- 后续如果继续扩状态系统，应优先补稳定的状态记录/查询模型，而不是重新回到 actor 脚本里加状态常量。

4. `ActorRuntime.select_action_id`
- 当前是“没有动作就回退 `basic_attack`，否则取第一个动作”。
- 这适合 smoke 阶段，但如果以后要支持更完整的行动模板或行动选择规则，应优先扩展行动选择入口，而不是继续在这里叠加更多角色专用 if/else。

5. `ActorRuntime.select_attack_target`
- 当前是“返回第一个可用目标”。
- 这同样适合最小可运行版本，但一旦出现前后排、嘲讽、随机、最低血量等规则，应优先扩展目标选择策略，而不是把更多 targeting 规则直接堆进这个函数。

6. `PassiveExecutor._select_heal_target`
- 当前只真正支持 `lowest_hp_percent_ally`，其它规则会被静默回退到这一条。
- 这属于“规则系统缺能力，于是在执行器里强行收口”。
- 后续如果继续加治疗/辅助目标规则，应优先抽象统一的目标选择机制。

7. `ActorInventoryComponent._resolve_or_make_item`
- 运行时装备链路里仍保留“找不到真实物品就创建 placeholder item”的 fallback。
- 这能保证 devtest 不断，但长期看属于把资源入口能力缺口补在运行时代码里。
- 后续如果继续扩装备系统，应优先补 item registry / 资源入口，而不是继续扩 placeholder fallback。

8. `ActorRuntime.is_usable`
- 当前保留为兼容入口，实际语义已开始拆分到 `can_act()` 和 `is_targetable()`。
- 这一步还没有引入新的行为规则，但已经把“能行动”和“能被选择”为未来分开扩展预留了入口。
- 后续如果要加入眩晕、禁用、离场等规则，应优先扩展这两个入口，而不是继续在调用点散着补条件。

## 6. 下一阶段建议顺序

1. 重做 `observer / robot` 的模板和被动资源
- 目标：让测试角色尽量表达“模板数据”，少依赖行为层里的角色专用假设

2. 回归测试
- `ActorRuntimeTestPanel`
- `ExpeditionSessionTestPanel`

3. 再考虑下一轮通用化
- `ActionTemplate`
- 更完整的敌人模板资源化
- 进一步清理 `CombatEngine` 中残留的角色细节

## 7. 当前判断

`ActorRuntime` 重构已经过了“骨架验证”阶段，进入“模板与资源收敛”阶段。

更直接地说：
- 角色本体结构：基本立住了
- 通用运行时属性：当前主链路已补齐
- 下一步最该做的不是继续堆逻辑，而是重做测试角色资源并验证这套底座是否足够干净

## 8. 继续工作前建议先读

继续推进 `ActorRuntime` 之前，建议先回看这些文档：

- `src/attribute_framework/README.md`
  - 看属性框架职责边界、运行时属性约定、当前已下沉的通用属性
- `src/expedition_system/actor/README.md`
  - 看 actor 模块边界、当前重构进度与当前不足
- `src/expedition_system/docs/plans/actor_runtime_test_plan.md`
  - 看 `ActorRuntime` 的手动面板测试范围
- `scenes/devtest/README.md`
  - 看当前 devtest 场景入口，尤其是 `ActorRuntimeTestPanel` 和 `TestHub`
- `src/expedition_system/README.md`
  - 看整个远征系统当前阶段结论，确认 `ActorRuntime` 在全局中的位置
- `src/expedition_system/battle/README.md`
  - 看 `CombatEngine` 与 `ActorRuntime` 的职责边界，避免继续混层
- `src/expedition_system/docs/architecture/CHARACTER_DATA_FLOW.md`
  - 看角色数据从模板到战斗实例的流转过程

如果下一步要重做 `observer / robot`，至少要先读前 3 项。
