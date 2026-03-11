# DevTest Scripts

`src/devtest` contains scripts for the development test hub.

## File Responsibilities

- `TestPanelBase.gd`
  - Base class for test panels.
  - Shared context and logging helpers.

- `TestRegistry.gd`
  - Registry of test panels shown in `TestHub`.

## Boundaries

- Keep only test infrastructure scripts here.
- Business logic should stay in its owning module.
- Panels are for invoking and displaying behavior, not for long-term core rules.
