@tool
extends EditorScript

# Generates a simple texture atlas for testing
# Run this in Script Editor: File -> Run

func _run():
	print("=== Generating Texture Atlas ===")
	
	# Create directories if needed
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("res://textures"):
		dir.make_dir("res://textures")
	
	# Generate a 256x256 texture atlas (16x16 tiles, each 16x16 pixels)
	var atlas_size = 256
	var tile_size = 16
	var tiles_per_row = atlas_size / tile_size  # 16
	
	var image = Image.create(atlas_size, atlas_size, false, Image.FORMAT_RGBA8)
	
	# Define textures for each block type
	_draw_stone_texture(image, 0, 0)           # Position 0,0
	_draw_wood_top_texture(image, 1, 0)        # Position 1,0  
	_draw_wood_side_texture(image, 2, 0)       # Position 2,0
	_draw_iron_texture(image, 3, 0)            # Position 3,0
	_draw_glass_texture(image, 4, 0)           # Position 4,0
	_draw_water_texture(image, 5, 0)           # Position 5,0
	_draw_lava_texture(image, 6, 0)            # Position 6,0
	_draw_grass_top_texture(image, 0, 1)       # Position 0,1
	_draw_grass_side_texture(image, 1, 1)      # Position 1,1
	_draw_dirt_texture(image, 2, 1)            # Position 2,1
	
	# Save the atlas
	image.save_png("res://textures/voxel_atlas.png")
	print("Created texture atlas at res://textures/voxel_atlas.png")
	
	# Also create a reference guide
	_create_atlas_reference()

func _draw_tile(image: Image, tile_x: int, tile_y: int, pattern_func: Callable):
	var start_x = tile_x * 16
	var start_y = tile_y * 16
	
	for x in range(16):
		for y in range(16):
			var color = pattern_func.call(x, y)
			image.set_pixel(start_x + x, start_y + y, color)

func _draw_stone_texture(image: Image, tile_x: int, tile_y: int):
	_draw_tile(image, tile_x, tile_y, func(x: int, y: int) -> Color:
		var noise = (sin(x * 0.5) * cos(y * 0.3) + 1.0) * 0.1
		var base = 0.5 + noise
		return Color(base, base, base)
	)

func _draw_wood_top_texture(image: Image, tile_x: int, tile_y: int):
	_draw_tile(image, tile_x, tile_y, func(x: int, y: int) -> Color:
		# Wood rings pattern
		var center_x = 8.0
		var center_y = 8.0
		var dist = sqrt(pow(x - center_x, 2) + pow(y - center_y, 2))
		var ring = sin(dist * 0.5) * 0.1 + 0.5
		return Color(0.55 * ring, 0.27 * ring, 0.07)
	)

func _draw_wood_side_texture(image: Image, tile_x: int, tile_y: int):
	_draw_tile(image, tile_x, tile_y, func(x: int, y: int) -> Color:
		# Vertical wood grain
		var grain = sin(x * 0.8) * 0.1 + 0.9
		return Color(0.45 * grain, 0.22 * grain, 0.05)
	)

func _draw_iron_texture(image: Image, tile_x: int, tile_y: int):
	_draw_tile(image, tile_x, tile_y, func(x: int, y: int) -> Color:
		# Metallic pattern with slight scratches
		var scratch = randf_range(0.9, 1.0) if (x + y) % 7 == 0 else 1.0
		var base = 0.7 * scratch
		return Color(base, base, base)
	)

func _draw_glass_texture(image: Image, tile_x: int, tile_y: int):
	_draw_tile(image, tile_x, tile_y, func(x: int, y: int) -> Color:
		# Glass with slight border
		var is_border = x == 0 or x == 15 or y == 0 or y == 15
		if is_border:
			return Color(0.9, 0.95, 1.0, 0.8)
		else:
			return Color(0.8, 0.9, 1.0, 0.3)
	)

func _draw_water_texture(image: Image, tile_x: int, tile_y: int):
	_draw_tile(image, tile_x, tile_y, func(x: int, y: int) -> Color:
		# Wavy water pattern
		var wave = sin(x * 0.5 + y * 0.3) * 0.1 + 0.9
		return Color(0.2 * wave, 0.4 * wave, 0.8, 0.7)
	)

func _draw_lava_texture(image: Image, tile_x: int, tile_y: int):
	_draw_tile(image, tile_x, tile_y, func(x: int, y: int) -> Color:
		# Hot lava with bright spots
		var heat = sin(x * 0.3) * cos(y * 0.4) * 0.3 + 0.7
		return Color(1.0, 0.3 * heat, 0.0)
	)

func _draw_grass_top_texture(image: Image, tile_x: int, tile_y: int):
	_draw_tile(image, tile_x, tile_y, func(x: int, y: int) -> Color:
		# Grass blades pattern
		var blade = sin(x * 2.0 + y * 0.5) * 0.1 + 0.9
		return Color(0.2, 0.7 * blade, 0.2)
	)

func _draw_grass_side_texture(image: Image, tile_x: int, tile_y: int):
	_draw_tile(image, tile_x, tile_y, func(x: int, y: int) -> Color:
		# Dirt with grass on top
		if y < 4:
			var blade = sin(x * 2.0) * 0.1 + 0.9
			return Color(0.2, 0.7 * blade, 0.2)
		else:
			return Color(0.4, 0.3, 0.2)
	)

func _draw_dirt_texture(image: Image, tile_x: int, tile_y: int):
	_draw_tile(image, tile_x, tile_y, func(x: int, y: int) -> Color:
		# Dirt pattern
		var noise = randf_range(0.8, 1.0)
		return Color(0.3 * noise, 0.2 * noise, 0.1 * noise)
	)

func _create_atlas_reference():
	var reference = """
=== Voxel Atlas Reference ===
Atlas Size: 16x16 tiles (256x256 pixels)
Tile Size: 16x16 pixels each

Block ID -> Atlas Position (x, y):
0: Air (no texture)
1: Stone -> (0, 0)
2: Wood -> Top (1, 0), Sides (2, 0)
3: Iron -> (3, 0)
4: Glass -> (4, 0)
5: Water -> (5, 0)
6: Lava -> (6, 0)
7: Grass -> Top (0, 1), Sides (1, 1), Bottom (2, 1)

To add more blocks:
- Add textures at the next available position
- Update VoxelBlockyLibrary with new model
- Add to MaterialDatabase
"""
	
	var file = FileAccess.open("res://textures/atlas_reference.txt", FileAccess.WRITE)
	file.store_string(reference)
	file.close()
	
	print("Created atlas reference at res://textures/atlas_reference.txt")
