class_name Inventory
extends Resource

# Core inventory system

@export var slots: Array[ItemStack] = []
@export var size: int = 24

signal inventory_changed(slot_index: int)
signal item_added(item: Item, quantity: int)
signal item_removed(item: Item, quantity: int)

func _init(inventory_size: int = 24):
	size = inventory_size
	_initialize_slots()

func _initialize_slots():
	slots.clear()
	for i in range(size):
		slots.append(ItemStack.new())

func get_slot(index: int) -> ItemStack:
	if index < 0 or index >= size:
		return null
	return slots[index]

func set_slot(index: int, stack: ItemStack) -> bool:
	if index < 0 or index >= size:
		return false
	
	slots[index] = stack if stack else ItemStack.new()
	inventory_changed.emit(index)
	return true

func add_item(item: Item, quantity: int = 1) -> int:
	var remaining = quantity
	
	# First, try to add to existing stacks
	for i in range(size):
		var slot = slots[i]
		if not slot.is_empty() and slot.item.can_stack_with(item):
			var added = slot.add_item(item, remaining)
			remaining -= added
			inventory_changed.emit(i)
			if remaining <= 0:
				break
	
	# Then, try to add to empty slots
	if remaining > 0:
		for i in range(size):
			var slot = slots[i]
			if slot.is_empty():
				var added = slot.add_item(item, remaining)
				remaining -= added
				inventory_changed.emit(i)
				if remaining <= 0:
					break
	
	var added_total = quantity - remaining
	if added_total > 0:
		item_added.emit(item, added_total)
	
	return remaining

func remove_item(item: Item, quantity: int = 1) -> int:
	var remaining = quantity
	
	for i in range(size):
		var slot = slots[i]
		if not slot.is_empty() and slot.item.can_stack_with(item):
			var removed = slot.remove_item(remaining)
			remaining -= removed
			inventory_changed.emit(i)
			if remaining <= 0:
				break
	
	var removed_total = quantity - remaining
	if removed_total > 0:
		item_removed.emit(item, removed_total)
	
	return removed_total

func has_item(item: Item, quantity: int = 1) -> bool:
	var count = get_item_count(item)
	return count >= quantity

func get_item_count(item: Item) -> int:
	var count = 0
	for slot in slots:
		if not slot.is_empty() and slot.item.can_stack_with(item):
			count += slot.quantity
	return count

func get_first_empty_slot() -> int:
	for i in range(size):
		if slots[i].is_empty():
			return i
	return -1

func is_full() -> bool:
	return get_first_empty_slot() == -1

func clear():
	for i in range(size):
		slots[i] = ItemStack.new()
		inventory_changed.emit(i)

func swap_slots(index1: int, index2: int) -> bool:
	if index1 < 0 or index1 >= size or index2 < 0 or index2 >= size:
		return false
	
	var temp = slots[index1]
	slots[index1] = slots[index2]
	slots[index2] = temp
	
	inventory_changed.emit(index1)
	inventory_changed.emit(index2)
	return true
