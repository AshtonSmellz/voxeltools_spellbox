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
var tree_noise: FastNoiseLite  # For tree placement

# Generation parameters
@export var sea_level: int = 64
@export var max_height: int = 32  # Height variation range
@export var cave_threshold: float = 0.4
@export var tree_density: float = 0.05  # Probability of tree per block (5% chance)

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
	
	# Tree noise for tree placement
	tree_noise = FastNoiseLite.new()
	tree_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	tree_noise.frequency = 0.05

func set_seed(new_seed: int):
	height_noise.seed = new_seed
	biome_noise.seed = new_seed + 1
	cave_noise.seed = new_seed + 2
	tree_noise.seed = new_seed + 3
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
			
			# Generate trees above surface (only in non-desert biomes, on grass blocks)
			# Only check once per column, after terrain is generated
			# IMPORTANT: Only generate trees if the surface is actually in this chunk
			var surface_in_chunk = surface_y_local >= 0 and surface_y_local < buffer_size.y
			
			# Debug: Show ALL attempts (first few columns) to see what's happening
			if x < 3 and z < 3:
				print("TREE CODE at (", world_x, ", ", world_z, "): surface_in_chunk=", surface_in_chunk, ", is_desert=", is_desert, ", surface_y_local=", surface_y_local, ", terrain_height=", terrain_height, ", origin.y=", origin.y)
			
			# Only proceed if surface is in this chunk AND not desert
			if not is_desert and surface_in_chunk:
				# Check if surface block is grass (trees only grow on grass)
				var surface_block = out_buffer.get_voxel(x, surface_y_local, z, VoxelBuffer.CHANNEL_TYPE)
				
				# Debug: Always show when surface is in chunk
				if x < 3 and z < 3:
					print("  -> Surface IN chunk! World Y=", terrain_height, ", Local Y=", surface_y_local, ", Block: ", surface_block, " (GRASS=", BlockIDs.BlockID.GRASS, ", match=", surface_block == BlockIDs.BlockID.GRASS, ")")
				
				if surface_block == BlockIDs.BlockID.GRASS:
					# Check if we should place a tree at this position
					var should_place = _should_place_tree(world_x, world_z)
					var tree_noise_val = tree_noise.get_noise_2d(world_x, world_z)
					var threshold = 1.0 - (tree_density * 20.0)  # Updated to match _should_place_tree
					
					# Debug: Always show tree placement checks
					if x < 3 and z < 3:
						print("  -> GRASS found! Tree check: should_place=", should_place, ", tree_noise=", tree_noise_val, ", threshold=", threshold)
					
					if should_place:
						# Double-check surface_y_local calculation
						var recalc_surface_y = terrain_height - origin.y
						print("  *** PLACING TREE at world (", world_x, ", ", world_z, ") ***")
						print("    Surface world Y=", terrain_height, ", Chunk origin.y=", origin.y, ", surface_y_local=", surface_y_local, " (recalc: ", recalc_surface_y, ")")
						print("    Chunk Y range: ", origin.y, " to ", origin.y + buffer_size.y - 1)
						if surface_y_local != recalc_surface_y:
							print("    ERROR: surface_y_local mismatch! Using recalculated value.")
							surface_y_local = recalc_surface_y
						print("    Calling _generate_tree with: local_x=", x, ", surface_y=", surface_y_local, ", local_z=", z, ", origin=", origin)
						_generate_tree(out_buffer, x, surface_y_local, z, buffer_size, origin)
						print("    _generate_tree call completed")
				elif x < 3 and z < 3:
					print("  -> Surface block is NOT grass (", surface_block, "), skipping tree")
			elif x < 3 and z < 3:
				if is_desert:
					print("  -> Skipping: is_desert=true")
				else:
					print("  -> Skipping: surface_in_chunk=false")
	
	# Debug output for first few chunks
	if origin.x == 0 and origin.z == 0:
		print("SimpleWorldGenerator: Generated chunk at ", origin, " with ", blocks_placed, " blocks")
		print("  - Grass: ", grass_count, ", Dirt: ", dirt_count, ", Sand: ", sand_count)
		if grass_count == 0 and sand_count == 0:
			print("  WARNING: No grass or sand generated! Only dirt blocks. Check biome noise and surface height.")
		print("  Tree density setting: ", tree_density, " (threshold: ", 1.0 - (tree_density * 10.0), ")")

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
				print("    -> ", "SAND" if is_desert else "GRASS", " (SURFACE, depth=0, y=", y, " == surface_height=", surface_height, ")")
			return block_id
		elif depth <= 3:
			# Shallow subsurface (1-3 blocks below surface)
			var block_id = BlockIDs.BlockID.SAND if is_desert else BlockIDs.BlockID.DIRT
			if debug_this:
				print("    -> ", "SAND" if is_desert else "DIRT", " (subsurface, depth=", depth, ")")
			return block_id
		elif depth <= 8:
			# Medium depth (4-8 blocks below surface) - dirt layer
			if debug_this:
				print("    -> DIRT (medium depth, depth=", depth, ")")
			return BlockIDs.BlockID.DIRT
		else:
			# Deep underground - stone layer
			if debug_this:
				print("    -> STONE (deep, depth=", depth, ")")
			return BlockIDs.BlockID.STONE
	
	# Above surface but below sea level = water (use sand as "water" substitute)
	elif y <= sea_level and surface_height < sea_level:
		if debug_this:
			print("    -> SAND (ocean floor)")
		return BlockIDs.BlockID.SAND  # Sand represents water/ocean floor
	
	# Above ground - check for trees (handled separately in _generate_block)
	# For now, return air - trees are placed in a second pass
	if debug_this:
		print("    -> AIR (above surface, y=", y, " > surface_height=", surface_height, ")")
	return BlockIDs.BlockID.AIR

