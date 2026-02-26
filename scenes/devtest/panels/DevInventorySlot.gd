extends BaseInventorySlot
class_name DevInventorySlot

@onready var item_label: Label = $Panel/Margin/VBox/ItemLabel
@onready var count_label: Label = $Panel/Margin/VBox/CountLabel


func _apply_empty_view() -> void:
	item_label.text = "-"
	count_label.text = ""


func _apply_stack_view(slot: Slot) -> void:
	if slot == null or slot.item == null:
		_apply_empty_view()
		return
	var item_name := String(slot.item.item_id)
	if not slot.item.item_name.is_empty():
		item_name = slot.item.item_name
	item_label.text = item_name
	count_label.text = "x%s" % slot.count if slot.count > 1 else ""
