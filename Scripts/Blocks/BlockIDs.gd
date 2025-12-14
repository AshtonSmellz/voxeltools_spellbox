class_name BlockIDs
extends RefCounted

# Unified block ID system
# These IDs must match the order in which models are added to VoxelBlockyLibrary
# When you add a model to the library, its ID is the index in the models array

enum BlockID {
	AIR = 0,
	DIRT = 1,
	GRASS = 2,
	SAND = 3,
	STONE = 4,
	WOOD = 5,
	IRON = 6,
	GLASS = 7,
	WATER = 8,
	LAVA = 9,
	LOG = 10,      # Log/wood log block (for trees)
	LEAVES = 11    # Leaves block (for trees)
}

# Mapping from block ID to item ID string (for inventory system)
static func block_id_to_item_id(block_id: int) -> String:
	match block_id:
		BlockID.AIR:
			return ""  # Air doesn't drop items
		BlockID.DIRT:
			return "dirt"
		BlockID.GRASS:
			return "grass"
		BlockID.SAND:
			return "sand"
		BlockID.STONE:
			return "stone"
		BlockID.WOOD:
			return "wood"
		BlockID.IRON:
			return "iron"
		BlockID.GLASS:
			return "glass"
		BlockID.WATER:
			return "water"
		BlockID.LAVA:
			return "lava"
		BlockID.LOG:
			return "log"
		BlockID.LEAVES:
			return "leaves"
		_:
			return ""  # Unknown block, don't drop anything

# Mapping from item ID string to block ID (for placing blocks)
static func item_id_to_block_id(item_id: String) -> int:
	match item_id:
		"dirt":
			return BlockID.DIRT
		"grass":
			return BlockID.GRASS
		"sand":
			return BlockID.SAND
		"stone":
			return BlockID.STONE
		"wood":
			return BlockID.WOOD
		"iron":
			return BlockID.IRON
		"glass":
			return BlockID.GLASS
		"water":
			return BlockID.WATER
		"lava":
			return BlockID.LAVA
		"log":
			return BlockID.LOG
		"leaves":
			return BlockID.LEAVES
		_:
			return BlockID.AIR

