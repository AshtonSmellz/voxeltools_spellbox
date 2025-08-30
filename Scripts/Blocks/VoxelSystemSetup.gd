@tool
extends EditorScript

# This is a helper script to set up the voxel system correctly
# Run this in the Script Editor: File -> Run

func _run():
	print("=== Voxel System Setup Helper ===")
	print("Setting up scene structure...")
	
	var root = get_scene()
	if not root:
		print("ERROR: No scene open. Please open a scene first.")
		return
	
	# Check for required plugin
	if not EditorInterface.is_plugin_enabled("voxel"):
		print("ERROR: Voxel Tools plugin is not enabled!")
		print("Please go to Project Settings -> Plugins and enable 'Voxel'")
		return
	
	# Create VoxelTerrain if it doesn't exist
	var voxel_terrain = root.get_node_or_null("VoxelTerrain")
	if not voxel_terrain:
		print("Creating VoxelTerrain node...")
		voxel_terrain = VoxelTerrain.new()
		voxel_terrain.name = "VoxelTerrain"
		root.add_child(voxel_terrain)
		voxel_terrain.owner = root
	
	# Configure VoxelTerrain
	print("Configuring VoxelTerrain...")
	
	# Set up mesher
	if not voxel_terrain.mesher:
		var mesher = VoxelMesherBlocky.new()
		voxel_terrain.mesher = mesher
		print("  - Added VoxelMesherBlocky")
	
	# Set up generator (optional)
	if not voxel_terrain.generator:
		var generator = VoxelGeneratorFlat.new()
		generator.channel = VoxelBuffer.CHANNEL_TYPE
		generator.voxel_type = 1  # Stone
		generator.height = 0
		voxel_terrain.generator = generator
		print("  - Added VoxelGeneratorFlat")
	
	# Set up stream for saving (optional)
	if not voxel_terrain.stream:
		var stream = VoxelStreamSQLite.new()
		stream.database_path = "user://voxel_world.sqlite"
		voxel_terrain.stream = stream
		print("  - Added VoxelStreamSQLite")
	
	# Configure terrain settings
	voxel_terrain.view_distance = 256
	voxel_terrain.collision_layer = 1
	voxel_terrain.material_override = preload("res://materials/voxel_material.tres") if ResourceLoader.exists("res://materials/voxel_material.tres") else null
	
	# Create VoxelWorldManager if it doesn't exist
	var world_manager = root.get_node_or_null("VoxelWorldManager")
	if not world_manager:
		print("Creating VoxelWorldManager node...")
		world_manager = Node.new()
		world_manager.name = "VoxelWorldManager"
		world_manager.set_script(preload("res://VoxelWorldManager.gd"))  # Adjust path
		root.add_child(world_manager)
		world_manager.owner = root
	
	# Set the terrain path in world manager
	world_manager.set("voxel_terrain_path", NodePath("../VoxelTerrain"))
	
	# Create Player if it doesn't exist
	var player = root.get_node_or_null("Player")
	if not player:
		print("Creating Player node...")
		player = CharacterBody3D.new()
		player.name = "Player"
		root.add_child(player)
		player.owner = root
		
		# Add collision shape
		var collision = CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		var shape = CapsuleShape3D.new()
		shape.radius = 0.5
		shape.height = 1.8
		collision.shape = shape
		player.add_child(collision)
		collision.owner = root
		
		# Add camera
		var camera = Camera3D.new()
		camera.name = "Camera3D"
		camera.position = Vector3(0, 0.6, 0)
		camera.fov = 75
		player.add_child(camera)
		camera.owner = root
		
		# Set player position
		player.position = Vector3(0, 10, 0)
	
	# Create DirectionalLight3D for better visibility
	var light = root.get_node_or_null("DirectionalLight3D")
	if not light:
		print("Creating DirectionalLight3D...")
		light = DirectionalLight3D.new()
		light.name = "DirectionalLight3D"
		light.rotation_degrees = Vector3(-45, -45, 0)
		light.light_energy = 1.0
		light.shadow_enabled = true
		root.add_child(light)
		light.owner = root
	
	print("\n=== Setup Complete! ===")
	print("\nScene structure:")
	print("- " + root.name)
	print("  - VoxelTerrain (handles voxel rendering)")
	print("  - VoxelWorldManager (handles properties and spells)")
	print("  - Player (character controller)")
	print("  - DirectionalLight3D (lighting)")
	
	print("\nNext steps:")
	print("1. Save the scene")
	print("2. Make sure the script files are in the correct paths:")
	print("   - res://DynamicVoxelProperties.gd")
	print("   - res://VoxelWorldManager.gd")
	print("   - res://MaterialDatabase.gd")
	print("   - res://SpellSystem.gd")
	print("   - res://PlayerSpellcaster.gd")
	print("3. Add PlayerSpellcaster.gd to the Player node")
	print("4. Run the scene!")
	
	print("\nTroubleshooting:")
	print("- If you get errors about missing types, make sure Voxel Tools is installed")
	print("- If materials look wrong, create a StandardMaterial3D at res://materials/voxel_material.tres")
	print("- Check that all script files have 'class_name' defined at the top")
