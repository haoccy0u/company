# Squad Module (Scene Runtime)

`src/expedition_system/squad` now uses node-based runtime:

- `Squad.gd`
  - squad runtime container node
  - builds members from `PlayerRosterState + ActorCatalog`
  - owns squad shared state (`get_shared/set_shared/inc_shared_int`)
  - exports final run snapshot

- `SquadMember.gd`
  - member runtime node in expedition domain
  - carries IDs/loadout/runtime dictionaries
  - uses `AttributeComponent` for dynamic attribute changes

Default scenes:
- `res://scenes/expedition/squad/Squad.tscn`
- `res://scenes/expedition/squad/SquadMember.tscn`
