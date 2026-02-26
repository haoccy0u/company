# Attribute Framework README（当前项目用法说明）

## 1. 目的

`attribute_framework` 用来统一处理“属性数值 + 修饰效果（buff/modifier）”。

在当前远征/战斗系统中的定位：
- `ActorTemplate.base_attr_set`：角色基础属性模板（静态）
- `ActorRuntime.attr_set`：战斗期属性实例（运行时）
- `CombatEngine`：只负责触发时机与目标选择，数值修改尽量通过属性框架执行

## 2. 核心类职责

### `AttributeSet.gd`
作用：
- 持有一组 `Attribute`
- 在赋值 `attributes` 时，自动复制出运行时属性实例（`attributes_runtime_dict`）
- 建立属性依赖关系（derived attributes）
- 统一推进属性上的 buff 持续时间（`run_process(delta)`）

关键点：
- `attributes` 是模板数组
- `attributes_runtime_dict` 是运行期实际计算对象
- `find_attribute(name)` 用于取属性实例

### `Attribute.gd`
作用：
- 表示单个属性（例如 `hp_max`、`atk`、`dmg_out_mul`）
- 维护 `base_value`、`computed_value`
- 提供 `add/sub/mult/div/set_value` 等数值修改入口
- 管理挂载在该属性上的 `AttributeBuff`

重要机制：
- `get_value()` 会把 buff 作用结果叠加到属性最终值上
- `add_buff()` / `remove_buff()` 负责 buff 生命周期接入
- `run_process(delta)` 会推进 buff 持续时间并清理过期 buff

### `AttributeModifier.gd`
作用：
- 表示一次数值运算（加减乘除/设值）
- 是 `Attribute` 和 `AttributeBuff` 的底层运算单元

### `AttributeBuff.gd`
作用：
- 表示持续或永久数值效果（buff/debuff）
- 支持：
  - 运算类型（ADD/SUB/MULT/DIVIDE/SET）
  - 持续时间（HasDuration）
  - 合并策略（Restart / Addtion / NoEffect）

关键点：
- `add_buff()` 时会复制 buff（`duplicate_buff()`），因此可复用模板 buff
- 带 `buff_name` 时会按合并策略处理同名 buff

### `AttributeBuffDOT.gd`
作用：
- `AttributeBuff` 的 DOT（周期性）版本
- 周期触发时调用 `apply_to_attribute()`

当前远征系统尚未正式接入 DOT，但可用于后续中毒/燃烧等效果。

### `AttributeComponent.gd`
作用：
- Node 封装，用于场景节点上驱动 `AttributeSet.run_process(delta)`

当前远征 `CombatEngine` 使用的是纯脚本 `ActorRuntime`，因此没有用这个组件，而是直接在 `ActorRuntime.tick()` 中调用 `attr_set.run_process(delta)`。

## 3. 属性框架的正确使用方式（战斗系统）

### 3.1 推荐：通过 `Attribute` 方法修改数值

例如（推荐）：
- `attr.add(x)`
- `attr.sub(x)`
- `attr.mult(x)`
- `attr.set_value(x)`

优点：
- 统一走属性框架逻辑
- 与后续 derived attributes / buff 机制兼容
- 减少手写 `value += x` / `value -= x` 分支

### 3.2 推荐：持续效果用 `AttributeBuff`

例如“虚弱：伤害变为 70%（2 秒）”
- 目标属性：`dmg_out_mul`
- buff 运算：`MULT 0.7`
- duration：`2.0`
- buff_name：`weaken`

这样持续时间推进与过期移除由属性框架处理，不应在 `CombatEngine` 手动维护剩余秒数。

### 3.3 `CombatEngine` 应负责什么 / 不应负责什么

`CombatEngine` 负责：
- 触发时机（攻击命中时）
- 目标选择（命中的敌人、最低血量友方等）
- 调用属性框架（给某个属性挂 buff / 读取属性值）
- 一次性结算（伤害、治疗）

`CombatEngine` 不应负责：
- 手写 buff 持续时间递减
- 手写同名 buff 合并规则
- 重复实现加减乘除逻辑

## 4. 当前远征系统中的落地情况（截至当前）

已接入：
- `ActorTemplate.base_attr_set` 作为角色基础属性模板
- `SquadRuntimeFactory` 从 `base_attr_set.hp_max` 初始化 `MemberRuntime.max_hp`
- `ActorRuntime.attr_set` 作为战斗期属性实例
- `CombatEngine` 读取 `atk/def/spd/dmg_out_mul/...` 参与战斗结算
- `weaken` 使用 `AttributeBuff` 挂到 `dmg_out_mul`
- `ActorRuntime` 的 HP 增减优先通过属性框架 `Attribute.add/sub/set_value` 执行（运行时 `hp` 属性）

未完全接入（后续可继续重构）：
- 所有被动效果参数完全数据化（目前仍有一部分在 `CombatEngine` 中做条件逻辑）
- 状态追踪的通用化（当前主要跟踪 `weaken`）
- HP/护盾等更多战斗属性的完整属性化设计

## 5. 使用约定（建议统一）

当前建议属性名：
- `hp_max`
- `hp`（战斗期运行时属性，由 `ActorRuntime` 注入）
- `atk`
- `def`
- `spd`
- `dmg_out_mul`
- `dmg_in_mul`
- `heal_out_mul`
- `heal_in_mul`

建议：
- 模板属性（静态）放在 `ActorTemplate.base_attr_set`
- 战斗期临时属性（如 `hp`）在 `ActorRuntime` 生成时注入

## 6. 与当前战斗系统的对比（本轮重构重点）

重构前（问题）：
- HP 的增减主要靠 `current_hp +/- amount` 手写逻辑
- 虽然读取属性值用了属性框架，但数值修改路径不统一

重构后（当前）：
- `ActorRuntime.heal()` / `take_damage()` 优先通过运行时 `hp` 属性调用：
  - `Attribute.add()`
  - `Attribute.sub()`
  - `Attribute.set_value()`（用于 clamp 后回写）
- `current_hp` 变成运行时属性 `hp` 的同步镜像（便于兼容现有结果结构与 UI）

这样做的意义：
- 战斗数值改动的“入口”更统一
- 后续接 DOT、吸血、护盾等效果时更容易继续走属性框架

## 7. 后续建议

1. 为 `ActorRuntime` 增加通用 `apply_attribute_buff(attr_name, buff_template)` 方法
2. 将被动的 buff 效果完全数据化（直接复用 `AttributeBuff` 模板）
3. 逐步减少 `CombatEngine` 中硬编码常量，改为读取被动/技能资源参数
4. 若需要更严格 HP 上限/下限控制，可考虑为 `hp` 引入专用 Attribute 子类或统一后处理策略