# Helper function to get surface block type for external use
func get_surface_block_type(x: int, z: int) -> int:
	if _is_desert_biome(x, z):
		return BlockIDs.BlockID.SAND
	else:
		return BlockIDs.BlockID.GRASS

# Check if a tree should be placed at this position
func _should_place_tree(x: int, z: int) -> bool:
	# Only place trees in non-desert biomes
	if _is_desert_biome(x, z):
		return false
	
	# Use tree noise to determine placement
	var tree_value = tree_noise.get_noise_2d(x, z)
	# Tree noise returns values from -1.0 to 1.0
	# We want trees to spawn when noise is above a threshold
	# Lower threshold = more trees
	# With tree_density = 0.05, threshold = 1.0 - 0.5 = 0.5
	# This means trees spawn when noise > 0.5, which is ~25% of values
	# Let's make it more common: threshold = 1.0 - (tree_density * 20.0)
	# For 5% density: threshold = 1.0 - 1.0 = 0.0 (50% chance)
	var threshold = 1.0 - (tree_density * 20.0)  # More trees: 0.05 -> threshold = 0.0
	var should_place = tree_value > threshold
	return should_place

# Generate a tree at the given position
func _generate_tree(out_buffer: VoxelBuffer, local_x: int, surface_y: int, local_z: int, buffer_size: Vector3i, chunk_origin: Vector3i):
	# Tree parameters
	var tree_height = 4 + randi() % 3  # 4-6 blocks tall
	var canopy_radius = 2
	
	var surface_world_y = chunk_origin.y + surface_y
	print("Generating tree at local pos (", local_x, ", ", surface_y, ", ", local_z, ") with height ", tree_height)
	print("  Chunk origin: ", chunk_origin, ", Surface local y=", surface_y, ", Surface world Y=", surface_world_y)
	print("  Surface block at local y=", surface_y, " should be GRASS (", BlockIDs.BlockID.GRASS, ")")
	var surface_block_check = out_buffer.get_voxel(local_x, surface_y, local_z, VoxelBuffer.CHANNEL_TYPE)
	print("  Actual surface block: ", surface_block_check, " (match: ", surface_block_check == BlockIDs.BlockID.GRASS, ")")
	
	# Generate tree trunk (log blocks)
	# IMPORTANT: surface_y is the LOCAL position of the surface block
	# The trunk should start ABOVE the surface, so we use surface_y + 1
	for i in range(tree_height):
		var tree_y = surface_y + 1 + i
		var tree_world_y = chunk_origin.y + tree_y
		# Make sure we're within the buffer bounds
		if tree_y >= 0 and tree_y < buffer_size.y:
			# Check if there's already a block here (shouldn't be, but let's verify)
			var existing_block = out_buffer.get_voxel(local_x, tree_y, local_z, VoxelBuffer.CHANNEL_TYPE)
			if existing_block != BlockIDs.BlockID.AIR and existing_block != BlockIDs.BlockID.LOG:
				print("  WARNING: Overwriting block ", existing_block, " at local y=", tree_y, " (world Y=", tree_world_y, ") with LOG")
			out_buffer.set_voxel(BlockIDs.BlockID.LOG, local_x, tree_y, local_z, VoxelBuffer.CHANNEL_TYPE)
			print("  Placed log at local y=", tree_y, " (world Y=", tree_world_y, ", block_id=", BlockIDs.BlockID.LOG, ")")
		else:
			print("  SKIPPED log at local y=", tree_y, " (world Y=", tree_world_y, ") - out of bounds (buffer_size.y=", buffer_size.y, ")")
	
	# Generate tree canopy (leaves)
	# NOTE: Leaves may extend into adjacent chunks, but we can only place them in this chunk
	# This is a limitation - trees spanning chunks will have incomplete canopies
	var canopy_top = surface_y + tree_height
	var leaves_placed = 0
	var canopy_world_y = chunk_origin.y + canopy_top
	print("  Generating canopy at local y=", canopy_top, " (world Y=", canopy_world_y, ", surface_y=", surface_y, ", tree_height=", tree_height, ")")
	
	for dx in range(-canopy_radius, canopy_radius + 1):
		for dz in range(-canopy_radius, canopy_radius + 1):
			for dy in range(0, 3):  # 3 layers of leaves
				var canopy_y = canopy_top + dy
				var canopy_world_y_leaf = chunk_origin.y + canopy_y
				var distance = sqrt(dx * dx + dz * dz)
				
				# Create roughly spherical canopy
				if distance <= canopy_radius and (dy == 0 or distance <= canopy_radius - 0.5):
					var leaf_x = local_x + dx
					var leaf_z = local_z + dz
					
					# Check bounds - only place leaves within this chunk
					var in_x_bounds = leaf_x >= 0 and leaf_x < buffer_size.x
					var in_z_bounds = leaf_z >= 0 and leaf_z < buffer_size.z
					var in_y_bounds = canopy_y >= 0 and canopy_y < buffer_size.y
					
					if in_x_bounds and in_z_bounds and in_y_bounds:
						# Don't place leaves where the trunk is
						if not (dx == 0 and dz == 0 and dy == 0):
							out_buffer.set_voxel(BlockIDs.BlockID.LEAVES, leaf_x, canopy_y, leaf_z, VoxelBuffer.CHANNEL_TYPE)
							leaves_placed += 1
					# Note: Leaves outside chunk bounds will be skipped (limitation of per-chunk generation)
	
	print("  Placed ", leaves_placed, " leaves for tree (some may be in adjacent chunks)")
	print("  *** TREE GENERATION COMPLETE at world (", chunk_origin.x + local_x, ", ", surface_world_y, ", ", chunk_origin.z + local_z, ") ***")
