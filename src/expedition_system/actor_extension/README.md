# Actor Extension (Expedition)

This directory is reserved for expedition-specific actor assembly logic.

Current model changes:
- legacy `ActorInstance` runtime model has been removed
- squad runtime now uses scene nodes (`Squad` + `SquadMember`)

Future logic can be added here without mixing back into `actor_system`.
