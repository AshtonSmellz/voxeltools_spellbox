extends Node
# WorldSaveSystem singleton - no class_name needed for autoloads

# Manages saving/loading of world data with proper separation of concerns
# VoxelTools handles voxel data through VoxelStream, we handle metadata and dynamic properties

const WORLDS_DIR = "user://worlds/"
const PROPERTIES_SUBDIR = "properties/"
const GLOBAL_SUBDIR = "global/"

var current_world_data: WorldData
var current_world_path: String
var voxel_world_manager: VoxelWorldManager
var save_timer: float = 0.0
var auto_save_interval: float = 300.0  # 5 minutes

signal world_saved(success: bool)
signal world_loaded(success: bool)
signal properties_saved(chunk_pos: Vector3i)
signal properties_loaded(chunk_pos: Vector3i)

func _ready():
	_ensure_world_directories()

func set_voxel_world_manager(manager: VoxelWorldManager):
	voxel_world_manager = manager

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
	world_data.creation_date = int(Time.get_unix_time_from_system())
	world_data.last_played = world_data.creation_date
	
	# Generate world ID and path
	var world_id = _generate_world_id()
	var world_path = WORLDS_DIR + world_id + "/"
	
	# Create directory structure
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(world_path))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(world_path + PROPERTIES_SUBDIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(world_path + GLOBAL_SUBDIR))
	
	# Configure VoxelStream for this world
	if voxel_world_manager and voxel_world_manager.voxel_terrain:
		var stream = VoxelStreamSQLite.new()
		stream.database_path = world_path + "voxels.sqlite"
		voxel_world_manager.voxel_terrain.stream = stream
		
		# Setup comprehensive generation and set seed
		voxel_world_manager.setup_comprehensive_generation()
		voxel_world_manager.set_world_seed(world_data.seed)
		
		print("Configured VoxelStream SQLite at: ", stream.database_path)
	
	# Save initial world data
	var save_path = world_path + "world.tres"
	var error = ResourceSaver.save(world_data, save_path)
	
	if error != OK:
		print("Failed to create world: ", error)
		return null
	
	current_world_data = world_data
	current_world_path = world_path
	
	print("Created world: ", world_name, " at ", world_path)
	
	# Signal game ready for new world too with delay
	call_deferred("_signal_game_ready_delayed")
	
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
	
	# Configure VoxelStream to load from this world
	if voxel_world_manager and voxel_world_manager.voxel_terrain:
		var stream = VoxelStreamSQLite.new()
		stream.database_path = world_path + "voxels.sqlite"
		voxel_world_manager.voxel_terrain.stream = stream
		
		# Setup comprehensive generation and set seed
		voxel_world_manager.setup_comprehensive_generation()
		voxel_world_manager.set_world_seed(world_data.seed)
		
		# Check if database exists - if not, it will generate fresh
		# If it exists, it will load the saved data
		if voxel_world_manager.voxel_terrain.has_method("restart_stream"):
			voxel_world_manager.voxel_terrain.restart_stream()
		elif voxel_world_manager.voxel_terrain.has_method("reload_stream"):
			voxel_world_manager.voxel_terrain.reload_stream()
		print("Loaded voxel database from: ", stream.database_path)
	
	# Load global data (active spells, etc.)
	_load_global_data()
	
	# Load all saved dynamic properties
	_load_all_properties()
	
	print("Loaded world: ", world_data.world_name)
	
	# Signal game ready and set player spawn with delay
	call_deferred("_signal_game_ready_delayed")
	
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
	
	# Save all dynamic properties
	_save_all_properties()
	
	# Save global data (active spells, etc.)
	_save_global_data()
	
	# VoxelStream automatically saves voxel data
	if voxel_world_manager and voxel_world_manager.voxel_terrain:
		voxel_world_manager.voxel_terrain.save_modified_blocks()
	
	print("Saved world: ", current_world_data.world_name)
	world_saved.emit(true)
	return true

func auto_save():
	if current_world_data:
		print("Auto-saving world...")
		save_world()

# Save/Load dynamic properties for modified voxels
func _save_all_properties():
	if not voxel_world_manager or current_world_path.is_empty():
		return
	
	var props_path = current_world_path + PROPERTIES_SUBDIR
	var modified_voxels = voxel_world_manager.modified_voxels
	
	# Group modified voxels by chunk
	var chunks_with_props = {}
	for world_pos in modified_voxels:
		var chunk_pos = _world_to_chunk_pos(world_pos)
		if not chunks_with_props.has(chunk_pos):
			chunks_with_props[chunk_pos] = []
		chunks_with_props[chunk_pos].append(world_pos)
	
	# Save properties for each chunk
	for chunk_pos in chunks_with_props:
		_save_chunk_properties(chunk_pos, chunks_with_props[chunk_pos])
	
	print("Saved properties for ", chunks_with_props.size(), " chunks")

