extends Node
class_name WorldSaveSystem

# Manages saving/loading of world data with proper separation of concerns
# VoxelTools handles voxel data, we handle metadata and dynamic properties

const WORLDS_DIR = "user://worlds/"
const CHUNK_SUBDIR = "chunks/"
const GLOBAL_SUBDIR = "global/"

var current_world_data: WorldData
var current_world_path: String
var block_property_manager: BlockPropertyManager
var save_timer: float = 0.0
var auto_save_interval: float = 300.0  # 5 minutes

signal world_saved(success: bool)
signal world_loaded(success: bool)
signal chunk_saved(chunk_pos: Vector3i)
signal chunk_loaded(chunk_pos: Vector3i)

func _ready():
	block_property_manager = get_node("/root/BlockPropertyManager")
	_ensure_world_directories()

func _process(delta):
	if current_world_data:
		current_world_data.playtime += delta
		save_timer += delta
		
		if save_timer >= auto_save_interval:
			auto_save()
			save_timer = 0.0

func _ensure_world_directories():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORLDS_DIR))

# World creation and management
func create_world(world_name: String, world_type: String = "default", seed: int = -1) -> WorldData:
	var world_data = WorldData.new()
	world_data.world_name = world_name
	world_data.world_type = world_type
	world_data.seed = seed if seed != -1 else randi()
	
	# Generate world ID and path
	var world_id = _generate_world_id()
	var world_path = WORLDS_DIR + world_id + "/"
	
	# Create directory structure
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(world_path))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(world_path + CHUNK_SUBDIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(world_path + GLOBAL_SUBDIR))
	
	# Save initial world data
	var save_path = world_path + "world.tres"
	var error = ResourceSaver.save(world_data, save_path)
	
	if error != OK:
		print("Failed to create world: ", error)
		return null
	
	print("Created world: ", world_name, " at ", world_path)
	return world_data

func load_world(world_id: String) -> bool:
	var world_path = WORLDS_DIR + world_id + "/"
	var world_file = world_path + "world.tres"
	
	if not ResourceLoader.exists(world_file):
		print("World file not found: ", world_file)
		return false
	
	var world_data = ResourceLoader.load(world_file) as WorldData
	if world_data == null:
		print("Failed to load world data from: ", world_file)
		return false
	
	current_world_data = world_data
	current_world_path = world_path
	current_world_data.update_last_played()
	save_timer = 0.0
	
	print("Loaded world: ", world_data.world_name)
	world_loaded.emit(true)
	return true

func save_world() -> bool:
	if not current_world_data or current_world_path.is_empty():
		print("No world loaded to save")
		return false
	
	current_world_data.update_last_played()
	
	# Save world metadata
	var world_file = current_world_path + "world.tres"
	var error = ResourceSaver.save(current_world_data, world_file)
	
	if error != OK:
		print("Failed to save world metadata: ", error)
		world_saved.emit(false)
		return false
	
	# Save global magical effects and world state
	_save_global_data()
	
	print("Saved world: ", current_world_data.world_name)
	world_saved.emit(true)
	return true

func auto_save():
	if current_world_data:
		print("Auto-saving world...")
		save_world()

# Chunk-specific save/load operations
func save_chunk(chunk_pos: Vector3i, voxel_data: VoxelBuffer = null) -> bool:
	if current_world_path.is_empty():
		return false
	
	var chunk_filename = "chunk_%d_%d_%d" % [chunk_pos.x, chunk_pos.y, chunk_pos.z]
	var success = true
	
	# Save voxel data using VoxelTools (if provided)
	if voxel_data:
		var voxel_path = current_world_path + CHUNK_SUBDIR + chunk_filename + ".voxel"
		# Note: This would use VoxelTools' save method
		# voxel_data.save_to_file(voxel_path)
		print("Would save voxel data to: ", voxel_path)
	
	# Save dynamic properties (our custom data)
	var props_success = _save_chunk_properties(chunk_pos, chunk_filename)
	
	if success and props_success:
		current_world_data.statistics["chunks_generated"] += 1
		chunk_saved.emit(chunk_pos)
	
	return success and props_success

func load_chunk(chunk_pos: Vector3i) -> Dictionary:
	if current_world_path.is_empty():
		return {}
	
	var chunk_filename = "chunk_%d_%d_%d" % [chunk_pos.x, chunk_pos.y, chunk_pos.z]
	var result = {"voxel_data": null, "properties": {}}
	
	# Load voxel data using VoxelTools
	var voxel_path = current_world_path + CHUNK_SUBDIR + chunk_filename + ".voxel"
	if FileAccess.file_exists(voxel_path):
		# Note: This would use VoxelTools' load method
		# result["voxel_data"] = VoxelBuffer.load_from_file(voxel_path)
		print("Would load voxel data from: ", voxel_path)
	
	# Load dynamic properties
	result["properties"] = _load_chunk_properties(chunk_pos, chunk_filename)
	
	chunk_loaded.emit(chunk_pos)
	return result

