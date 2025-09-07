class_name ItemStack
extends Resource

# Represents a stack of items in an inventory slot

@export var item: Item
@export var quantity: int = 0

func _init(stack_item: Item = null, stack_quantity: int = 0):
	item = stack_item
	quantity = stack_quantity

func is_empty() -> bool:
	return item == null or quantity <= 0

func can_add_item(other_item: Item, amount: int = 1) -> bool:
	if is_empty():
		return true
	if not item.can_stack_with(other_item):
		return false
	return quantity + amount <= item.max_stack_size

func add_item(other_item: Item, amount: int = 1) -> int:
	if is_empty():
		item = other_item
		quantity = min(amount, other_item.max_stack_size)
		return amount - quantity
	
	if not item.can_stack_with(other_item):
		return amount
	
	var can_add = min(amount, item.max_stack_size - quantity)
	quantity += can_add
	return amount - can_add

func remove_item(amount: int = 1) -> int:
	var removed = min(amount, quantity)
	quantity -= removed
	
	if quantity <= 0:
		item = null
		quantity = 0
	
	return removed

func split_stack(amount: int) -> ItemStack:
	if amount >= quantity:
		var result = ItemStack.new(item, quantity)
		item = null
		quantity = 0
		return result
	else:
		var result = ItemStack.new(item, amount)
		quantity -= amount
		return result

func get_display_text() -> String:
	if is_empty():
		return ""
	return item.get_display_name() + ((" x" + str(quantity)) if quantity > 1 else "")
