class_name VoxelWorldManager
extends Node

# This manages the voxel world using Voxel Tools library
# Attach this to a node that has VoxelTerrain as a child

@export var voxel_terrain_path: NodePath = "VoxelTerrain"
@export var enable_physics_simulation: bool = true
@export var enable_temperature_propagation: bool = true

var voxel_terrain: VoxelTerrain
var voxel_tool  # VoxelTool type (can't be exported)
var material_database  # MaterialDatabase instance
var spell_system: SpellSystem
var modified_voxels: Dictionary = {}  # Vector3i -> DynamicVoxelProperties
var voxel_library: VoxelBlockyLibrary

signal voxel_modified(world_pos: Vector3i)
signal voxel_destroyed(world_pos: Vector3i, material_id: int)

func _ready():
	print("VoxelWorldManager _ready() called")
	print("voxel_terrain_path: ", voxel_terrain_path)
	print("Parent node: ", get_parent())
	print("Parent children: ", get_parent().get_children().map(func(n): return n.name + " (" + n.get_class() + ")"))
	
	# Get VoxelTerrain node
	if voxel_terrain_path:
		voxel_terrain = get_node(voxel_terrain_path)
		print("Found via path: ", voxel_terrain)
	
	if not voxel_terrain:
		# Try to find it as sibling
		voxel_terrain = get_parent().get_node_or_null("VoxelTerrain")
		print("Found as sibling: ", voxel_terrain)
	
	if not voxel_terrain:
		# Search more broadly
		print("Searching for VoxelTerrain in scene tree...")
		voxel_terrain = _find_voxel_terrain_recursive(get_tree().current_scene)
		print("Found via search: ", voxel_terrain)
	
	if not voxel_terrain:
		push_error("VoxelWorldManager: No VoxelTerrain found! Please set the voxel_terrain_path or ensure VoxelTerrain exists as a sibling node.")
		return
	
	# Initialize voxel tool for terrain manipulation
	voxel_tool = voxel_terrain.get_voxel_tool()
	if voxel_tool:
		voxel_tool.channel = VoxelBuffer.CHANNEL_TYPE
		
		# Setup the voxel library
		_setup_voxel_library()
	
	# Initialize systems
	material_database = MaterialDatabase.new()
	spell_system = SpellSystem.new()
	spell_system.name = "SpellSystem"
	add_child(spell_system)
	
	# Connect voxel destruction signal to item drop creation
	voxel_destroyed.connect(_on_voxel_destroyed)

func _setup_voxel_library():
	# Create or get the voxel library
	var mesher = voxel_terrain.mesher
	
	# Create mesher if it doesn't exist
	if not mesher:
		mesher = VoxelMesherBlocky.new()
		voxel_terrain.mesher = mesher
	
	# Only proceed if we have a blocky mesher
	if mesher is VoxelMesherBlocky:
		voxel_library = mesher.library
		if not voxel_library:
			voxel_library = VoxelBlockyLibrary.new()
			mesher.library = voxel_library
		
		# Setup voxel types based on material database
		_setup_voxel_types()
	else:
		push_warning("VoxelWorldManager: Mesher is not VoxelMesherBlocky. Some features may not work correctly.")

func _setup_voxel_types():
	# Helper function to get model count from library
	var get_library_model_count = func(lib: VoxelBlockyLibrary) -> int:
		if not lib:
			return 0
		# VoxelBlockyLibrary has a 'models' property that's an Array
		# Access it directly - it should always exist
		return lib.models.size() if lib.models else 0
	
	# Check if library from mesher is valid
	var mesher = voxel_terrain.mesher as VoxelMesherBlocky
	if mesher and mesher.library:
		var existing_lib = mesher.library as VoxelBlockyLibrary
		var model_count = get_library_model_count.call(existing_lib)
		if model_count >= 4:
			# Use existing library from mesher
			voxel_library = existing_lib
			print("Using existing voxel library from mesher with ", model_count, " models")
			return
	
	# Try to load existing library from file
	var library_path = "res://materials/voxel_library.tres"
	if ResourceLoader.exists(library_path):
		var loaded_library = load(library_path) as VoxelBlockyLibrary
		var model_count = get_library_model_count.call(loaded_library)
		if model_count >= 4:
			# Library exists and has enough models - use it
			voxel_library = loaded_library
			if mesher:
				mesher.library = voxel_library
			print("Loaded existing voxel library with ", model_count, " models")
			return
		else:
			# Library exists but doesn't have enough models - recreate it
			print("Existing library has only ", model_count, " models, creating new one")
	
	# Create a basic library if none exists or existing one is insufficient
	_create_basic_voxel_library()
	if mesher:
		mesher.library = voxel_library
	var final_count = get_library_model_count.call(voxel_library)
	print("Created basic voxel library with ", final_count, " models in BlockIDs order")

