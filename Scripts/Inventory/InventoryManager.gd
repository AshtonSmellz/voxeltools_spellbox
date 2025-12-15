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
	# Try to get texture coordinates from voxel library first
	var texture_coords = _get_texture_coords_from_library()
	
	# Load atlas texture for extracting block icons
	var atlas_texture = load("res://textures/BlockSpriteSheet.png") as Texture2D
	if not atlas_texture:
		print("Warning: Could not load BlockSpriteSheet.png")
	
	# Create items based on MaterialDatabase block types
	# Use texture coordinates from library if available, otherwise use fallback values
	var dirt = Item.new("dirt", "Dirt", "Basic earth material")
	dirt.item_type = Item.ItemType.BLOCK
	dirt.max_stack_size = 64
	dirt.icon = _get_item_icon(atlas_texture, texture_coords.get("dirt", Vector2i(2, 0)))
	item_database["dirt"] = dirt
	
	var grass = Item.new("grass", "Grass Block", "Grassy earth block")
	grass.item_type = Item.ItemType.BLOCK
	grass.max_stack_size = 64
	grass.icon = _get_item_icon(atlas_texture, texture_coords.get("grass", Vector2i(0, 1)))
	item_database["grass"] = grass
	
	var sand = Item.new("sand", "Sand", "Granular material")
	sand.item_type = Item.ItemType.BLOCK
	sand.max_stack_size = 64
	sand.icon = _get_item_icon(atlas_texture, texture_coords.get("sand", Vector2i(3, 0)))
	item_database["sand"] = sand
	
	var stone = Item.new("stone", "Stone", "A solid building material")
	stone.item_type = Item.ItemType.BLOCK
	stone.max_stack_size = 64
	stone.icon = _get_item_icon(atlas_texture, texture_coords.get("stone", Vector2i(4, 0)))
	item_database["stone"] = stone
	
	var wood = Item.new("wood", "Wood", "Useful for crafting")
	wood.item_type = Item.ItemType.MATERIAL
	wood.max_stack_size = 64
	wood.icon = _get_item_icon(atlas_texture, texture_coords.get("wood", Vector2i(5, 0)))
	item_database["wood"] = wood
	
	var iron = Item.new("iron", "Iron", "Strong metallic material")
	iron.item_type = Item.ItemType.MATERIAL
	iron.max_stack_size = 64
	iron.icon = _get_item_icon(atlas_texture, texture_coords.get("iron", Vector2i(7, 0)))
	item_database["iron"] = iron
	
	var glass = Item.new("glass", "Glass", "Transparent building block")
	glass.item_type = Item.ItemType.BLOCK
	glass.max_stack_size = 64
	glass.icon = _get_item_icon(atlas_texture, texture_coords.get("glass", Vector2i(4, 0)))
	item_database["glass"] = glass
	
	var water = Item.new("water", "Water Bucket", "Contains water")
	water.item_type = Item.ItemType.MATERIAL
	water.max_stack_size = 1
	water.icon = _get_item_icon(atlas_texture, texture_coords.get("water", Vector2i(5, 0)))
	item_database["water"] = water
	
	var lava = Item.new("lava", "Lava Bucket", "Contains molten rock")
	lava.item_type = Item.ItemType.MATERIAL
	lava.max_stack_size = 1
	lava.icon = _get_item_icon(atlas_texture, texture_coords.get("lava", Vector2i(6, 0)))
	item_database["lava"] = lava
	
	var log = Item.new("log", "Log", "Tree trunk block")
	log.item_type = Item.ItemType.BLOCK
	log.max_stack_size = 64
	log.icon = _get_item_icon(atlas_texture, texture_coords.get("log", Vector2i(2, 0)))
	item_database["log"] = log
	
	var leaves = Item.new("leaves", "Leaves", "Tree foliage block")
	leaves.item_type = Item.ItemType.BLOCK
	leaves.max_stack_size = 64
	leaves.icon = _get_item_icon(atlas_texture, texture_coords.get("leaves", Vector2i(4, 1)))
	item_database["leaves"] = leaves
	
	# Tools
	var pickaxe = Item.new("pickaxe", "Pickaxe", "Tool for mining blocks")
	pickaxe.item_type = Item.ItemType.TOOL
	pickaxe.max_stack_size = 1
	item_database["pickaxe"] = pickaxe
	
	var bread = Item.new("bread", "Bread", "Restores health")
	bread.item_type = Item.ItemType.CONSUMABLE
	bread.max_stack_size = 16
	item_database["bread"] = bread

