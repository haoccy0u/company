# DevTest Scripts

`src/devtest` 是开发测试工作台的脚本层（非正式玩法逻辑）。

## 文件职责

- `TestPanelBase.gd`
  - 测试面板基类
  - 提供日志接口与共享上下文访问（`ctx_get/ctx_set/...`）

- `TestRegistry.gd`
  - 注册可在 `TestHub` 中显示的测试面板
  - 作为测试项入口清单

## 边界约定

- 这里只放测试基础设施脚本
- 业务逻辑仍放在对应模块（如 `expedition_system`）
- 面板只做调用/展示，不长期承载核心规则实现
