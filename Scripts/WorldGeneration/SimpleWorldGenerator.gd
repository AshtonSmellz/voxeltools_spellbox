class_name SimpleWorldGenerator
extends VoxelGeneratorScript

# Simple world generator using only the 4 basic blocks
# Uses unified BlockIDs system

# Use BlockIDs enum instead of local enum
# BlockIDs.BlockID.AIR, BlockIDs.BlockID.DIRT, etc.

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
	
	# Always print for first chunk to confirm generator is running
	if origin.x == 0 and origin.z == 0:
		print("=== SimpleWorldGenerator._generate_block called ===")
		print("  Origin: ", origin)
		print("  LOD: ", lod)
	
	var buffer_size = out_buffer.get_size()
	var blocks_placed = 0
	var grass_count = 0
	var dirt_count = 0
	var sand_count = 0
	
	# Debug chunk info
	if origin.x == 0 and origin.z == 0:
		print("=== Generating chunk at origin ", origin, " with buffer size ", buffer_size, " ===")
	
	for x in range(buffer_size.x):
		for z in range(buffer_size.z):
			var world_x = origin.x + x
			var world_z = origin.z + z
			
			# Calculate terrain height and biome
			var terrain_height = _get_terrain_height(world_x, world_z)
			var is_desert = _is_desert_biome(world_x, world_z)
			
			# Debug first column and any column that includes the surface
			var surface_in_chunk_y = origin.y <= terrain_height and terrain_height < origin.y + buffer_size.y
			if (world_x == 0 and world_z == 0) or surface_in_chunk_y:
				print("Column (", world_x, ", ", world_z, "): terrain_height=", terrain_height, ", is_desert=", is_desert)
				print("  Chunk Y range: ", origin.y, " to ", origin.y + buffer_size.y - 1)
				print("  Surface is at Y=", terrain_height, " (within chunk: ", surface_in_chunk_y, ")")
			
			# Generate vertical column
			var surface_y_local = terrain_height - origin.y
			for y in range(buffer_size.y):
				var world_y = origin.y + y
				var block_id = _get_block_at(world_x, world_y, world_z, terrain_height, is_desert)
				
				if block_id != BlockIDs.BlockID.AIR:
					out_buffer.set_voxel(block_id, x, y, z, VoxelBuffer.CHANNEL_TYPE)
					blocks_placed += 1
					
					# Count block types for debugging
					if block_id == BlockIDs.BlockID.GRASS:
						grass_count += 1
					elif block_id == BlockIDs.BlockID.DIRT:
						dirt_count += 1
					elif block_id == BlockIDs.BlockID.SAND:
						sand_count += 1
	
	# Debug output for first few chunks
	if origin.x == 0 and origin.z == 0:
		print("SimpleWorldGenerator: Generated chunk at ", origin, " with ", blocks_placed, " blocks")
		print("  - Grass: ", grass_count, ", Dirt: ", dirt_count, ", Sand: ", sand_count)
		if grass_count == 0 and sand_count == 0:
			print("  WARNING: No grass or sand generated! Only dirt blocks. Check biome noise and surface height.")

func _get_terrain_height(x: int, z: int) -> int:
	# Generate rolling hills with some variation
	var height_value = height_noise.get_noise_2d(x, z)
	var height = int(height_value * max_height + sea_level)
	return max(height, sea_level - 10)  # Ensure we don't go too low

func _is_desert_biome(x: int, z: int) -> bool:
	var biome_value = biome_noise.get_noise_2d(x, z)
	var is_desert = biome_value > 0.2  # About 60% of world will be desert
	# Debug first chunk
	if x == 0 and z == 0:
		print("Biome check at (0,0): value=", biome_value, ", is_desert=", is_desert)
	return is_desert

func _get_block_at(x: int, y: int, z: int, surface_height: int, is_desert: bool) -> int:
	# Debug positions near surface
	var debug_this = (x == 0 and z == 0 and abs(y - surface_height) <= 2)
	if debug_this:
		print("  _get_block_at(", x, ", ", y, ", ", z, "): surface_height=", surface_height, ", is_desert=", is_desert, ", depth=", surface_height - y)
	
	# Check for caves first (only in solid ground areas)
	if y < surface_height - 3 and y > 5:
		var cave_value = cave_noise.get_noise_3d(x, y, z)
		if cave_value > cave_threshold:
			if debug_this:
				print("    -> AIR (cave)")
			return BlockIDs.BlockID.AIR
	
	# At or below surface - terrain layers
	# IMPORTANT: Use <= to include the surface layer (y == surface_height)
	if y <= surface_height:
		var depth = surface_height - y
		
		if depth == 0:
			# Surface layer - this is where grass or sand should be
			var block_id = BlockIDs.BlockID.SAND if is_desert else BlockIDs.BlockID.GRASS
			if debug_this:
				#print("    -> ", "SAND" if is_desert else "GRASS", " (SURFACE, depth=0, y=", y, " == surface_height=", surface_height, ")")
				pass
			return block_id
		elif depth <= 3:
			# Shallow subsurface (1-3 blocks below surface)
			var block_id = BlockIDs.BlockID.SAND if is_desert else BlockIDs.BlockID.DIRT
			if debug_this:
				#print("    -> ", "SAND" if is_desert else "DIRT", " (subsurface, depth=", depth, ")")
				pass
			return block_id
		elif depth <= 8:
			# Medium depth (4-8 blocks below surface) - dirt layer
			if debug_this:
				#print("    -> DIRT (medium depth, depth=", depth, ")")
				pass
			return BlockIDs.BlockID.DIRT
		else:
			# Deep underground - stone layer
			if debug_this:
				#print("    -> STONE (deep, depth=", depth, ")")
				pass
			return BlockIDs.BlockID.STONE
	
	# Above surface but below sea level = water (use sand as "water" substitute)
	elif y <= sea_level and surface_height < sea_level:
		if debug_this:
			#print("    -> SAND (ocean floor)")
			pass
		return BlockIDs.BlockID.SAND  # Sand represents water/ocean floor
	
	# Above ground - return air
	if debug_this:
		#print("    -> AIR (above surface, y=", y, " > surface_height=", surface_height, ")")
		pass
	return BlockIDs.BlockID.AIR

# Helper function to get surface block type for external use
func get_surface_block_type(x: int, z: int) -> int:
	if _is_desert_biome(x, z):
		return BlockIDs.BlockID.SAND
	else:
		return BlockIDs.BlockID.GRASS
