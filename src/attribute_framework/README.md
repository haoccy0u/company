# Attribute Framework

## 1. 目的

`src/attribute_framework` 用来统一处理“属性值本身”和“作用在属性上的运算/效果”。

它解决的是这类问题：

- 一个属性的当前值怎么保存
- 一个属性怎么被加减乘除或设置
- 一个属性怎么挂 buff / debuff
- 一个属性怎么依赖别的属性
- 一组属性在运行时怎么一起更新

它不负责这类问题：

- 什么时候触发一次攻击
- 攻击谁
- 哪个队友会被治疗
- 跨 Actor 的效果最终落到谁身上

这些仍然属于行为层、战斗层或上层业务逻辑。

## 2. 核心对象职责

### `Attribute.gd`

表示“一个属性值”。

适合用它表示：

- `hp_max`
- `hp`
- `atk`
- `def`
- `spd`
- `dmg_out_mul`
- `dmg_in_mul`
- `heal_out_mul`
- `heal_in_mul`

它负责：

- 保存 `base_value`
- 保存运行时 `computed_value`
- 提供 `set/add/sub/mult/div`
- 挂载 `AttributeBuff`
- 定义派生关系
- 定义最终值后处理

如果一个东西本质上是“角色当前拥有的一条数值状态”，优先考虑用 `Attribute`。

### `AttributeModifier.gd`

表示“一次数值运算”。

它不是状态，也不是属性，只是一次操作描述。

适合用它表示：

- `+10`
- `-5`
- `x1.2`
- `/2`
- `set 100`

它适合的场景：

- 需要描述一次明确的运算
- 需要把“操作类型”和“操作值”分开保存

如果只是一次加减乘除，不需要新建一个 Attribute，优先考虑 `AttributeModifier`。

### `AttributeBuff.gd`

表示“挂在某个 Attribute 上的持续效果”。

它本质上是：

- 一个 `AttributeModifier`
- 再加上持续时间、合并规则、名字等运行时信息

适合用它表示：

- 攻击力 +10，持续 5 秒
- 受到伤害 x1.2，持续 2 秒
- 防御力 -3，直到战斗结束

如果一个效果要“附着在属性上，并持续一段时间或直到移除”，优先考虑 `AttributeBuff`。

### `AttributeBuffDOT.gd`

表示“周期触发的 buff”。

它是 `AttributeBuff` 的特殊形式，适合：

- 每秒掉血
- 每 0.5 秒回血
- 每隔一段时间重复触发一次属性变化

如果效果不是持续改变最终值，而是“按周期反复触发”，优先考虑 `AttributeBuffDOT`。

### `AttributeSet.gd`

表示“一组属性的运行时容器”。

它负责：

- 持有多个 `Attribute`
- 建立属性名到运行时属性的映射
- 建立派生依赖关系
- 推进所有属性上的 buff 时间

如果要管理一个角色整套运行时属性，用 `AttributeSet`。

### `AttributeComponent.gd`

表示“场景树里的 Node 包装”。

它本身不新增数值能力，只是为了：

- 让场景节点能挂一个 `AttributeSet`
- 在 `_physics_process` 里调用 `attribute_set.run_process(delta)`

如果已经有上层统一调度器手动推进 `AttributeSet`，就不一定非要依赖 `AttributeComponent`。

## 3. 什么时候用什么

这是当前最重要的选择规则。

### 情况 A：我要表示一个角色真正拥有的数值

用 `Attribute`。

例如：

- 最大生命
- 当前生命
- 攻击力
- 防御力
- 速度
- 伤害倍率

判断标准：

- 它是一个“状态值”
- 它会被读取
- 它会在一段时间内持续存在

### 情况 B：我要做一次简单运算

用 `AttributeModifier`。

例如：

- 把 hp 减 10
- 把 atk 加 5
- 把伤害倍率乘 1.2

判断标准：

- 只是一次操作
- 不需要持续附着
- 不需要自己维护生命周期

### 情况 C：我要做一个持续效果

用 `AttributeBuff`。

例如：

- 中毒期间每次最终伤害增加 20%
- 虚弱期间输出倍率变成 70%
- 3 秒内攻击力 +5

判断标准：

- 它要持续存在
- 它作用在某个 Attribute 上
- 它需要时长、命名或合并规则

### 情况 D：我要做周期效果

用 `AttributeBuffDOT`。

例如：

- 每秒扣血
- 每秒回血

判断标准：

- 不是单纯“最终值一直变”
- 而是“每隔一段时间触发一次”

### 情况 E：一个属性取决于别的属性

用 `Attribute` 子类，重写：

- `derived_from()`
- `custom_compute()`
- 必要时 `post_attribute_value_changed()`

例如：

- `hp` 依赖 `hp_max` 做 clamp
- `cooldown_total` 依赖 `spd`

判断标准：

- 这是单角色内部的数值关系
- 不是一次行为事件
- 也不是跨角色逻辑

### 情况 F：我要管理一个角色整套属性

用 `AttributeSet`。

如果这个角色还在场景树中，并且需要节点自动推进，再外面包一层 `AttributeComponent`。

## 4. 明确不要这样用

### 不要把行为规则写进属性框架

这些不该放进 `attribute_framework`：

- 目标选择
- 技能选择
- 触发时机判断
- 敌我判定
- 跨 Actor 的最终落地

这些应该在行为层或战斗层处理。

### 不要把一次事件误建模成独立属性

例如：

- `damage`
- `heal`

如果它们本质上只是“对 `hp` 的一次修改请求”，那更适合建模成：

- 一次 `AttributeModifier`
- 或一组作用在 `hp` 上的计算输入

而不是长期存在的并列属性。

### 不要在业务层重复实现数值解算

如果一段逻辑本质上是：

- clamp
- 派生
- buff 运算
- modifier 运算
- 单属性最终值计算

那应优先放进 `attribute_framework`，不要在 `ActorRuntime`、`CombatEngine` 或别的业务脚本里再手写一遍。

## 5. 当前远征系统接入建议

按当前远征/战斗系统，建议这样使用：

- `ActorTemplate.base_attr_set`
  - 放静态基础属性模板

- `ActorRuntime.attr_set`
  - 放战斗中的运行时属性实例

- `RuntimeHpAttribute`
  - 继续保留
  - 因为 `hp` 是真实运行时属性，且需要依赖 `hp_max`

- `RuntimeCooldownTotalAttribute`
  - 继续保留
  - 因为它是典型的单角色内部派生关系

- `damage / heal`
  - 不应长期作为和 `hp` 并列的真实属性来扩展业务语义
  - 更适合被整理成“作用在 `hp` 上的 modifier / operation 输入”

## 6. 简单判断表

- 要表示“一个长期存在的数值状态”：用 `Attribute`
- 要表示“一次加减乘除/设置”：用 `AttributeModifier`
- 要表示“持续附着效果”：用 `AttributeBuff`
- 要表示“周期触发效果”：用 `AttributeBuffDOT`
- 要表示“属性之间的派生关系”：用 `Attribute` 子类
- 要管理“整套运行时属性”：用 `AttributeSet`
- 要在场景树里自动驱动：用 `AttributeComponent`

## 7. 当前文档结论

对这个框架，后续最重要的约束是：

- 业务层负责组织事件
- 属性框架负责处理属性计算
- 不要把事件语义误写成属性
- 不要把属性计算重新写回业务脚本
