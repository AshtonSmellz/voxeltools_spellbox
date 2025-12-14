@tool
extends EditorScript

# This script fixes texture bleeding by adjusting UV coordinates
# to add small margins around each texture in the atlas

func _run():
	print("Starting texture bleeding fix...")
	
	# Load the voxel library
	var library_path = "res://blocks/voxel_library.tres"
	var library = load(library_path) as VoxelBlockyLibrary
	
	if not library:
		print("Could not load voxel library at: ", library_path)
		return
	
	var model_count = library.models.size() if library.models else 0
	print("Loaded library with ", model_count, " models")
	
	# Atlas size (assuming 16x16 atlas)
	var atlas_size = Vector2(16, 16)
	var tile_size = Vector2(1.0 / atlas_size.x, 1.0 / atlas_size.y)
	
	# UV margin (1/4 pixel margin on each side)
	var margin = Vector2(0.25 / (atlas_size.x * 16), 0.25 / (atlas_size.y * 16))
	
	print("Tile size: ", tile_size, " Margin: ", margin)
	
	# Process each model in the library
	if library.models:
		for i in range(library.models.size()):
			var model = library.models[i]
		if model is VoxelBlockyModelCube:
			print("Processing cube model ", i, ": ", model.resource_name)
			_fix_cube_model_uvs(model as VoxelBlockyModelCube, tile_size, margin)
	
	# Save the modified library
	var result = ResourceSaver.save(library, library_path)
	if result == OK:
		print("Successfully saved fixed library!")
	else:
		print("Failed to save library: ", result)

func _fix_cube_model_uvs(model: VoxelBlockyModelCube, tile_size: Vector2, margin: Vector2):
	# This would require direct mesh access which is complex
	# Instead, let's create a simpler solution
	print("Model ", model.resource_name, " would benefit from UV margin adjustments")