func _save_chunk_properties(chunk_pos: Vector3i, voxel_positions: Array):
	var filename = "props_%d_%d_%d.dat" % [chunk_pos.x, chunk_pos.y, chunk_pos.z]
	var file_path = current_world_path + PROPERTIES_SUBDIR + filename
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		print("Failed to create properties file: ", file_path)
		return
	
	# Write header
	file.store_32(1)  # Version
	file.store_32(voxel_positions.size())  # Number of voxels
	
	# Write each voxel's properties
	for world_pos in voxel_positions:
		var props = voxel_world_manager.modified_voxels[world_pos]
		
		# Store position
		file.store_32(world_pos.x)
		file.store_32(world_pos.y)
		file.store_32(world_pos.z)
		
		# Store packed properties
		file.store_32(props.packed_data)
	
	file.close()
	properties_saved.emit(chunk_pos)

func _load_all_properties():
	if not voxel_world_manager or current_world_path.is_empty():
		return
	
	var props_dir = current_world_path + PROPERTIES_SUBDIR
	var dir = DirAccess.open(props_dir)
	if not dir:
		return
	
	dir.list_dir_begin()
	var filename = dir.get_next()
	var loaded_chunks = 0
	
	while filename != "":
		if filename.begins_with("props_") and filename.ends_with(".dat"):
			_load_chunk_properties_file(props_dir + filename)
			loaded_chunks += 1
		filename = dir.get_next()
	
	print("Loaded properties from ", loaded_chunks, " chunks")

func _load_chunk_properties_file(file_path: String):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("Failed to open properties file: ", file_path)
		return
	
	# Read header
	var version = file.get_32()
	if version != 1:
		print("Unsupported properties version: ", version)
		file.close()
		return
	
	var voxel_count = file.get_32()
	
	# Read each voxel's properties
	for i in range(voxel_count):
		var world_pos = Vector3i(
			file.get_32(),
			file.get_32(),
			file.get_32()
		)
		
		var packed_data = file.get_32()
		var props = DynamicVoxelProperties.new(packed_data)
		
		# Apply to world
		voxel_world_manager.modify_voxel_properties(world_pos, props)
	
	file.close()

func _save_global_data():
	if current_world_path.is_empty():
		return
	
	var global_path = current_world_path + GLOBAL_SUBDIR
	
	# Save active spells
	if voxel_world_manager and voxel_world_manager.spell_system:
		var spells_file = FileAccess.open(global_path + "active_spells.dat", FileAccess.WRITE)
		if spells_file:
			var active_spells = voxel_world_manager.spell_system.active_spells
			spells_file.store_32(active_spells.size())
			
			for spell in active_spells:
				# Store spell data
				spells_file.store_float(spell.time_remaining)
				spells_file.store_32(spell.effect.shape)
				spells_file.store_float(spell.effect.radius)
				spells_file.store_float(spell.effect.duration)
				spells_file.store_float(spell.effect.intensity)
				
				# Store affected positions
				spells_file.store_32(spell.affected_positions.size())
				for pos in spell.affected_positions:
					spells_file.store_32(pos.x)
					spells_file.store_32(pos.y)
					spells_file.store_32(pos.z)
			
			spells_file.close()
	
	# Save world statistics
	if current_world_data:
		var stats_file = FileAccess.open(global_path + "statistics.json", FileAccess.WRITE)
		if stats_file:
			stats_file.store_string(JSON.stringify(current_world_data.statistics, "\t"))
			stats_file.close()

func _load_global_data():
	if current_world_path.is_empty():
		return
	
	var global_path = current_world_path + GLOBAL_SUBDIR
	
	# Load statistics
	var stats_file = FileAccess.open(global_path + "statistics.json", FileAccess.READ)
	if stats_file:
		var json_string = stats_file.get_as_text()
		stats_file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			current_world_data.statistics = json.data
	
	# Note: Active spells are not loaded as they're temporary effects
	# You could implement spell persistence if desired

func _world_to_chunk_pos(world_pos: Vector3i) -> Vector3i:
	var chunk_size = 16  # VoxelTerrain default chunk size
	return Vector3i(
		int(floor(world_pos.x / float(chunk_size))),
		int(floor(world_pos.y / float(chunk_size))),
		int(floor(world_pos.z / float(chunk_size)))
	)

func _generate_world_id() -> String:
	# Generate a unique ID using timestamp and random number
	var timestamp = Time.get_unix_time_from_system()
	var random = randi()
	return "%d_%d" % [timestamp, random]

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

# Force regeneration of current world with new generator changes
func regenerate_current_world():
	print("regenerate_current_world() called")
	if voxel_world_manager:
		print("Found voxel_world_manager, calling clear_world_and_regenerate()")
		voxel_world_manager.clear_world_and_regenerate()
		print("Regenerated current world with updated generators")
	else:
		print("ERROR: No voxel_world_manager found!")

# Load world but force regeneration (useful for testing generator changes)
func load_world_with_regeneration(world_id: String) -> bool:
	var success = load_world(world_id)
	if success and voxel_world_manager:
		voxel_world_manager.clear_world_and_regenerate()
		print("Loaded world and forced regeneration")
	return success