func _create_basic_voxel_library():
	# This creates a simple colored voxel library without textures
	# IMPORTANT: Models must be added in BlockIDs order!
	# For proper textured voxels, use VoxelAtlasSetup.gd
	
	voxel_library.atlas_size = Vector2i(16, 16)
	
	# Create a basic material
	var basic_material = StandardMaterial3D.new()
	basic_material.vertex_color_use_as_albedo = true
	basic_material.roughness = 0.8
	
	# IMPORTANT: Add models in BlockIDs order
	# ID 0: Air (empty)
	var air_voxel = VoxelBlockyModelEmpty.new()
	voxel_library.add_model(air_voxel)  # BlockIDs.BlockID.AIR
	
	# ID 1: Dirt
	var dirt_model = VoxelBlockyModelCube.new()
	dirt_model.resource_name = "Dirt"
	var dirt_mat = StandardMaterial3D.new()
	dirt_mat.albedo_color = Color(0.4, 0.3, 0.2)  # Brown dirt color
	dirt_mat.roughness = 0.8
	dirt_model.set_material_override(0, dirt_mat)
	voxel_library.add_model(dirt_model)  # BlockIDs.BlockID.DIRT
	
	# ID 2: Grass
	var grass_model = VoxelBlockyModelCube.new()
	grass_model.resource_name = "Grass"
	var grass_mat = StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.2, 0.7, 0.2)  # Green grass color
	grass_mat.roughness = 0.8
	grass_model.set_material_override(0, grass_mat)
	voxel_library.add_model(grass_model)  # BlockIDs.BlockID.GRASS
	
	# ID 3: Sand
	var sand_model = VoxelBlockyModelCube.new()
	sand_model.resource_name = "Sand"
	var sand_mat = StandardMaterial3D.new()
	sand_mat.albedo_color = Color(0.9, 0.8, 0.6)  # Beige sand color
	sand_mat.roughness = 0.8
	sand_model.set_material_override(0, sand_mat)
	voxel_library.add_model(sand_model)  # BlockIDs.BlockID.SAND
	
	# ID 4: Stone
	var stone_model = VoxelBlockyModelCube.new()
	stone_model.resource_name = "Stone"
	var stone_mat = StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.5, 0.5, 0.5)  # Gray stone color
	stone_mat.roughness = 0.8
	stone_model.set_material_override(0, stone_mat)
	voxel_library.add_model(stone_model)  # BlockIDs.BlockID.STONE
	
	# ID 5: Wood
	var wood_model = VoxelBlockyModelCube.new()
	wood_model.resource_name = "Wood"
	var wood_mat = StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.55, 0.27, 0.07)  # Brown wood color
	wood_mat.roughness = 0.8
	wood_model.set_material_override(0, wood_mat)
	voxel_library.add_model(wood_model)  # BlockIDs.BlockID.WOOD
	
	# ID 6: Iron
	var iron_model = VoxelBlockyModelCube.new()
	iron_model.resource_name = "Iron"
	var iron_mat = StandardMaterial3D.new()
	iron_mat.albedo_color = Color(0.7, 0.7, 0.7)  # Silver iron color
	iron_mat.roughness = 0.3
	iron_mat.metallic = 0.8
	iron_model.set_material_override(0, iron_mat)
	voxel_library.add_model(iron_model)  # BlockIDs.BlockID.IRON
	
	# ID 7: Glass
	var glass_model = VoxelBlockyModelCube.new()
	glass_model.resource_name = "Glass"
	glass_model.transparent = true
	glass_model.transparency_index = 1
	var glass_mat = StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.8, 0.9, 1.0, 0.3)  # Light blue transparent
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.roughness = 0.1
	glass_model.set_material_override(0, glass_mat)
	voxel_library.add_model(glass_model)  # BlockIDs.BlockID.GLASS
	
	# ID 8: Water
	var water_model = VoxelBlockyModelCube.new()
	water_model.resource_name = "Water"
	water_model.transparent = true
	water_model.transparency_index = 2
	var water_mat = StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.2, 0.4, 0.8, 0.7)  # Blue transparent
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.roughness = 0.1
	water_model.set_material_override(0, water_mat)
	voxel_library.add_model(water_model)  # BlockIDs.BlockID.WATER
	
	# ID 9: Lava
	var lava_model = VoxelBlockyModelCube.new()
	lava_model.resource_name = "Lava"
	var lava_mat = StandardMaterial3D.new()
	lava_mat.albedo_color = Color(1.0, 0.3, 0.0)  # Orange-red lava color
	lava_mat.roughness = 0.8
	lava_mat.emission_enabled = true
	lava_mat.emission = Color(1.0, 0.3, 0.0) * 0.5  # Glowing effect
	lava_model.set_material_override(0, lava_mat)
	voxel_library.add_model(lava_model)  # BlockIDs.BlockID.LAVA
	
	# Bake the library for optimization
	voxel_library.bake()
	var model_count = voxel_library.models.size() if voxel_library.models else 0
	print("Created basic voxel library with ", model_count, " models in BlockIDs order")

