class_name SimpleWorldGenerator
extends VoxelGeneratorScript

# Simple world generator using only the 4 basic blocks
# Block IDs: 0=Air, 1=Dirt, 2=Grass, 3=Sand

enum BlockID {
	AIR = 0,
	DIRT = 1,
	GRASS = 2, 
	SAND = 3
}

# Noise generators
var height_noise: FastNoiseLite
var biome_noise: FastNoiseLite
var cave_noise: FastNoiseLite

# Generation parameters
@export var sea_level: int = 64
@export var max_height: int = 32  # Height variation range
@export var cave_threshold: float = 0.4

func _init():
	# Height noise for terrain shape
	height_noise = FastNoiseLite.new()
	height_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	height_noise.frequency = 0.01
	height_noise.fractal_octaves = 3
	
	# Biome noise to determine grass vs desert areas
	biome_noise = FastNoiseLite.new()
	biome_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	biome_noise.frequency = 0.003
	
	# Cave noise for underground caverns
	cave_noise = FastNoiseLite.new()
	cave_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	cave_noise.frequency = 0.02

func set_seed(new_seed: int):
	height_noise.seed = new_seed
	biome_noise.seed = new_seed + 1
	cave_noise.seed = new_seed + 2
	print("Set simple world generator seed to: ", new_seed)

func _generate_block(out_buffer: VoxelBuffer, origin: Vector3i, lod: int):
	if lod != 0:
		return  # Only generate at highest detail
	
	var buffer_size = out_buffer.get_size()
	var blocks_placed = 0
	
	for x in range(buffer_size.x):
		for z in range(buffer_size.z):
			var world_x = origin.x + x
			var world_z = origin.z + z
			
			# Calculate terrain height and biome
			var terrain_height = _get_terrain_height(world_x, world_z)
			var is_desert = _is_desert_biome(world_x, world_z)
			
			# Generate vertical column
			for y in range(buffer_size.y):
				var world_y = origin.y + y
				var block_id = _get_block_at(world_x, world_y, world_z, terrain_height, is_desert)
				
				if block_id != BlockID.AIR:
					out_buffer.set_voxel(block_id, x, y, z, VoxelBuffer.CHANNEL_TYPE)
					blocks_placed += 1
	
	# Debug output for first few chunks
	if origin.x == 0 and origin.z == 0:
		print("SimpleWorldGenerator: Generated chunk at ", origin, " with ", blocks_placed, " blocks")

func _get_terrain_height(x: int, z: int) -> int:
	# Generate rolling hills with some variation
	var height_value = height_noise.get_noise_2d(x, z)
	var height = int(height_value * max_height + sea_level)
	return max(height, sea_level - 10)  # Ensure we don't go too low

func _is_desert_biome(x: int, z: int) -> bool:
	var biome_value = biome_noise.get_noise_2d(x, z)
	return biome_value > 0.2  # About 60% of world will be desert

func _get_block_at(x: int, y: int, z: int, surface_height: int, is_desert: bool) -> int:
	# Check for caves first (only in solid ground areas)
	if y < surface_height - 3 and y > 5:
		var cave_value = cave_noise.get_noise_3d(x, y, z)
		if cave_value > cave_threshold:
			return BlockID.AIR
	
	# Below surface - terrain layers
	if y < surface_height:
		var depth = surface_height - y
		
		if depth == 0:
			# Surface layer
			if is_desert:
				return BlockID.SAND
			else:
				return BlockID.GRASS
		elif depth <= 3:
			# Shallow subsurface
			if is_desert:
				return BlockID.SAND
			else:
				return BlockID.DIRT
		else:
			# Deep underground - always dirt
			return BlockID.DIRT
	
	# Above surface but below sea level = water (use sand as "water" substitute)
	elif y <= sea_level and surface_height < sea_level:
		return BlockID.SAND  # Sand represents water/ocean floor
	
	# Above ground = air
	return BlockID.AIR

# Helper function to get surface block type for external use
func get_surface_block_type(x: int, z: int) -> int:
	if _is_desert_biome(x, z):
		return BlockID.SAND
	else:
		return BlockID.GRASS
