extends RefCounted
class_name UIConfigTable

const KEY_UI_ID := "ui_id"
const KEY_SCENE := "scene"
const KEY_LAYER := "layer"
const KEY_CACHE_POLICY := "cache_policy"


static func entries() -> Array[Dictionary]:
	return [
		{
			KEY_UI_ID: &"inventory_panel",
			KEY_SCENE: preload("res://scenes/invtest/InventoryUIPanel.tscn"),
			KEY_LAYER: &"hud",
			KEY_CACHE_POLICY: &"keep_alive"
		}
	]
