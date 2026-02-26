class_name TestRegistry extends RefCounted


static func get_entries() -> Array[Dictionary]:
	return [
		{
			"id": &"squad_config",
			"label": "Squad Config",
			"scene_path": "res://scenes/devtest/panels/SquadConfigTestPanel.tscn",
			"description": "Configure a squad and build SquadRuntime from ActorTemplate."
		},
		{
			"id": &"expedition_session",
			"label": "Expedition Session",
			"scene_path": "res://scenes/devtest/panels/ExpeditionSessionTestPanel.tscn",
			"description": "Step 2 expedition flow: setup, advance event, complete event."
		}
	]