func _delete_directory_recursive(path: String) -> bool:
	var dir = DirAccess.open(path)
	if dir == null:
		return false
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = path + "/" + file_name
		if dir.current_is_dir():
			_delete_directory_recursive(full_path)
		else:
			dir.remove(file_name)
		file_name = dir.get_next()
	
	# Remove the directory itself
	dir.list_dir_end()
	var parent = path.get_base_dir()
	var dir_name = path.get_file()
	var parent_dir = DirAccess.open(parent)
	if parent_dir:
		parent_dir.remove(dir_name)
	
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
		var full_path = path + "/" + file_name
		if dir.current_is_dir():
			total_size += _calculate_directory_size(full_path)
		else:
			var file = FileAccess.open(full_path, FileAccess.READ)
			if file:
				total_size += file.get_length()
				file.close()
		file_name = dir.get_next()
	
	return total_size

# Format file size for display
func format_file_size(bytes: int) -> String:
	if bytes < 1024:
		return "%d B" % bytes
	elif bytes < 1024 * 1024:
		return "%.1f KB" % (bytes / 1024.0)
	elif bytes < 1024 * 1024 * 1024:
		return "%.1f MB" % (bytes / (1024.0 * 1024.0))
	else:
		return "%.2f GB" % (bytes / (1024.0 * 1024.0 * 1024.0))

func _signal_game_ready():
	print("_signal_game_ready called - looking for player...")
	
	# Try multiple ways to find the character controller
	var character_controller = null
	
	# Method 1: Find by name "Player"
	character_controller = get_tree().current_scene.find_child("Player", true, false)
	if character_controller:
		print("Found player by name: ", character_controller.name)
	
	# Method 2: Look for any node with character_controller script
	if not character_controller:
		var all_nodes = get_tree().current_scene.get_children()
		for node in all_nodes:
			if node.get_script() and node.get_script().resource_path.ends_with("character_controller.gd"):
				character_controller = node
				print("Found character controller by script: ", node.name)
				break
	
	# Method 3: Look in main node children
	if not character_controller:
		var main_node = get_tree().current_scene
		print("Current scene: ", main_node.name)
		print("Scene children: ", main_node.get_children().map(func(n): return n.name))
		for child in main_node.get_children():
			for grandchild in child.get_children():
				if grandchild.name.begins_with("Player") or grandchild.has_method("enable_game_ready"):
					character_controller = grandchild
					print("Found player in child nodes: ", grandchild.name)
					break
			if character_controller:
				break
	
	if character_controller:
		print("Character controller found: ", character_controller.name)
		print("Has enable_game_ready method: ", character_controller.has_method("enable_game_ready"))
		print("Has set_spawn_position method: ", character_controller.has_method("set_spawn_position"))
		
		if character_controller.has_method("enable_game_ready"):
			# Set spawn position - for now use a safe default height
			var spawn_pos = Vector3(0, 64, 0)  # Default spawn at y=64
			if character_controller.has_method("set_spawn_position"):
				character_controller.call("set_spawn_position", spawn_pos)
			
			# Enable physics and movement
			character_controller.call("enable_game_ready")
			print("Game ready - enabled character controller at spawn position: ", spawn_pos)
		else:
			print("Character controller missing enable_game_ready method")
	else:
		print("No character controller found anywhere in scene tree")

func _signal_game_ready_delayed():
	print("_signal_game_ready_delayed called...")
	# Try to find the player with a small delay, and retry if not found
	_try_enable_player(0)

func _try_enable_player(attempts: int):
	var max_attempts = 10
	if attempts >= max_attempts:
		print("Failed to find player after ", max_attempts, " attempts")
		return
	
	# Look in all scenes and nodes
	var character_controller = _find_character_controller()
	
	if character_controller:
		print("Found character controller on attempt ", attempts + 1, ": ", character_controller.name)
		
		if character_controller.has_method("enable_game_ready"):
			# Set spawn position
			var spawn_pos = Vector3(0, 64, 0)
			if character_controller.has_method("set_spawn_position"):
				character_controller.call("set_spawn_position", spawn_pos)
			
			# Enable physics and movement
			character_controller.call("enable_game_ready")
			print("SUCCESS: Game ready - enabled character controller at spawn position: ", spawn_pos)
		else:
			print("Character controller missing enable_game_ready method")
	else:
		print("Player not found on attempt ", attempts + 1, ", retrying...")
		# Try again in the next frame
		call_deferred("_try_enable_player", attempts + 1)

func _find_character_controller():
	# Search through all scenes in the tree
	var root = get_tree().root
	return _search_node_recursive(root, "character_controller.gd")

func _search_node_recursive(node: Node, script_name: String):
	# Check if this node has the script we're looking for
	if node.get_script() and node.get_script().resource_path.ends_with(script_name):
		return node
	
	# Check if this node has the methods we need
	if node.has_method("enable_game_ready") and node.has_method("set_spawn_position"):
		return node
	
	# Search children recursively
	for child in node.get_children():
		var result = _search_node_recursive(child, script_name)
		if result:
			return result
	
	return null
