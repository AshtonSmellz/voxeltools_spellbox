@tool
extends EditorScript

# This script creates a proper VoxelBlockyLibrary with texture atlas
# Run this in the Script Editor: File -> Run

func _run():
	print("=== Creating Voxel Library with Texture Atlas ===")
	
	# Create directories
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("res://materials"):
		dir.make_dir("res://materials")
	if not dir.dir_exists("res://textures"):
		dir.make_dir("res://textures")
	
	# Create the atlas material
	var atlas_material = _create_atlas_material()
	
	# Create the voxel library
	var library = _create_voxel_library_with_atlas()
	
	print("\n=== Setup Complete! ===")
	print("Created VoxelBlockyLibrary at res://materials/voxel_library.tres")
	print("Created atlas material at res://materials/voxel_atlas_material.tres")
	print("\nIMPORTANT: You need to create or add a texture atlas image!")
	print("1. Create a 16x16 grid texture (256x256px if each tile is 16x16)")
	print("2. Save it as res://textures/voxel_atlas.png")
	print("3. Set it as the albedo_texture in voxel_atlas_material.tres")
	print("\nThen assign voxel_library.tres to your VoxelMesherBlocky's Library property")

func _create_atlas_material() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	
	# Configure for voxel rendering to prevent texture bleeding
	mat.vertex_color_use_as_albedo = false
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # Pixelated look - CRITICAL for preventing bleeding
	mat.roughness = 0.8
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	
	# Additional settings to prevent texture bleeding
	# These help ensure crisp pixel boundaries
	mat.disable_receive_shadows = false
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # Optional: for cleaner look
	
	# NOTE: You'll need to set the texture manually or uncomment this line with your atlas
	# mat.albedo_texture = preload("res://textures/voxel_atlas.png")
	
	ResourceSaver.save(mat, "res://materials/voxel_atlas_material.tres")
	print("Created atlas material with NEAREST filtering (prevents texture bleeding)")
	print("IMPORTANT: Make sure your texture import settings have:")
	print("  - Filter: OFF")
	print("  - Mipmaps: OFF (or set to 'Disable')")
	print("  - Fix Alpha Border: ON")
	
	return mat

func _create_voxel_library_with_atlas() -> VoxelBlockyLibrary:
	var library = VoxelBlockyLibrary.new()
	
	# IMPORTANT: Set atlas size (e.g., 16x16 for 256 blocks max)
	library.atlas_size = Vector2i(16, 16)
	
	# Load the atlas material
	var atlas_material = load("res://materials/voxel_atlas_material.tres")
	
	# IMPORTANT: IDs must match BlockIDs enum order
	# ID 0: Air (empty)
	var air = VoxelBlockyModelEmpty.new()
	library.add_model(air)  # ID 0 = BlockIDs.BlockID.AIR
	
	# ID 1: Dirt
	var dirt = _create_cube_model(
		Vector2i(2, 1),  # Position in atlas (dirt texture)
		atlas_material,
		"Dirt"
	)
	library.add_model(dirt)  # ID 1 = BlockIDs.BlockID.DIRT
	
	# ID 2: Grass
	var grass = _create_cube_with_sides(
		Vector2i(0, 1),  # Top (grass)
		Vector2i(1, 1),  # Sides (dirt with grass)
		Vector2i(2, 1),  # Bottom (dirt)
		atlas_material,
		"Grass"
	)
	library.add_model(grass)  # ID 2 = BlockIDs.BlockID.GRASS
	
	# ID 3: Sand
	var sand = _create_cube_model(
		Vector2i(3, 1),  # Position in atlas (sand texture)
		atlas_material,
		"Sand"
	)
	library.add_model(sand)  # ID 3 = BlockIDs.BlockID.SAND
	
	# ID 4: Stone
	var stone = _create_cube_model(
		Vector2i(0, 0),  # Position in atlas (top-left)
		atlas_material,
		"Stone"
	)
	library.add_model(stone)  # ID 4 = BlockIDs.BlockID.STONE
	
	# ID 5: Wood
	var wood = _create_cube_with_sides(
		Vector2i(1, 0),  # Top texture position
		Vector2i(2, 0),  # Side texture position  
		Vector2i(1, 0),  # Bottom texture position
		atlas_material,
		"Wood"
	)
	library.add_model(wood)  # ID 5 = BlockIDs.BlockID.WOOD
	
	# ID 6: Iron
	var iron = _create_cube_model(
		Vector2i(3, 0),
		atlas_material,
		"Iron"
	)
	library.add_model(iron)  # ID 6 = BlockIDs.BlockID.IRON
	
	# ID 7: Glass
	var glass = _create_cube_model(
		Vector2i(4, 0),
		atlas_material,
		"Glass"
	)
	glass.transparent = true
	glass.transparency_index = 1
	library.add_model(glass)  # ID 7 = BlockIDs.BlockID.GLASS
	
	# ID 8: Water
	var water = _create_cube_model(
		Vector2i(5, 0),
		atlas_material,
		"Water"
	)
	water.transparent = true
	water.transparency_index = 2
	library.add_model(water)  # ID 8 = BlockIDs.BlockID.WATER
	
	# ID 9: Lava
	var lava = _create_cube_model(
		Vector2i(6, 0),
		atlas_material,
		"Lava"
	)
	library.add_model(lava)  # ID 9 = BlockIDs.BlockID.LAVA
	
	# ID 10: Log (for trees)
	var log = _create_cube_with_sides(
		Vector2i(2, 0),  # Top (log end)
		Vector2i(2, 0),  # Sides (log bark)
		Vector2i(2, 0),  # Bottom (log end)
		atlas_material,
		"Log"
	)
	library.add_model(log)  # ID 10 = BlockIDs.BlockID.LOG
	
	# ID 11: Leaves
	var leaves = _create_cube_model(
		Vector2i(4, 1),  # Position in atlas (leaves texture) - adjust based on your atlas
		atlas_material,
		"Leaves"
	)
	leaves.transparent = true
	leaves.transparency_index = 3  # Use different transparency index than glass/water
	library.add_model(leaves)  # ID 11 = BlockIDs.BlockID.LEAVES
	
	# Bake the library for optimization
	library.bake()
	
	# Save the library
	ResourceSaver.save(library, "res://materials/voxel_library.tres")
	var model_count = library.models.size() if library.models else 0
	print("Created voxel library with " + str(model_count) + " models")
	
	return library

