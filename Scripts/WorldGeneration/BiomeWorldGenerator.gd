class_name BiomeWorldGenerator
extends VoxelGeneratorScript

# Comprehensive world generator that uses all available blocks
# Block IDs based on your voxel library order
enum BlockID {
	AIR = 0,
	DIRT = 1, 
	GRASS = 2,
	LOG_X = 3,
	LOG_Y = 4, 
	LOG_Z = 5,
	STAIRS_NX = 6,
	PLANKS = 7,
	TALL_GRASS = 8,
	STAIRS_NZ = 9,
	STAIRS_PX = 10,
	STAIRS_PZ = 11,
	GLASS = 12,
	WATER_TOP = 13,
	WATER_FULL = 14,
	RAIL_X = 15,
	RAIL_Z = 16,
	RAIL_TURN_NX = 17,
	RAIL_TURN_PX = 18,
	RAIL_TURN_NZ = 19,
	RAIL_TURN_PZ = 20,
	RAIL_SLOPE_NX = 21,
	RAIL_SLOPE_PX = 22,
	RAIL_SLOPE_NZ = 23,
	RAIL_SLOPE_PZ = 24,
	LEAVES = 25,
	DEAD_SHRUB = 26
}

# Noise generators for different features
var height_noise: FastNoiseLite
var cave_noise: FastNoiseLite
var biome_noise: FastNoiseLite
var tree_noise: FastNoiseLite
var decoration_noise: FastNoiseLite

# World generation parameters
@export var world_height: int = 128
@export var sea_level: int = 64
@export var cave_threshold: float = 0.3
@export var tree_density: float = 0.02
@export var decoration_density: float = 0.05

func _init():
	# Initialize noise generators
	height_noise = FastNoiseLite.new()
	height_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	height_noise.frequency = 0.005
	height_noise.fractal_octaves = 4
	
	cave_noise = FastNoiseLite.new()
	cave_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	cave_noise.frequency = 0.02
	
	biome_noise = FastNoiseLite.new()
	biome_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	biome_noise.frequency = 0.001
	
	tree_noise = FastNoiseLite.new()
	tree_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	tree_noise.frequency = 0.1
	
	decoration_noise = FastNoiseLite.new()
	decoration_noise.noise_type = FastNoiseLite.TYPE_VALUE
	decoration_noise.frequency = 0.05

func set_seed(new_seed: int):
	height_noise.seed = new_seed
	cave_noise.seed = new_seed + 1
	biome_noise.seed = new_seed + 2
	tree_noise.seed = new_seed + 3
	decoration_noise.seed = new_seed + 4

func _generate_block(out_buffer: VoxelBuffer, origin: Vector3i, lod: int):
	if lod != 0:
		return  # Only generate at highest detail
	
	var buffer_size = out_buffer.get_size()
	
	for x in range(buffer_size.x):
		for z in range(buffer_size.z):
			var world_pos = Vector3i(origin.x + x, 0, origin.z + z)
			
			# Generate height map
			var height = _get_height_at(world_pos.x, world_pos.z)
			var biome = _get_biome_at(world_pos.x, world_pos.z)
			
			# Generate vertical column
			for y in range(buffer_size.y):
				var world_y = origin.y + y
				var block_id = _get_block_at(world_pos.x, world_y, world_pos.z, height, biome)
				
				if block_id != BlockID.AIR:
					out_buffer.set_voxel(block_id, x, y, z, VoxelBuffer.CHANNEL_TYPE)

func _get_height_at(x: int, z: int) -> int:
	var base_height = height_noise.get_noise_2d(x, z) * 30.0 + sea_level
	return int(base_height)

func _get_biome_at(x: int, z: int) -> String:
	var biome_value = biome_noise.get_noise_2d(x, z)
	if biome_value > 0.3:
		return "mountain"
	elif biome_value > 0.0:
		return "forest"
	elif biome_value > -0.3:
		return "plains"
	else:
		return "swamp"

