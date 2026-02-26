# DevTest Scenes

`scenes/devtest` 是通用开发测试工作台场景目录。

## 场景结构（当前）

- `TestHub.tscn`
  - 通用测试入口
  - 左侧测试列表 + 右侧面板容器 + 底部日志

- `panels/SquadConfigTestPanel.tscn`
  - 小队配置与 `SquadRuntime` 构建测试

- `panels/ExpeditionSessionTestPanel.tscn`
  - 远征推进、`BattleStart` 组装、战斗执行与回写测试

## 约定

- 面板 UI 使用 `.tscn` 保存，不在脚本里动态创建 UI 节点
- 测试面板可使用 `TestHub` 共享上下文传递测试数据（如 `SquadRuntime`）
- 如需临时调试控件，优先放在 `devtest`，避免污染正式场景
