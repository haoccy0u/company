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
- `ActorRuntime` 运行期注入 `hp` 属性（战斗内生命值）
- `CombatEngine` 读取属性：
  - `hp_max`
  - `atk`
  - `def`
  - `spd`
  - `dmg_out_mul`
  - `dmg_in_mul`
  - `heal_out_mul`
  - `heal_in_mul`
- `ActorRuntime.heal()` / `take_damage()` 优先通过 `Attribute` 方法改值（而不是直接 `current_hp +/- amount`）
- `weaken` 状态通过 `AttributeBuff` 挂载到 `dmg_out_mul`

## 4. 使用约定（建议保持一致）

推荐属性名：
- `hp_max`
- `hp`（运行期注入）
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

## 6. 当前已知改进方向

1. 给 `ActorRuntime` 增加通用 `apply_attribute_buff(attr_name, buff_template)`
2. 把更多被动效果参数化并通过 `AttributeBuff` 资源驱动
3. 进一步减少 `CombatEngine` 中的硬编码数值常量
