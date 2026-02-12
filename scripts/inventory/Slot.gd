extends Resource
class_name Slot

@export var item: ItemData = null
@export var count: int = 0

func is_empty() -> bool:
	return item == null or count <= 0

func clear() -> void:
	item = null
	count = 0

# 把 amount 个 for_item 尽量塞进这个格子，返回“剩余没塞进去的数量”
func add_items(for_item: ItemData, amount: int) -> int:
	if for_item == null or amount <= 0:
		return amount

	var max_s = maxi(for_item.max_stack, 1)

	# 空格：直接放
	if is_empty():
		item = for_item
		var add = mini(amount, max_s)
		count = add
		return amount - add

	# 非空：不是同一种就不能合并
	if item.item_id != for_item.item_id:
		return amount

	# 同一种：补到满
	var space = max_s - count
	if space <= 0:
		return amount

	var add2 = mini(amount, space)
	count += add2
	return amount - add2

#取出物品，返回物品堆
func take(amount: int) -> ItemStack:
	if amount <= 0 or is_empty():
		return ItemStack.empty()

	# 实际能取出的数量
	var n = mini(amount, count)

	var out := ItemStack.new()
	out.item = item
	out.count = n

	count -= n
	if count <= 0:
		clear()

	return out

func place_from(stack: ItemStack, amount: int = -1) -> void:
	if stack == null or stack.is_empty():
		return
	if amount == 0:
		return

	# 这次最多尝试放多少
	var want: int = stack.count if amount < 0 else mini(amount, stack.count)
	if want <= 0:
		return

	# 空格：直接放
	if is_empty():
		item = stack.item
		var cap: int = maxi(1, item.max_stack)
		var put: int = mini(want, cap)
		count = put
		stack.count -= put
		if stack.count <= 0:
			stack.item = null
			stack.count = 0
		return

	# 非空：不是同物品就不合并（由 swap 决定）
	if item.item_id != stack.item.item_id:
		return

	# 同物品：合并到满
	var cap2: int = maxi(1, item.max_stack)
	var space: int = cap2 - count
	if space <= 0:
		return

	var put2: int = mini(want, space)
	count += put2
	stack.count -= put2
	if stack.count <= 0:
		stack.item = null
		stack.count = 0

func swap_with(stack: ItemStack) -> void:
	if stack == null:
		return

	var tmp_item := item
	var tmp_count := count

	item = stack.item
	count = stack.count

	stack.item = tmp_item
	stack.count = tmp_count

	# 规范化：保证空时 count=0
	if item == null:
		count = 0
	if stack.item == null:
		stack.count = 0