func _get_block_at(x: int, y: int, z: int, surface_height: int, biome: String) -> int:
	# Check for caves
	if y < surface_height - 5 and y > 10:
		var cave_value = cave_noise.get_noise_3d(x, y, z)
		if cave_value > cave_threshold:
			return BlockID.AIR
	
	# Below surface - generate terrain layers
	if y < surface_height:
		return _get_terrain_block(x, y, z, surface_height, biome)
	
	# At surface level - place surface features
	elif y == surface_height:
		return _get_surface_block(x, y, z, biome)
	
	# Above surface - place structures and decorations
	elif y > surface_height and y < surface_height + 10:
		return _get_above_surface_block(x, y, z, surface_height, biome)
	
	# Water level
	elif y <= sea_level:
		if y == sea_level:
			return BlockID.WATER_TOP
		else:
			return BlockID.WATER_FULL
	
	return BlockID.AIR

func _get_terrain_block(x: int, y: int, z: int, surface_height: int, biome: String) -> int:
	var depth = surface_height - y
	
	# Bedrock layer (very bottom)
	if y <= 5:
		return BlockID.PLANKS  # Using planks as "bedrock"
	
	# Stone layer (deep underground)
	elif depth > 10:
		# Add some variety in deep stone
		var stone_noise = height_noise.get_noise_3d(x, y, z)
		if stone_noise > 0.3:
			return BlockID.GLASS  # Crystal veins
		else:
			return BlockID.PLANKS  # Regular stone
	
	# Soil layers
	elif depth > 3:
		return BlockID.DIRT
	
	# Top soil - varies by biome
	else:
		match biome:
			"mountain":
				return BlockID.PLANKS  # Rocky
			"forest", "plains":
				return BlockID.DIRT
			"swamp":
				return BlockID.DIRT
			_:
				return BlockID.DIRT

func _get_surface_block(x: int, y: int, z: int, biome: String) -> int:
	match biome:
		"mountain":
			return BlockID.PLANKS  # Rocky surface
		"forest", "plains":
			return BlockID.GRASS
		"swamp":
			return BlockID.DIRT  # Muddy surface
		_:
			return BlockID.GRASS

func _get_above_surface_block(x: int, y: int, z: int, surface_height: int, biome: String) -> int:
	var height_above = y - surface_height
	
	# Trees
	if _should_place_tree(x, z, biome):
		var tree_height = _get_tree_height(biome)
		if height_above <= tree_height:
			return _get_tree_block(x, y, z, surface_height, height_above, biome)
	
	# Surface decorations
	elif height_above == 1 and _should_place_decoration(x, z, biome):
		return _get_decoration_block(biome)
	
	return BlockID.AIR

func _should_place_tree(x: int, z: int, biome: String) -> bool:
	var tree_chance = tree_noise.get_noise_2d(x, z)
	var threshold = _get_tree_threshold(biome)
	return tree_chance > threshold

func _get_tree_threshold(biome: String) -> float:
	match biome:
		"forest": return 0.3
		"plains": return 0.7
		"swamp": return 0.5
		"mountain": return 0.9
		_: return 0.8

func _get_tree_height(biome: String) -> int:
	match biome:
		"forest": return 6
		"plains": return 4
		"swamp": return 8
		"mountain": return 3
		_: return 5

func _get_tree_block(x: int, y: int, z: int, surface_height: int, height_above: int, biome: String) -> int:
	var tree_height = _get_tree_height(biome)
	
	# Tree trunk
	if height_above <= tree_height - 2:
		return BlockID.LOG_Y  # Vertical logs
	
	# Tree canopy
	else:
		# Simple spherical canopy
		var center_x = x
		var center_y = surface_height + tree_height - 1
		var center_z = z
		
		var distance = Vector3(x, y, z).distance_to(Vector3(center_x, center_y, center_z))
		if distance <= 2.5:
			return BlockID.LEAVES
	
	return BlockID.AIR

func _should_place_decoration(x: int, z: int, biome: String) -> bool:
	var decoration_chance = decoration_noise.get_noise_2d(x, z)
	var threshold = _get_decoration_threshold(biome)
	return decoration_chance > threshold

func _get_decoration_threshold(biome: String) -> float:
	match biome:
		"forest": return 0.4
		"plains": return 0.3
		"swamp": return 0.6
		"mountain": return 0.8
		_: return 0.5

func _get_decoration_block(biome: String) -> int:
	match biome:
		"forest": return BlockID.TALL_GRASS
		"plains": return BlockID.TALL_GRASS
		"swamp": return BlockID.DEAD_SHRUB
		"mountain": return BlockID.DEAD_SHRUB
		_: return BlockID.TALL_GRASS
