extends Node
class_name BlockLibrary

# Import the required classes from Scripts folder
const BlockType = preload("res://Scripts/BlockType.gd")
const BlockDrop = preload("res://Scripts/BlockDrop.gd")

# Singleton for managing all block types
static var instance: BlockLibrary

# Fast lookup tables
var block_types: Dictionary = {}  # id: BlockType
var block_by_name: Dictionary = {}  # name: BlockType

# Block ID constants for performance-critical code
enum BlockIDs {
	AIR = 0,
	STONE = 1,
	DIRT = 2,
	GRASS = 3,
	WOOD = 4,
	LEAVES = 5,
	SAND = 6,
	WATER = 7,
	LAVA = 8,
	IRON_ORE = 9,
	GOLD_ORE = 10,
	CRYSTAL = 11,
	ICE = 12,
	OBSIDIAN = 13,
	MAGIC_STONE = 14
}

func _ready():
	instance = self
	_initialize_block_types()

static func get_instance() -> BlockLibrary:
	return instance

func _initialize_block_types():
	# Air
	_create_block_type(BlockIDs.AIR, "air", 0, {
		"density": 0.001,
		"hardness": 0.0,
		"friction": 0.0,
		"flags": BlockType.BlockFlags.GAS | BlockType.BlockFlags.TRANSPARENT,
		"thermal_conductivity": 0.024,
		"magical_conductivity": 0.1
	})
	
	# Stone
	_create_block_type(BlockIDs.STONE, "stone", 1, {
		"density": 2.7,
		"hardness": 3.0,
		"friction": 0.9,
		"specific_heat": 0.88,
		"thermal_conductivity": 2.5,
		"melting_point": 1200.0,
		"tool_effectiveness": {"pickaxe": 1.5, "hammer": 1.2},
		"drop_table": [_create_drop(BlockIDs.STONE, 1, 1, 1.0)]
	})
	
	# Dirt
	_create_block_type(BlockIDs.DIRT, "dirt", 2, {
		"density": 1.5,
		"hardness": 1.0,
		"friction": 0.7,
		"specific_heat": 1.26,
		"thermal_conductivity": 0.4,
		"flags": BlockType.BlockFlags.SOLID | BlockType.BlockFlags.ORGANIC,
		"tool_effectiveness": {"shovel": 2.0, "hoe": 1.5},
		"drop_table": [_create_drop(BlockIDs.DIRT, 1, 1, 1.0)]
	})
	
	# Grass
	_create_block_type(BlockIDs.GRASS, "grass", 3, {
		"density": 1.3,
		"hardness": 1.0,
		"friction": 0.6,
		"specific_heat": 1.8,
		"thermal_conductivity": 0.5,
		"flags": BlockType.BlockFlags.SOLID | BlockType.BlockFlags.ORGANIC | BlockType.BlockFlags.FLAMMABLE,
		"magical_affinity": {"nature": 0.8, "growth": 1.0},
		"tool_effectiveness": {"shovel": 2.0, "hoe": 1.8},
		"drop_table": [_create_drop(BlockIDs.DIRT, 1, 1, 1.0)]
	})
	
	# Wood
	_create_block_type(BlockIDs.WOOD, "wood", 4, {
		"density": 0.8,
		"hardness": 2.0,
		"friction": 0.8,
		"specific_heat": 1.76,
		"thermal_conductivity": 0.12,
		"flags": BlockType.BlockFlags.SOLID | BlockType.BlockFlags.ORGANIC | BlockType.BlockFlags.FLAMMABLE,
		"magical_affinity": {"nature": 1.0, "growth": 0.6},
		"tool_effectiveness": {"axe": 3.0, "saw": 2.0},
		"drop_table": [_create_drop(BlockIDs.WOOD, 1, 1, 1.0)]
	})
	
	# Water
	_create_block_type(BlockIDs.WATER, "water", 7, {
		"density": 1.0,
		"hardness": 0.0,
		"friction": 0.1,
		"restitution": 0.0,
		"specific_heat": 4.18,
		"thermal_conductivity": 0.6,
		"freezing_point": 0.0,
		"flags": BlockType.BlockFlags.LIQUID | BlockType.BlockFlags.TRANSPARENT,
		"magical_conductivity": 0.3,
		"magical_affinity": {"water": 1.0, "ice": 0.8, "healing": 0.4}
	})
	
	# Lava
	_create_block_type(BlockIDs.LAVA, "lava", 8, {
		"density": 2.8,
		"hardness": 0.0,
		"friction": 0.05,
		"specific_heat": 1.2,
		"thermal_conductivity": 4.0,
		"melting_point": 1200.0,
		"flags": BlockType.BlockFlags.LIQUID | BlockType.BlockFlags.LIGHT_SOURCE,
		"light_emission": 15,
		"magical_conductivity": 0.7,
		"magical_affinity": {"fire": 1.0, "earth": 0.6, "destruction": 0.8}
	})
	
	# Iron Ore
	_create_block_type(BlockIDs.IRON_ORE, "iron_ore", 9, {
		"density": 5.0,
		"hardness": 4.0,
		"friction": 0.9,
		"specific_heat": 0.45,
		"thermal_conductivity": 80.0,
		"electrical_conductivity": 10.0,
		"melting_point": 1538.0,
		"flags": BlockType.BlockFlags.SOLID | BlockType.BlockFlags.CONDUCTIVE,
		"magical_conductivity": 0.2,
		"tool_effectiveness": {"pickaxe": 1.8, "hammer": 1.5},
		"drop_table": [_create_drop(BlockIDs.IRON_ORE, 1, 1, 1.0)]
	})
	
	# Crystal (magical material)
	_create_block_type(BlockIDs.CRYSTAL, "crystal", 11, {
		"density": 2.2,
		"hardness": 6.0,
		"friction": 0.3,
		"restitution": 0.1,
		"specific_heat": 0.7,
		"thermal_conductivity": 1.4,
		"flags": BlockType.BlockFlags.SOLID | BlockType.BlockFlags.CRYSTALLINE | BlockType.BlockFlags.LIGHT_SOURCE,
		"light_emission": 8,
		"magical_conductivity": 2.0,
		"magical_resistance": 0.3,
		"magical_affinity": {"energy": 1.0, "light": 0.8, "amplification": 1.5},
		"tool_effectiveness": {"pickaxe": 1.0, "chisel": 2.0},
		"drop_table": [_create_drop(BlockIDs.CRYSTAL, 1, 3, 0.8)]
	})
	
	# Ice
	_create_block_type(BlockIDs.ICE, "ice", 12, {
		"density": 0.92,
		"hardness": 1.5,
		"friction": 0.1,
		"restitution": 0.05,
		"specific_heat": 2.09,
		"thermal_conductivity": 2.2,
		"melting_point": 0.0,
		"flags": BlockType.BlockFlags.SOLID | BlockType.BlockFlags.TRANSPARENT,
		"magical_conductivity": 0.4,
		"magical_affinity": {"ice": 1.0, "water": 0.6, "preservation": 0.8},
		"tool_effectiveness": {"pickaxe": 2.0, "hammer": 1.8},
		"drop_table": [_create_drop(BlockIDs.WATER, 1, 1, 1.0)]
	})
	
	# Magic Stone (enhanced material)
	_create_block_type(BlockIDs.MAGIC_STONE, "magic_stone", 14, {
		"density": 3.0,
		"hardness": 5.0,
		"friction": 0.8,
		"specific_heat": 1.0,
		"thermal_conductivity": 3.0,
		"flags": BlockType.BlockFlags.SOLID | BlockType.BlockFlags.LIGHT_SOURCE,
		"light_emission": 6,
		"magical_conductivity": 1.5,
		"magical_resistance": 0.5,
		"magical_affinity": {"all": 0.5, "amplification": 1.0},
		"tool_effectiveness": {"pickaxe": 1.2, "magic_tool": 2.0},
		"drop_table": [_create_drop(BlockIDs.MAGIC_STONE, 1, 1, 1.0)]
	})

