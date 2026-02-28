# Attribute Framework

## 1. 目的

`src/attribute_framework` 用于统一处理“属性值 + modifier / buff”的数值逻辑。

在当前远征/战斗系统中的定位：
- `ActorTemplate.base_attr_set`：角色基础属性模板（静态）
- `ActorRuntime.attr_set`：战斗期属性实例（运行时）
- `CombatEngine`：负责触发时机与目标选择，尽量复用属性框架完成数值变化

## 2. 核心脚本职责

### `AttributeSet.gd`
- 持有一组 `Attribute`
- 根据 `attributes` 构建运行时属性字典（`attributes_runtime_dict`）
- 统一推进属性上的 buff 持续时间（`run_process(delta)`）
- 提供 `find_attribute(name)` 查询入口

### `Attribute.gd`
- 单个属性（如 `hp_max`, `atk`, `dmg_out_mul`）
- 管理 `base_value` / `computed_value`
- 提供 `add/sub/mult/div/set_value` 等数值修改方法
- 管理挂载在该属性上的 `AttributeBuff`
- 提供“单个属性自定义计算方式”的接口：
  - `custom_compute(operated_value, compute_params)`
  - `derived_from()`
  - `post_attribute_value_changed(value)`

这 3 个接口的分工：
- `derived_from()`
  - 声明这个属性依赖哪些其它属性
- `custom_compute(...)`
  - 定义该属性在基础运算之后，如何结合依赖属性重新计算
- `post_attribute_value_changed(...)`
  - 定义最终值的后处理逻辑，例如 clamp、下限保护、格式化修正

### `AttributeModifier.gd`
- 描述单次数值运算（加减乘除、设置）
- 是 `Attribute` / `AttributeBuff` 的底层运算单元

### `AttributeBuff.gd`
- 持续或永久的属性效果（buff/debuff）
- 支持：
  - 运算类型（ADD/SUB/MULT/DIVIDE/SET）
  - 持续时间
  - 同名 buff 合并策略
- 可作为模板重复使用（内部会复制）

### `AttributeBuffDOT.gd`
- 周期性 buff（DOT/HOT 的基础）
- 当前远征战斗未正式接入，但可用于后续扩展

### `AttributeComponent.gd`
- `Node` 包装，用于场景节点上驱动 `AttributeSet.run_process(delta)`
- 当前 `CombatEngine` 主要仍直接驱动 `ActorRuntime.attr_set`，未强依赖此组件

## 3. 当前在战斗系统中的用法（已落地）

- 角色模板基础属性来自 `ActorTemplate.base_attr_set`
- 战斗开始时复制为 `ActorRuntime.attr_set`
- `ActorRuntime` 运行期注入通用属性：
  - `hp`
  - `damage`
  - `heal`
  - `cooldown_total`
- `CombatEngine` 读取属性：
  - `hp_max`
  - `atk`
  - `def`
  - `spd`
  - `dmg_out_mul`
  - `dmg_in_mul`
  - `heal_out_mul`
  - `heal_in_mul`
- `ActorRuntime.apply_heal()` / `apply_damage()` 通过 `Attribute` 方法改值，不再直接对 `current_hp` 做算术修改
- `ActorRuntime` 当前还会创建运行时 `damage` 属性，用作单次伤害结算通道
- `weaken` 状态通过 `AttributeBuff` 挂载到 `dmg_out_mul`

## 4. 使用约定（建议保持一致）

推荐属性名：
- `hp_max`
- `hp`（运行期注入）
- `damage`（运行期注入）
- `heal`（运行期注入）
- `cooldown_total`（运行期注入）
- `atk`
- `def`
- `spd`
- `dmg_out_mul`
- `dmg_in_mul`
- `heal_out_mul`
- `heal_in_mul`

## 5. 战斗层与属性框架的职责边界

`CombatEngine` 负责：
- 触发时机（攻击命中、行动结束等）
- 目标选择（敌方、友方、最低血量等）
- 调用属性框架读取/修改数值
- 战斗规则裁决与日志输出

属性框架负责：
- buff 持续时间推进
- buff 合并规则
- 属性最终值计算
- 基础数值运算入口（`add/sub/mult/...`）

进一步约定：
- 只要某段逻辑属于“单个角色内部的数值关系”，优先考虑放进 `Attribute` 子类
- 只要某段逻辑依赖“触发时机 / 目标选择 / 跨角色影响”，应保留在行为层或 `CombatEngine`

当前划分示例：
- 适合属性框架：
  - `hp` 对 `hp_max` 的钳制
  - `damage` 作为单次伤害通道的最终数值处理
  - 未来的 `cooldown_total <- spd` 派生关系
- 不适合属性框架：
  - 攻击时选择哪个敌人
  - 攻击后给谁治疗
  - 什么时候触发被动
  - 跨 Actor 的效果真正落地

## 6. 当前已下沉的通用属性优化

### `RuntimeHpAttribute.gd`
- 运行时 `hp` 不再只是一条普通属性
- 现在由 `RuntimeHpAttribute` 负责：
  - 依赖 `hp_max`
  - 在 `post_attribute_value_changed()` 中统一钳制到 `0..hp_max`

这意味着：
- `ActorRuntime.apply_heal()` / `apply_damage()` 不再手动对 `hp` 做 clamp
- `ActorRuntime.current_hp` 只是运行时 `hp` 的镜像输出，不再是权威来源

### `RuntimeDamageAttribute.gd`
- 运行时 `damage` 通道属性
- 负责把单次伤害结算值约束为非负

### `RuntimeHealAttribute.gd`
- 运行时 `heal` 通道属性
- 负责把单次治疗结算值约束为非负

### `RuntimeCooldownTotalAttribute.gd`
- 运行时 `cooldown_total` 属性
- 依赖 `spd`
- 统一计算：
  - `cooldown_total = 1 / max(spd, 0.1)`
- actor 不再直接手算这条关系

## 7. 推荐后续优化顺序

1. `hp`
   - 已完成：钳制逻辑下沉到自定义属性类
2. `damage`
   - 已完成：收口为运行时通道属性
3. `cooldown_total`
   - 已完成：作为 `spd` 的派生属性
4. `heal`
   - 已完成：补齐与 `damage` 对称的临时属性通道

## 8. 当前已知改进方向

1. 继续把更多单角色数值关系收进自定义属性类
2. 把更多被动效果参数化并通过 `AttributeBuff` 资源驱动
3. 继续减少 `CombatEngine` 中的硬编码数值常量
4. 在测试资源层重新设计观者 / 机器人，验证新的通用属性通道