func _process(delta):
	# Update active spells
	if spell_system:
		spell_system.update_spells(delta, self)
		spell_system.process_modifications(self)
	
	# Update physics simulation
	if enable_physics_simulation:
		_update_physics_simulation(delta)
	
	# Update temperature propagation
	if enable_temperature_propagation:
		_update_temperature_propagation(delta)

# Get voxel at world position (both ID and properties)
func get_voxel_at_pos(world_pos: Vector3i) -> Dictionary:
	voxel_tool.pos = world_pos
	var voxel_id = voxel_tool.get_voxel()
	
	# Get metadata (properties) if exists
	var metadata = voxel_tool.get_voxel_metadata()
	var props = DynamicVoxelProperties.from_metadata(metadata)
	
	# If no metadata but voxel exists, use default properties
	if metadata == null and voxel_id > 0:
		var material = material_database.get_material(voxel_id)
		if material:
			props = material.default_dynamic_properties.duplicate_and_modify()
	
	return {
		"id": voxel_id,
		"properties": props,
		"position": world_pos
	}

# Set voxel at world position
func set_voxel_at_pos(world_pos: Vector3i, material_id: int, props: DynamicVoxelProperties = null):
	voxel_tool.pos = world_pos
	voxel_tool.set_voxel(material_id)
	
	# Store properties as metadata if provided
	if props:
		voxel_tool.set_voxel_metadata(props.to_metadata())
		modified_voxels[world_pos] = props
	elif modified_voxels.has(world_pos):
		modified_voxels.erase(world_pos)
		voxel_tool.set_voxel_metadata(null)
	
	voxel_modified.emit(world_pos)

# Modify voxel properties without changing the block type
func modify_voxel_properties(world_pos: Vector3i, props: DynamicVoxelProperties):
	voxel_tool.pos = world_pos
	var voxel_id = voxel_tool.get_voxel()
	
	if voxel_id > 0:  # Only modify non-air blocks
		voxel_tool.set_voxel_metadata(props.to_metadata())
		modified_voxels[world_pos] = props
		voxel_modified.emit(world_pos)

# Cast a spell at a world position
func cast_spell(spell_effect: SpellSystem.SpellEffect, position: Vector3):
	spell_system.cast_spell(spell_effect, position)

# Get voxels in a box area
func get_voxels_in_area(min_pos: Vector3i, max_pos: Vector3i) -> Array:
	var voxels = []
	for x in range(min_pos.x, max_pos.x + 1):
		for y in range(min_pos.y, max_pos.y + 1):
			for z in range(min_pos.z, max_pos.z + 1):
				var pos = Vector3i(x, y, z)
				var voxel = get_voxel_at_pos(pos)
				if voxel.id > 0:  # Skip air
					voxels.append(voxel)
	return voxels

# Apply modifications in batch (more efficient)
func apply_batch_modifications(modifications: Array):
	voxel_tool.channel = VoxelBuffer.CHANNEL_TYPE
	
	for mod in modifications:
		voxel_tool.pos = mod.position
		
		if mod.has("id"):
			voxel_tool.set_voxel(mod.id)
		
		if mod.has("properties"):
			voxel_tool.set_voxel_metadata(mod.properties.to_metadata())
			modified_voxels[mod.position] = mod.properties

