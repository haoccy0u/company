extends Button
class_name ChestButton

@export var item_blue: ItemData
@onready var inv: InventoryComponent = $InventoryComponent


func _ready() -> void:
	# 播种测试物品（可选）
	if item_blue != null:
		inv.try_insert(item_blue, 20)

	# 直接在代码里连接 pressed 信号
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	var player := get_tree().get_first_node_in_group("player")
	if hud == null or player == null:
		push_warning("HUD or Player not found (check groups).")
		return

	# 取玩家背包组件（按你玩家的结构改路径）
	var player_inv := player.get_node("PlayerInv") as InventoryComponent
	hud.open_inventory(player_inv, inv)