# Get texture coordinates from the voxel library by reading the actual library file
# This matches BlockIDs enum order: AIR=0, DIRT=1, GRASS=2, SAND=3, STONE=4, WOOD=5, IRON=6, etc.
func _get_texture_coords_from_library() -> Dictionary:
	var coords = {}
	
	# Try to load the voxel library
	var library_path = "res://VoxelToolFiles/voxel_blocky_library.tres"
	var library = load(library_path) as VoxelBlockyLibrary
	
	if not library or not library.models:
		print("Warning: Could not load voxel library, using fallback texture coordinates")
		return coords
	
	# Map BlockIDs to item IDs and get texture coordinates
	# BlockID 1 = DIRT -> Model index 1
	if library.models.size() > BlockIDs.BlockID.DIRT:
		var dirt_model = library.models[BlockIDs.BlockID.DIRT]
		if dirt_model is VoxelBlockyModelCube:
			coords["dirt"] = dirt_model.tile_top  # Use top face
	
	# BlockID 2 = GRASS -> Model index 2
	if library.models.size() > BlockIDs.BlockID.GRASS:
		var grass_model = library.models[BlockIDs.BlockID.GRASS]
		if grass_model is VoxelBlockyModelCube:
			coords["grass"] = grass_model.tile_top  # Use top face (grass texture)
	
	# BlockID 3 = SAND -> Model index 3
	if library.models.size() > BlockIDs.BlockID.SAND:
		var sand_model = library.models[BlockIDs.BlockID.SAND]
		if sand_model is VoxelBlockyModelCube:
			coords["sand"] = sand_model.tile_top
	
	# BlockID 4 = STONE -> Model index 4
	if library.models.size() > BlockIDs.BlockID.STONE:
		var stone_model = library.models[BlockIDs.BlockID.STONE]
		if stone_model is VoxelBlockyModelCube:
			coords["stone"] = stone_model.tile_top
	
	# BlockID 5 = WOOD -> Model index 5
	if library.models.size() > BlockIDs.BlockID.WOOD:
		var wood_model = library.models[BlockIDs.BlockID.WOOD]
		if wood_model is VoxelBlockyModelCube:
			coords["wood"] = wood_model.tile_top  # Use top face (wood top texture)
	
	# BlockID 6 = IRON -> Model index 6
	if library.models.size() > BlockIDs.BlockID.IRON:
		var iron_model = library.models[BlockIDs.BlockID.IRON]
		if iron_model is VoxelBlockyModelCube:
			coords["iron"] = iron_model.tile_top
	
	# BlockID 7 = GLASS -> Model index 7 (if exists)
	if library.models.size() > BlockIDs.BlockID.GLASS:
		var glass_model = library.models[BlockIDs.BlockID.GLASS]
		if glass_model is VoxelBlockyModelCube:
			coords["glass"] = glass_model.tile_top
	
	# BlockID 8 = WATER -> Model index 8 (if exists)
	if library.models.size() > BlockIDs.BlockID.WATER:
		var water_model = library.models[BlockIDs.BlockID.WATER]
		if water_model is VoxelBlockyModelCube:
			coords["water"] = water_model.tile_top
	
	# BlockID 9 = LAVA -> Model index 9 (if exists)
	if library.models.size() > BlockIDs.BlockID.LAVA:
		var lava_model = library.models[BlockIDs.BlockID.LAVA]
		if lava_model is VoxelBlockyModelCube:
			coords["lava"] = lava_model.tile_top
	
	# BlockID 10 = LOG -> Model index 10 (if exists)
	if library.models.size() > BlockIDs.BlockID.LOG:
		var log_model = library.models[BlockIDs.BlockID.LOG]
		if log_model is VoxelBlockyModelCube:
			coords["log"] = log_model.tile_top
	
	# BlockID 11 = LEAVES -> Model index 11 (if exists)
	if library.models.size() > BlockIDs.BlockID.LEAVES:
		var leaves_model = library.models[BlockIDs.BlockID.LEAVES]
		if leaves_model is VoxelBlockyModelCube:
			coords["leaves"] = leaves_model.tile_top
	
	print("Loaded texture coordinates from voxel library: ", coords)
	return coords

# Extract a texture tile from the atlas at the given tile position
func _get_item_icon(atlas_texture: Texture2D, tile_pos: Vector2i) -> Texture2D:
	if not atlas_texture:
		print("Warning: Atlas texture is null, cannot extract icon")
		return null
	
	# Get the image from the texture
	var atlas_image = atlas_texture.get_image()
	if not atlas_image:
		print("Warning: Could not get image from atlas texture")
		return null
	
	# Calculate pixel coordinates (tile_pos is in tile coordinates)
	# Detect tile size from atlas dimensions and library settings
	var atlas_width = atlas_image.get_width()
	var atlas_height = atlas_image.get_height()
	
	# Try to get atlas size from voxel library
	var library_path = "res://VoxelToolFiles/voxel_blocky_library.tres"
	var library = load(library_path) as VoxelBlockyLibrary
	var atlas_size_tiles = 10  # Default fallback
	if library and library.models.size() > 0:
		var first_model = library.models[0]
		if first_model is VoxelBlockyModelCube:
			atlas_size_tiles = first_model.atlas_size_in_tiles.x
			if atlas_size_tiles == 0:
				atlas_size_tiles = 10
	
	# Calculate tile size: if atlas is 60x60 and library says 10x10 tiles, tiles are 6x6 pixels
	# But if library says 10x10 tiles and atlas is larger, calculate from that
	# Actually, let's calculate: tile_size = atlas_width / atlas_size_tiles
	var tile_size = int(atlas_width / atlas_size_tiles)
	if tile_size == 0:
		tile_size = 10  # Fallback
	
	print("Atlas size: ", atlas_width, "x", atlas_height, " tiles: ", atlas_size_tiles, "x", atlas_size_tiles, " tile_size: ", tile_size)
	
	var pixel_x = tile_pos.x * tile_size
	var pixel_y = tile_pos.y * tile_size
	
	# Make sure we don't go out of bounds
	if pixel_x + tile_size > atlas_image.get_width() or pixel_y + tile_size > atlas_image.get_height():
		print("Warning: Texture coordinates out of bounds: ", tile_pos, " for atlas size: ", atlas_image.get_size())
		return null
	
	# Extract the 10x10 region
	var extracted_image = atlas_image.get_region(Rect2i(pixel_x, pixel_y, tile_size, tile_size))
	
	# Create a new ImageTexture from the extracted region
	var icon_texture = ImageTexture.create_from_image(extracted_image)
	
	if icon_texture:
		print("Successfully extracted icon texture from atlas at tile position: ", tile_pos)
	else:
		print("Warning: Failed to create ImageTexture from extracted image")
	
	return icon_texture

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