# Update physics simulation
func _update_physics_simulation(delta: float):
	# Process modified voxels for state changes
	var to_process = modified_voxels.keys()
	
	for world_pos in to_process:
		var voxel = get_voxel_at_pos(world_pos)
		if voxel.id == 0:
			continue
		
		var material = material_database.get_material(voxel.id)
		if not material:
			continue
		
		var state_change = material_database.check_state_change(
			voxel.properties, material
		)
		
		# Handle state changes
		if state_change.should_destroy:
			set_voxel_at_pos(world_pos, 0)  # Destroy voxel
			voxel_destroyed.emit(world_pos, voxel.id)
			
		elif state_change.should_melt:
			_handle_melting(world_pos, voxel, material)
			
		elif state_change.should_freeze:
			_handle_freezing(world_pos, voxel, material)
		
		if state_change.should_become_conductive:
			var new_props = voxel.properties.duplicate_and_modify()
			new_props.set_conductive(true)
			modify_voxel_properties(world_pos, new_props)

# Handle melting
func _handle_melting(world_pos: Vector3i, voxel: Dictionary, material: StaticMaterialProperties):
	# Convert to liquid variant
	match voxel.id:
		BlockIDs.BlockID.DIRT:  # Dirt -> Destroy (organic matter burns)
			set_voxel_at_pos(world_pos, BlockIDs.BlockID.AIR)
			voxel_destroyed.emit(world_pos, voxel.id)
		BlockIDs.BlockID.GRASS:  # Grass -> Destroy (burns)
			set_voxel_at_pos(world_pos, BlockIDs.BlockID.AIR)
			voxel_destroyed.emit(world_pos, voxel.id)
		BlockIDs.BlockID.SAND:  # Sand -> Glass (melted sand becomes glass)
			set_voxel_at_pos(world_pos, BlockIDs.BlockID.GLASS, voxel.properties)
		BlockIDs.BlockID.STONE:  # Stone -> Lava
			set_voxel_at_pos(world_pos, BlockIDs.BlockID.LAVA, voxel.properties)
		BlockIDs.BlockID.WOOD:  # Wood -> Destroy (burns)
			set_voxel_at_pos(world_pos, BlockIDs.BlockID.AIR)
			voxel_destroyed.emit(world_pos, voxel.id)
		BlockIDs.BlockID.IRON:  # Iron -> Lava
			set_voxel_at_pos(world_pos, BlockIDs.BlockID.LAVA, voxel.properties)
		BlockIDs.BlockID.GLASS:  # Glass -> Lava
			set_voxel_at_pos(world_pos, BlockIDs.BlockID.LAVA, voxel.properties)
		_:
			# Default: destroy
			set_voxel_at_pos(world_pos, BlockIDs.BlockID.AIR)

# Handle freezing
func _handle_freezing(world_pos: Vector3i, voxel: Dictionary, material: StaticMaterialProperties):
	# Convert to solid variant
	match voxel.id:
		BlockIDs.BlockID.WATER:  # Water -> Ice (we'll make it stone for now)
			set_voxel_at_pos(world_pos, BlockIDs.BlockID.STONE, voxel.properties)
		BlockIDs.BlockID.LAVA:  # Lava -> Stone
			set_voxel_at_pos(world_pos, BlockIDs.BlockID.STONE, voxel.properties)

