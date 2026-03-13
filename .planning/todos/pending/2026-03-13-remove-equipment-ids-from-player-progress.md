---
created: 2026-03-13T02:54:04.692Z
title: Remove equipment ids from player progress
area: general
files:
  - src/actor_system/PlayerActorData.gd:13
  - src/save/codecs/PlayerProgressCodec.gd:90
  - src/save/codecs/PlayerProgressCodec.gd:109
  - src/save/codecs/PlayerProgressCodec.gd:151
  - src/save/codecs/PlayerProgressCodec.gd:173
  - src/expedition_system/squad/SquadMember.gd:39
  - src/expedition_system/squad/SquadMember.gd:60
---

## Problem

当前项目里 `equipment_ids` 仍然挂在 `PlayerActorData` 并写入 PlayerProgress 存档 codec。
但产品方向已确认：玩家 inventory 不是 roster 层职责，存档调试面板 v1 也先不显示/编辑该字段，仅保留 roster 基础进度编辑。
这会造成模型语义混杂（roster progression 与 squad loadout 耦合），后续做跨系统存档工具时容易误导和引入回归。

## Solution

将“移除 `PlayerActorData.equipment_ids` 及其存档字段”列为后续专项改造：
1. 明确装备/物品归属到 squad member 或独立 inventory 领域模型。
2. 调整 `PlayerProgressCodec`：新 schema 不再产出 `equipment_ids`；兼容读取旧档时可忽略该字段或做迁移。
3. 更新 `SquadMember.initialize_from_player(...)` 输入来源，避免直接依赖 roster 上的 `equipment_ids`。
4. 补充回归验证：远征组队初始化、存档读写兼容、调试面板字段一致性。
