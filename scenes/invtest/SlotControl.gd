extends BaseInventorySlot
class_name SlotControl

@onready var background: TextureRect = $MarginContainer/Background
@onready var icon: TextureRect = $MarginContainer/Background/Icon
@onready var count_label: Label = $MarginContainer/Background/Icon/Count


#region Protected
func _apply_empty_view() -> void:
	icon.texture = null
	count_label.text = ""

func _apply_stack_view(slot: Slot) -> void:
	icon.texture = slot.item.texture
	count_label.text = str(slot.count) if slot.count > 1 else ""
#endregion