# Update temperature propagation
func _update_temperature_propagation(delta: float):
	if modified_voxels.is_empty():
		return
	
	var new_temperatures = {}
	var positions_to_check = modified_voxels.keys()
	
	# Simple heat diffusion
	for pos in positions_to_check:
		var voxel = get_voxel_at_pos(pos)
		if voxel.id == 0:
			continue
		
		var material = material_database.get_material(voxel.id)
		if not material:
			continue
		
		var total_heat_transfer = 0.0
		var neighbor_count = 0
		
		# Check 6 neighbors (not diagonals for performance)
		var neighbors = [
			Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
			Vector3i(0, 1, 0), Vector3i(0, -1, 0),
			Vector3i(0, 0, 1), Vector3i(0, 0, -1)
		]
		
		for offset in neighbors:
			var neighbor_pos = pos + offset
			var neighbor = get_voxel_at_pos(neighbor_pos)
			
			if neighbor.id > 0:
				var neighbor_material = material_database.get_material(neighbor.id)
				if not neighbor_material:
					continue
				
				# Calculate temperature difference
				var temp_diff = neighbor.properties.get_temperature_kelvin() - voxel.properties.get_temperature_kelvin()
				
				# Use average thermal conductivity between materials
				var avg_conductivity = (material.thermal_conductivity + neighbor_material.thermal_conductivity) / 2.0
				
				# Account for heat capacity - higher heat capacity means slower temperature change
				var heat_capacity_mult = voxel.properties.get_heat_capacity_multiplier()
				var base_heat_capacity = material.base_heat_capacity
				var effective_heat_capacity = base_heat_capacity * heat_capacity_mult
				
				# Heat transfer formula: Q = k * A * ΔT / (C * m) where C is heat capacity
				# Simplified: ΔT = (k * ΔT * dt) / C
				var heat_transfer = temp_diff * avg_conductivity * delta / max(effective_heat_capacity, 0.1)
				total_heat_transfer += heat_transfer
				neighbor_count += 1
		
		if neighbor_count > 0:
			var avg_transfer = total_heat_transfer / neighbor_count
			new_temperatures[pos] = voxel.properties.get_temperature_kelvin() + avg_transfer
	
	# Apply new temperatures
	for pos in new_temperatures:
		var voxel = get_voxel_at_pos(pos)
		var new_props = voxel.properties.duplicate_and_modify()
		
		# Find closest temperature index
		var new_temp = clamp(new_temperatures[pos], 0, 3000)
		var closest_index = 0
		var min_diff = abs(new_temp - DynamicVoxelProperties.TEMPERATURE_VALUES[0])
		
		for i in range(1, DynamicVoxelProperties.TEMPERATURE_VALUES.size()):
			var diff = abs(new_temp - DynamicVoxelProperties.TEMPERATURE_VALUES[i])
			if diff < min_diff:
				min_diff = diff
				closest_index = i
		
		new_props.set_temperature_index(closest_index)
		modify_voxel_properties(pos, new_props)

# Raycast using VoxelTool
func raycast_voxel(from: Vector3, direction: Vector3, max_distance: float = 100.0) -> Dictionary:
	var result = voxel_tool.raycast(from, direction, max_distance)
	
	if result:
		var voxel = get_voxel_at_pos(result.position)
		return {
			"hit": true,
			"position": result.position,
			"previous_position": result.previous_position,
			"voxel": voxel,
			"distance": result.distance
		}
	
	return {"hit": false}

# Edit voxels in a sphere
func edit_sphere(center: Vector3, radius: float, material_id: int, props: DynamicVoxelProperties = null):
	voxel_tool.channel = VoxelBuffer.CHANNEL_TYPE
	voxel_tool.mode = VoxelTool.MODE_SET
	voxel_tool.value = material_id
	voxel_tool.do_sphere(center, radius)
	
	# Apply properties to affected voxels if provided
	if props:
		var min_pos = Vector3i(center - Vector3.ONE * radius)
		var max_pos = Vector3i(center + Vector3.ONE * radius)
		
		for x in range(min_pos.x, max_pos.x + 1):
			for y in range(min_pos.y, max_pos.y + 1):
				for z in range(min_pos.z, max_pos.z + 1):
					var pos = Vector3i(x, y, z)
					if pos.distance_to(center) <= radius:
						voxel_tool.pos = pos
						if voxel_tool.get_voxel() == material_id:
							voxel_tool.set_voxel_metadata(props.to_metadata())

# Edit voxels in a box
func edit_box(min_pos: Vector3i, max_pos: Vector3i, material_id: int, props: DynamicVoxelProperties = null):
	voxel_tool.channel = VoxelBuffer.CHANNEL_TYPE
	voxel_tool.mode = VoxelTool.MODE_SET
	voxel_tool.value = material_id
	voxel_tool.do_box(min_pos, max_pos)
	
	# Apply properties if provided
	if props:
		for x in range(min_pos.x, max_pos.x + 1):
			for y in range(min_pos.y, max_pos.y + 1):
				for z in range(min_pos.z, max_pos.z + 1):
					var pos = Vector3i(x, y, z)
					voxel_tool.pos = pos
					voxel_tool.set_voxel_metadata(props.to_metadata())

