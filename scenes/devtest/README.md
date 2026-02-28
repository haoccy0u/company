# DevTest Scenes

`scenes/devtest` 是通用开发测试工作台场景目录。

## 场景结构

- `TestHub.tscn`
  - 通用测试入口
  - 左侧测试列表 + 右侧面板容器 + 底部日志

- `panels/SquadConfigTestPanel.tscn`
  - 小队配置与 `SquadRuntime` 构建测试

- `panels/ExpeditionSessionTestPanel.tscn`
  - 远征推进、`BattleStart` 组装、战斗执行与回写测试
  - 以 `PASS/WAIT` 验证报告 + 固定战斗指标摘要为主

- `panels/ActorRuntimeTestPanel.tscn`
  - 单 actor 本体测试
  - 直接验证属性、装备、buff、行为输出与 smoke 结果

- `actor_runtime_smoke.tscn`
  - 无 UI 的 ActorRuntime smoke runner
  - 供 Godot MCP 启动并读取结构化测试结果

## 约定

- 面板 UI 使用 `.tscn` 保存，不在脚本里动态创建 UI 节点
- 测试面板可使用 `TestHub` 共享上下文传递测试数据
- 如需临时调试控件，优先放在 `devtest`
- `ActorRuntime` 相关测试应优先复用：
  - `src/expedition_system/actor/test/ActorRuntimeTestService.gd`
  - 手动面板与 smoke 场景必须共用同一套测试逻辑

## 当前重点回归

本阶段 `devtest` 主要用于验证 `ActorRuntime` 自治改造：
- 角色默认行动选择是否由 `ActorRuntime` 决定
- 角色被动参数读取与效果意图是否由 `ActorRuntime` 决定
- 战斗内 HP / damage 数值通道是否已收敛到属性框架
- `CombatEngine` 是否退回到“调度 + 落地 + 记录”的职责

详细用例见：
- `src/expedition_system/docs/plans/actor_autonomy_test_plan.md`
