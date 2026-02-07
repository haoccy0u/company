extends RefCounted
class_name ItemStack

var item: ItemData = null
var count: int = 0

func is_empty() -> bool:
	return item == null or count <= 0

static func empty() -> ItemStack:
	return ItemStack.new() # 默认 item=null,count=0