func set_world_seed(seed: int):
	if voxel_terrain and voxel_terrain.generator:
		if voxel_terrain.generator is VoxelGeneratorNoise:
			var noise_gen = voxel_terrain.generator as VoxelGeneratorNoise
			if noise_gen.noise:
				noise_gen.noise.seed = seed
				print("Set world seed to: ", seed)
		elif voxel_terrain.generator is VoxelGeneratorFlat:
			print("Flat generator doesn't use seed")
		elif voxel_terrain.generator is SimpleWorldGenerator:
			var simple_gen = voxel_terrain.generator as SimpleWorldGenerator
			simple_gen.set_seed(seed)
			print("Set simple world generator seed to: ", seed)
		else:
			print("Unknown generator type, cannot set seed")
	else:
		print("No voxel terrain or generator found to set seed")

func setup_comprehensive_generation():
	if not voxel_terrain:
		print("ERROR: No voxel terrain to setup generation for")
		return
	
	# Create simple world generator that uses grass, dirt, and sand
	var simple_generator = SimpleWorldGenerator.new()
	voxel_terrain.generator = simple_generator
	
	print("=== Set up SimpleWorldGenerator ===")
	print("Generator type: ", simple_generator.get_script().get_path())
	print("Generator will create:")
	print("  - Grass blocks on surface (non-desert biomes)")
	print("  - Dirt blocks underground")
	print("  - Sand blocks in desert biomes and ocean floors")
	print("Current terrain generator: ", voxel_terrain.generator)
	print("Generator class: ", voxel_terrain.generator.get_class() if voxel_terrain.generator else "null")
	
	# Verify the generator is actually set
	if voxel_terrain.generator != simple_generator:
		print("ERROR: Generator was not set correctly!")
	else:
		print("Generator successfully assigned to voxel_terrain")
	
	# Ensure library has the right blocks
	var mesher = voxel_terrain.mesher as VoxelMesherBlocky
	if mesher:
		# Get library from mesher if we don't have one
		if not voxel_library:
			voxel_library = mesher.library
		
		# Ensure mesher has the library
		if not mesher.library:
			if not voxel_library:
				_create_basic_voxel_library()
			mesher.library = voxel_library
			print("Assigned voxel library to mesher")
	
	if voxel_library:
		var model_count = voxel_library.models.size() if voxel_library.models else 0
		
		if model_count < 4:
			print("WARNING: Voxel library only has ", model_count, " models. Need at least 4 (Air, Dirt, Grass, Sand)")
			print("Recreating library with correct BlockIDs order...")
			_create_basic_voxel_library()
			if mesher:
				mesher.library = voxel_library
			model_count = voxel_library.models.size() if voxel_library.models else 0
			print("Recreated library with ", model_count, " models")
		else:
			print("Voxel library has ", model_count, " models - should be sufficient")
			print("Library models should be in order: Air(0), Dirt(1), Grass(2), Sand(3), Stone(4), Wood(5), Iron(6), Glass(7), Water(8), Lava(9)")
	else:
		print("ERROR: No voxel library! Creating basic library...")
		_create_basic_voxel_library()
		if mesher:
			mesher.library = voxel_library
	
	# Note: Removed structure generation for simplicity

func _find_surface_height(x: int, z: int) -> int:
	# Scan downward to find surface
	for y in range(128, 0, -1):
		voxel_tool.pos = Vector3i(x, y, z)
		var voxel_id = voxel_tool.get_voxel()
		if voxel_id != 0:  # Found solid block
			return y
	return 64  # Default to sea level

func regenerate_with_seed(seed: int):
	set_world_seed(seed)
	if voxel_terrain:
		# Clear any existing voxel data
		if voxel_terrain.has_method("clear_cached_blocks"):
			voxel_terrain.clear_cached_blocks()
		elif voxel_terrain.has_method("clear_blocks"):
			voxel_terrain.clear_blocks()
		
		# Clear the database file to force full regeneration
		if voxel_terrain.stream and voxel_terrain.stream is VoxelStreamSQLite:
			var sqlite_stream = voxel_terrain.stream as VoxelStreamSQLite
			var db_path = sqlite_stream.database_path
			print("Clearing voxel database: ", db_path)
			
			# Close the current stream
			voxel_terrain.stream = null
			
			# Delete the database file if it exists
			if FileAccess.file_exists(db_path):
				DirAccess.remove_absolute(db_path)
			
			# Create a new stream
			var new_stream = VoxelStreamSQLite.new()
			new_stream.database_path = db_path
			voxel_terrain.stream = new_stream
		
		# Restart the stream to use new seed
		if voxel_terrain.has_method("restart_stream"):
			voxel_terrain.restart_stream()
		elif voxel_terrain.has_method("reload_stream"):
			voxel_terrain.reload_stream()
		else:
			# Try to force reload by setting stream again
			var current_stream = voxel_terrain.stream
			voxel_terrain.stream = null
			voxel_terrain.stream = current_stream
		
		# Force regeneration around player if possible
		if voxel_terrain.has_method("pregenerate_region"):
			voxel_terrain.pregenerate_region(Vector3.ZERO, 4)
		
		print("Regenerated world with seed: ", seed)