func _save_chunk_properties(chunk_pos: Vector3i, filename: String) -> bool:
	# Get dynamic properties for this chunk
	var chunk_props = {}
	var modified_blocks = block_property_manager.get_modified_blocks_in_chunk(chunk_pos)
	
	if modified_blocks.is_empty():
		# No properties to save, delete file if it exists
		var props_path = current_world_path + CHUNK_SUBDIR + filename + ".props"
		if FileAccess.file_exists(props_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(props_path))
		return true
	
	# Collect properties for serialization
	for world_pos in modified_blocks:
		var local_pos = block_property_manager.world_to_local(world_pos)
		var dynamic_props = block_property_manager.get_dynamic_properties(world_pos)
		if dynamic_props:
			chunk_props[local_pos] = dynamic_props.pack_to_bytes()
	
	# Save to compressed binary format
	var props_path = current_world_path + CHUNK_SUBDIR + filename + ".props"
	var file = FileAccess.open(props_path, FileAccess.WRITE)
	if file == null:
		print("Failed to open chunk properties file: ", props_path)
		return false
	
	# Write header
	file.store_32(1)  # Version
	file.store_32(chunk_props.size())  # Number of blocks with properties
	
	# Write properties
	for local_pos in chunk_props:
		file.store_8(local_pos.x)
		file.store_8(local_pos.y)
		file.store_8(local_pos.z)
		var data: PackedByteArray = chunk_props[local_pos]
		file.store_32(data.size())
		file.store_var(data)
	
	file.close()
	return true

func _load_chunk_properties(chunk_pos: Vector3i, filename: String) -> Dictionary:
	var props_path = current_world_path + CHUNK_SUBDIR + filename + ".props"
	if not FileAccess.file_exists(props_path):
		return {}
	
	var file = FileAccess.open(props_path, FileAccess.READ)
	if file == null:
		print("Failed to open chunk properties file: ", props_path)
		return {}
	
	# Read header
	var version = file.get_32()
	if version != 1:
		print("Unsupported chunk properties version: ", version)
		file.close()
		return {}
	
	var block_count = file.get_32()
	var result = {}
	
	# Read properties
	for i in range(block_count):
		var local_pos = Vector3i(file.get_8(), file.get_8(), file.get_8())
		var data_size = file.get_32()
		var data: PackedByteArray = file.get_var()
		
		# Create and populate DynamicBlockProperties
		var props = DynamicBlockProperties.new()
		if props.unpack_from_bytes(data):
			var world_pos = block_property_manager.chunk_and_local_to_world(chunk_pos, local_pos)
			block_property_manager.set_dynamic_properties(world_pos, props)
	
	file.close()
	return result

func _save_global_data():
	if current_world_path.is_empty():
		return
	
	var global_path = current_world_path + GLOBAL_SUBDIR
	
	# Save memory usage statistics
	var stats_file = FileAccess.open(global_path + "memory_stats.json", FileAccess.WRITE)
	if stats_file:
		var memory_stats = block_property_manager.get_memory_usage_summary()
		stats_file.store_string(JSON.stringify(memory_stats, "\t"))
		stats_file.close()

func _generate_world_id() -> String:
	var crypto = Crypto.new()
	return crypto.generate_random_bytes(8).hex_encode()

# World management utilities
func get_available_worlds() -> Array[Dictionary]:
	var worlds: Array[Dictionary] = []
	var dir = DirAccess.open(WORLDS_DIR)
	if dir == null:
		return worlds
	
	dir.list_dir_begin()
	var world_dir = dir.get_next()
	
	while world_dir != "":
		if dir.current_is_dir():
			var world_file = WORLDS_DIR + world_dir + "/world.tres"
			if ResourceLoader.exists(world_file):
				var world_data = ResourceLoader.load(world_file) as WorldData
				if world_data:
					worlds.append({
						"id": world_dir,
						"data": world_data,
						"path": WORLDS_DIR + world_dir + "/"
					})
		world_dir = dir.get_next()
	
	# Sort by last played (most recent first)
	worlds.sort_custom(func(a, b): return a.data.last_played > b.data.last_played)
	return worlds

func delete_world(world_id: String) -> bool:
	var world_path = WORLDS_DIR + world_id + "/"
	return _delete_directory_recursive(world_path)

func _delete_directory_recursive(path: String) -> bool:
	var dir = DirAccess.open(path)
	if dir == null:
		return false
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = path + file_name
		if dir.current_is_dir():
			_delete_directory_recursive(full_path + "/")
		else:
			dir.remove(file_name)
		file_name = dir.get_next()
	
	dir.remove_absolute(ProjectSettings.globalize_path(path))
	return true

func get_world_size_on_disk(world_id: String) -> int:
	var world_path = WORLDS_DIR + world_id + "/"
	return _calculate_directory_size(world_path)

func _calculate_directory_size(path: String) -> int:
	var total_size = 0
	var dir = DirAccess.open(path)
	if dir == null:
		return 0
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = path + file_name
		if dir.current_is_dir():
			total_size += _calculate_directory_size(full_path + "/")
		else:
			var file = FileAccess.open(full_path, FileAccess.READ)
			if file:
				total_size += file.get_length()
				file.close()
		file_name = dir.get_next()
	
	return total_size