func _create_cube_model(atlas_pos: Vector2i, material: Material, model_name: String = "") -> VoxelBlockyModelCube:
	var model = VoxelBlockyModelCube.new()
	
	# Set the same texture coordinate for all faces
	for face in range(6):
		model.set_face_texture(face, atlas_pos)
	
	# Set material for all sides
	model.set_material_override(0, material)
	
	if model_name != "":
		model.resource_name = model_name
	
	return model

func _create_cube_with_sides(
	top_pos: Vector2i, 
	side_pos: Vector2i, 
	bottom_pos: Vector2i, 
	material: Material,
	model_name: String = ""
) -> VoxelBlockyModelCube:
	var model = VoxelBlockyModelCube.new()
	
	# Set face textures according to Voxel Tools face order
	# Face order: -X, +X, -Y, +Y, -Z, +Z
	model.set_face_texture(0, side_pos)    # Left (-X)
	model.set_face_texture(1, side_pos)    # Right (+X)
	model.set_face_texture(2, bottom_pos)  # Bottom (-Y)
	model.set_face_texture(3, top_pos)     # Top (+Y)
	model.set_face_texture(4, side_pos)    # Back (-Z)
	model.set_face_texture(5, side_pos)    # Front (+Z)
	
	# Set material
	model.set_material_override(0, material)
	
	if model_name != "":
		model.resource_name = model_name
	
	return model

func _create_example_atlas_texture():
	# This creates a simple colored atlas for testing
	var image = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	
	var colors = [
		Color(0.5, 0.5, 0.5),    # Stone
		Color(0.55, 0.27, 0.07),  # Wood top
		Color(0.45, 0.22, 0.05),  # Wood side
		Color(0.7, 0.7, 0.7),     # Iron
		Color(0.8, 0.9, 1.0, 0.5), # Glass
		Color(0.2, 0.4, 0.8, 0.7), # Water
		Color(1.0, 0.3, 0.0),      # Lava
		Color(0.2, 0.7, 0.2),      # Grass top
		Color(0.4, 0.3, 0.2),      # Dirt/grass side
		Color(0.3, 0.2, 0.1),      # Dirt
	]
	
	# Fill 16x16 tiles
	for i in range(colors.size()):
		var x = (i % 16) * 16
		var y = (i / 16) * 16
		
		for px in range(16):
			for py in range(16):
				image.set_pixel(x + px, y + py, colors[i])
	
	image.save_png("res://textures/voxel_atlas_example.png")
	print("Created example atlas texture at res://textures/voxel_atlas_example.png")