func _find_voxel_terrain_recursive(node: Node) -> Node:
	# Check if this node is a VoxelTerrain
	if node.get_class() == "VoxelTerrain" or node.get_class() == "VoxelLodTerrain":
		return node
	
	# Search children recursively
	for child in node.get_children():
		var result = _find_voxel_terrain_recursive(child)
		if result:
			return result
	
	return null

# Handle voxel destruction by creating item drops
func _on_voxel_destroyed(world_pos: Vector3i, material_id: int):
	_create_item_drop_for_voxel(material_id, world_pos)

func _create_item_drop_for_voxel(voxel_id: int, world_pos: Vector3i):
	# Map voxel IDs to item IDs based on MaterialDatabase
	var item_id = _voxel_id_to_item_id(voxel_id)
	if item_id.is_empty():
		return
	
	# Find inventory manager to get item data
	var inventory_manager = get_tree().current_scene.find_child("InventoryManager", true, false) as InventoryManager
	if not inventory_manager:
		print("Warning: No InventoryManager found for item drops")
		return
	
	var item = inventory_manager.get_item_by_id(item_id)
	if not item:
		print("Warning: Unknown item ID for voxel: ", item_id)
		return
	
	# Create item stack
	var item_stack = ItemStack.new(item, 1)
	
	# Convert voxel position to world position (center of voxel)
	var world_position = Vector3(world_pos) + Vector3(0.5, 0.5, 0.5)
	
	# Create and spawn item drop
	var item_drop = ItemDrop.create_item_drop(item_stack, world_position)
	get_tree().current_scene.add_child(item_drop)
	
	# Add some random velocity to make it look natural
	var random_velocity = Vector3(
		randf_range(-2, 2),
		randf_range(2, 4),
		randf_range(-2, 2)
	)
	item_drop.linear_velocity = random_velocity
	
	print("Created item drop: ", item_id, " at ", world_position)

func _voxel_id_to_item_id(voxel_id: int) -> String:
	# Use unified BlockIDs system
	return BlockIDs.block_id_to_item_id(voxel_id)

func clear_world_and_regenerate():
	"""Clear all voxel data and regenerate from scratch with current generator"""
	print("clear_world_and_regenerate() called")
	if voxel_terrain:
		print("Found voxel_terrain: ", voxel_terrain)
		print("Current generator: ", voxel_terrain.generator)
		
		# Force setup of our SimpleWorldGenerator
		setup_comprehensive_generation()
		print("Reset generator to: ", voxel_terrain.generator)
		
		# Save any pending modifications first
		voxel_terrain.save_modified_blocks()
		print("Saved pending modifications")
		
		# Clear the database if it exists
		if voxel_terrain.stream and voxel_terrain.stream is VoxelStreamSQLite:
			var sqlite_stream = voxel_terrain.stream as VoxelStreamSQLite
			var db_path = sqlite_stream.database_path
			print("Clearing world voxel database: ", db_path)
			
			# Delete database file to force regeneration
			if FileAccess.file_exists(db_path):
				var success = DirAccess.remove_absolute(db_path)
				print("Database file deletion result: ", success)
			
			# Create fresh stream
			var new_stream = VoxelStreamSQLite.new()
			new_stream.database_path = db_path
			voxel_terrain.stream = new_stream
			print("Created fresh SQLite stream")
		else:
			# Create a new SQLite stream for saving
			var temp_dir = "user://temp_world/"
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temp_dir))
			var new_stream = VoxelStreamSQLite.new()
			new_stream.database_path = temp_dir + "voxels.sqlite"
			voxel_terrain.stream = new_stream
			print("Created new SQLite stream: ", new_stream.database_path)
		
		# Force terrain to reload by moving player or triggering chunk reload
		var player_pos = Vector3.ZERO
		if voxel_terrain.has_method("pregenerate_region"):
			voxel_terrain.pregenerate_region(player_pos, 2)
			print("Forced pregeneration around ", player_pos)
		
		print("Cleared world and forced regeneration")
	else:
		print("ERROR: No voxel_terrain found!")