func _create_block_type(id: int, name: String, texture_id: int, properties: Dictionary) -> BlockType:
	var block_type = BlockType.new()
	block_type.id = id
	block_type.name = name
	block_type.texture_id = texture_id
	
	# Apply custom properties
	for key in properties:
		if key == "drop_table":
			block_type.drop_table = properties[key]
		elif key == "tool_effectiveness":
			block_type.tool_effectiveness = properties[key]
		elif key == "magical_affinity":
			block_type.magical_affinity = properties[key]
		else:
			block_type.set(key, properties[key])
	
	# Store in lookup tables
	block_types[id] = block_type
	block_by_name[name] = block_type
	
	return block_type

func _create_drop(item_id: int, min_qty: int, max_qty: int, chance: float) -> BlockDrop:
	var drop = BlockDrop.new()
	drop.item_id = item_id
	drop.min_quantity = min_qty
	drop.max_quantity = max_qty
	drop.drop_chance = chance
	return drop

# Fast access methods for performance-critical code
func get_block_type(id: int) -> BlockType:
	return block_types.get(id)

func get_block_by_name(name: String) -> BlockType:
	return block_by_name.get(name)

func is_solid(id: int) -> bool:
	var block = block_types.get(id)
	return block != null and block.is_solid

func is_transparent(id: int) -> bool:
	var block = block_types.get(id)
	return block != null and block.is_transparent

func is_liquid(id: int) -> bool:
	var block = block_types.get(id)
	return block != null and block.is_liquid

func get_friction(id: int) -> float:
	var block = block_types.get(id)
	return block.friction if block != null else 0.8

func get_density(id: int) -> float:
	var block = block_types.get(id)
	return block.density if block != null else 1.0

# Magical property helpers
func get_magical_conductivity(id: int) -> float:
	var block = block_types.get(id)
	return block.magical_conductivity if block != null else 0.0

func get_affinity_for_element(id: int, element: String) -> float:
	var block = block_types.get(id)
	if block == null:
		return 0.0
	return block.get_affinity_for_element(element)
