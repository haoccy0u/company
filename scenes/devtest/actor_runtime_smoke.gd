extends Node

const ActorRuntimeTestServiceRef = preload("res://src/expedition_system/actor/test/ActorRuntimeTestService.gd")

@onready var runtime_host: Node = $RuntimeHost


func _ready() -> void:
	var result: Dictionary = ActorRuntimeTestServiceRef.run_smoke_suite(runtime_host)
	print("ACTOR_RUNTIME_SMOKE_RESULT::%s" % JSON.stringify(result))

	if int(result.get("fail_count", 0)) > 0:
		push_error("ActorRuntime smoke suite failed: %s" % JSON.stringify(result))

	await get_tree().create_timer(0.5).timeout
	get_tree().quit()
