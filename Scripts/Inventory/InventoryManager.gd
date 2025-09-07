class_name InventoryManager
extends Node

# Main inventory manager that coordinates inventory system

@export var initial_items: Array[String] = []  # Item IDs to start with

var inventory: Inventory
var hotbar_ui: HotbarUI
var inventory_ui: InventoryUI

# Item database - in a real game, this would be loaded from files
var item_database: Dictionary = {}

signal item_selected(item: Item)
signal hotbar_changed(slot_index: int)

func _ready():
	_initialize_item_database()
	_initialize_inventory()
	_create_ui()
	_add_initial_items()

func _initialize_item_database():
	# Create items based on MaterialDatabase block types
	var dirt = Item.new("dirt", "Dirt", "Basic earth material")
	dirt.item_type = Item.ItemType.BLOCK
	dirt.max_stack_size = 64
	item_database["dirt"] = dirt
	
	var grass = Item.new("grass", "Grass Block", "Grassy earth block")
	grass.item_type = Item.ItemType.BLOCK
	grass.max_stack_size = 64
	item_database["grass"] = grass
	
	var sand = Item.new("sand", "Sand", "Granular material")
	sand.item_type = Item.ItemType.BLOCK
	sand.max_stack_size = 64
	item_database["sand"] = sand
	
	var stone = Item.new("stone", "Stone", "A solid building material")
	stone.item_type = Item.ItemType.BLOCK
	stone.max_stack_size = 64
	item_database["stone"] = stone
	
	var wood = Item.new("wood", "Wood", "Useful for crafting")
	wood.item_type = Item.ItemType.MATERIAL
	wood.max_stack_size = 64
	item_database["wood"] = wood
	
	var iron = Item.new("iron", "Iron", "Strong metallic material")
	iron.item_type = Item.ItemType.MATERIAL
	iron.max_stack_size = 64
	item_database["iron"] = iron
	
	var glass = Item.new("glass", "Glass", "Transparent building block")
	glass.item_type = Item.ItemType.BLOCK
	glass.max_stack_size = 64
	item_database["glass"] = glass
	
	var water = Item.new("water", "Water Bucket", "Contains water")
	water.item_type = Item.ItemType.MATERIAL
	water.max_stack_size = 1
	item_database["water"] = water
	
	var lava = Item.new("lava", "Lava Bucket", "Contains molten rock")
	lava.item_type = Item.ItemType.MATERIAL
	lava.max_stack_size = 1
	item_database["lava"] = lava
	
	# Tools
	var pickaxe = Item.new("pickaxe", "Pickaxe", "Tool for mining blocks")
	pickaxe.item_type = Item.ItemType.TOOL
	pickaxe.max_stack_size = 1
	item_database["pickaxe"] = pickaxe
	
	var bread = Item.new("bread", "Bread", "Restores health")
	bread.item_type = Item.ItemType.CONSUMABLE
	bread.max_stack_size = 16
	item_database["bread"] = bread

func _initialize_inventory():
	inventory = Inventory.new(24)  # 24 slots total

func _create_ui():
	# Create hotbar UI
	hotbar_ui = HotbarUI.new()
	hotbar_ui.name = "HotbarUI"
	hotbar_ui.hotbar_selection_changed.connect(_on_hotbar_selection_changed)
	
	# Create main inventory UI
	inventory_ui = InventoryUI.new()
	inventory_ui.name = "InventoryUI"
	inventory_ui.inventory_closed.connect(_on_inventory_closed)
	
	# Add to scene tree
	add_child(hotbar_ui)
	add_child(inventory_ui)
	
	# Setup with inventory
	hotbar_ui.setup_with_manager(self)
	inventory_ui.setup_with_manager(self)

func _add_initial_items():
	for item_id in initial_items:
		add_item_by_id(item_id, 1)

func get_item_by_id(item_id: String) -> Item:
	return item_database.get(item_id, null)

func add_item_by_id(item_id: String, quantity: int = 1) -> int:
	var item = get_item_by_id(item_id)
	if not item:
		print("Warning: Unknown item ID: ", item_id)
		return quantity
	
	return inventory.add_item(item, quantity)

func remove_item_by_id(item_id: String, quantity: int = 1) -> int:
	var item = get_item_by_id(item_id)
	if not item:
		return 0
	
	return inventory.remove_item(item, quantity)

func has_item_by_id(item_id: String, quantity: int = 1) -> bool:
	var item = get_item_by_id(item_id)
	if not item:
		return false
	
	return inventory.has_item(item, quantity)

func get_selected_item() -> ItemStack:
	if hotbar_ui:
		return hotbar_ui.get_selected_item()
	return null

func _on_hotbar_selection_changed(slot_index: int):
	hotbar_changed.emit(slot_index)
	var selected_item_stack = get_selected_item()
	if selected_item_stack and not selected_item_stack.is_empty():
		item_selected.emit(selected_item_stack.item)

func _on_inventory_closed():
	# Re-capture mouse when inventory closes
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func toggle_inventory():
	if inventory_ui.visible:
		inventory_ui.hide_inventory()
	else:
		inventory_ui.show_inventory()

func _input(event: InputEvent):
	# Toggle inventory with Tab key
	if event.is_action_pressed("toggle_inventory"):
		toggle_inventory()
		get_viewport().set_input_as_handled()

# Utility functions for external access
func give_item(item_id: String, quantity: int = 1):
	add_item_by_id(item_id, quantity)

func take_item(item_id: String, quantity: int = 1) -> bool:
	if has_item_by_id(item_id, quantity):
		remove_item_by_id(item_id, quantity)
		return true
	return false