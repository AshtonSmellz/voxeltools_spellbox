class_name ItemDrop
extends RigidBody3D

# Physical item that can be picked up from the world

@export var item_stack: ItemStack
@export var pickup_range: float = 2.0
@export var magnetic_range: float = 5.0
@export var magnetic_speed: float = 8.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var pickup_area: Area3D = $PickupArea
@onready var pickup_collision: CollisionShape3D = $PickupArea/CollisionShape3D

var pickup_timer: float = 0.0
var pickup_delay: float = 0.5  # Prevent immediate pickup
var target_player: Node3D = null
var player_search_timer: float = 0.0
var player_search_interval: float = 0.5  # Search for player every 0.5 seconds

signal item_picked_up(item_drop: ItemDrop)

func _ready():
	# Setup physics
	gravity_scale = 1.0
	mass = 0.1
	
	# Create pickup area if it doesn't exist
	if not pickup_area:
		_create_pickup_area()
	
	# Setup visual representation (will be called again if item_stack is set later)
	_setup_visual()
	
	# Connect area signals for RigidBody/CharacterBody detection
	if pickup_area:
		pickup_area.body_entered.connect(_on_body_entered)
		pickup_area.body_exited.connect(_on_body_exited)
		# Also connect area_entered for Area3D detection
		pickup_area.area_entered.connect(_on_area_entered)
		pickup_area.area_exited.connect(_on_area_exited)

func _create_pickup_area():
	pickup_area = Area3D.new()
	pickup_area.name = "PickupArea"
	pickup_area.collision_layer = 0
	pickup_area.collision_mask = 1  # Player layer
	add_child(pickup_area)
	
	pickup_collision = CollisionShape3D.new()
	pickup_collision.name = "CollisionShape3D"
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = pickup_range
	pickup_collision.shape = sphere_shape
	pickup_area.add_child(pickup_collision)

func _setup_visual():
	# Create mesh instance if it doesn't exist
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		add_child(mesh_instance)
	
	# Create collision shape if it doesn't exist
	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		add_child(collision_shape)
	
	# Setup collision
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(0.3, 0.3, 0.3)
	collision_shape.shape = box_shape
	
	# Create material based on item
	var material = StandardMaterial3D.new()
	material.roughness = 0.8
	material.metallic = 0.0
	
	if item_stack and not item_stack.is_empty() and item_stack.item:
		# For blocks, use the extracted icon texture (which is already a tile extracted from atlas)
		# This avoids UV coordinate issues
		if item_stack.item.icon and item_stack.item.item_type == Item.ItemType.BLOCK:
			material.albedo_texture = item_stack.item.icon
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # Pixel-perfect
			material.albedo_color = Color.WHITE
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # Unshaded to avoid lighting issues
			material.disable_receive_shadows = true
			
			# Use standard box mesh - the icon texture is already extracted as a single tile
			var box_mesh = BoxMesh.new()
			box_mesh.size = Vector3(0.3, 0.3, 0.3)
			mesh_instance.mesh = box_mesh
			print("ItemDrop: Using extracted icon texture for block: ", item_stack.item.name)
		elif item_stack.item.icon:
			# Fallback: use extracted icon texture (for non-block items)
			material.albedo_texture = item_stack.item.icon
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
			material.albedo_color = Color.WHITE
			
			# Use standard box mesh for icon textures
			var box_mesh = BoxMesh.new()
			box_mesh.size = Vector3(0.3, 0.3, 0.3)
			mesh_instance.mesh = box_mesh
			print("ItemDrop: Using icon texture for item: ", item_stack.item.name)
		else:
			# Fallback to color based on item type if no icon
			match item_stack.item.item_type:
				Item.ItemType.BLOCK:
					material.albedo_color = Color(0.6, 0.4, 0.2)  # Brown
				Item.ItemType.MATERIAL:
					material.albedo_color = Color(0.5, 0.5, 0.5)  # Gray
				Item.ItemType.TOOL:
					material.albedo_color = Color(1.0, 0.5, 0.0)  # Orange
				Item.ItemType.WEAPON:
					material.albedo_color = Color(0.8, 0.2, 0.2)  # Dark red
				Item.ItemType.CONSUMABLE:
					material.albedo_color = Color(0.2, 0.8, 0.2)  # Green
				_:
					material.albedo_color = Color(0.5, 0.5, 0.5)  # Default gray
			
			var box_mesh = BoxMesh.new()
			box_mesh.size = Vector3(0.3, 0.3, 0.3)
			mesh_instance.mesh = box_mesh
			print("ItemDrop: Using color for item (no icon): ", item_stack.item.name, " (type: ", item_stack.item.item_type, ")")
	else:
		# Default color if item_stack is not set yet (will be updated when item_stack is set)
		material.albedo_color = Color(0.5, 0.5, 0.5)  # Gray
		var box_mesh = BoxMesh.new()
		box_mesh.size = Vector3(0.3, 0.3, 0.3)
		mesh_instance.mesh = box_mesh
		if not item_stack:
			print("ItemDrop: Warning - item_stack is null during visual setup")
		elif item_stack.is_empty():
			print("ItemDrop: Warning - item_stack is empty during visual setup")
		elif not item_stack.item:
			print("ItemDrop: Warning - item_stack.item is null during visual setup")
	
	mesh_instance.material_override = material


# Create a cube mesh with UV coordinates mapped to a specific tile in the atlas
func _create_cube_mesh_with_atlas_uvs(tile_pos: Vector2i) -> ArrayMesh:
	# Get atlas size from voxel library
	var atlas_size_tiles = 10  # Default, but check library
	var library_path = "res://VoxelToolFiles/voxel_blocky_library.tres"
	var library = load(library_path) as VoxelBlockyLibrary
	if library and library.models.size() > 0:
		# Check first model to get atlas size
		var first_model = library.models[0]
		if first_model is VoxelBlockyModelCube:
			atlas_size_tiles = first_model.atlas_size_in_tiles.x
			if atlas_size_tiles == 0:
				atlas_size_tiles = 10  # Fallback
	
	var tile_size_uv = 1.0 / float(atlas_size_tiles)  # Each tile is 1/atlas_size of the atlas
	
	# Calculate UV coordinates for this tile
	# UV coordinates go from 0-1, so we need to map tile position to UV space
	var uv_min_x = float(tile_pos.x) * tile_size_uv
	var uv_max_x = float(tile_pos.x + 1) * tile_size_uv
	var uv_min_y = float(tile_pos.y) * tile_size_uv
	var uv_max_y = float(tile_pos.y + 1) * tile_size_uv
	
	# Flip Y coordinate (Godot's UV origin is bottom-left, but atlas is top-left)
	var uv_min_y_flipped = 1.0 - uv_max_y
	var uv_max_y_flipped = 1.0 - uv_min_y
	
	var size = 0.3
	var half_size = size / 2.0
	
	# Use SurfaceTool for easier mesh creation with proper normals
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Helper function to add a quad face
	var add_quad = func(v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, normal: Vector3, uv0: Vector2, uv1: Vector2, uv2: Vector2, uv3: Vector2):
		# Set normal once for the face
		surface_tool.set_normal(normal)
		
		# First triangle (counter-clockwise when viewed from outside)
		surface_tool.set_uv(uv0)
		surface_tool.add_vertex(v0)
		surface_tool.set_uv(uv1)
		surface_tool.add_vertex(v1)
		surface_tool.set_uv(uv2)
		surface_tool.add_vertex(v2)
		
		# Second triangle
		surface_tool.set_uv(uv0)
		surface_tool.add_vertex(v0)
		surface_tool.set_uv(uv2)
		surface_tool.add_vertex(v2)
		surface_tool.set_uv(uv3)
		surface_tool.add_vertex(v3)
	
	# UV coordinates for the tile
	var uv_tl = Vector2(uv_min_x, uv_min_y_flipped)  # Top-left
	var uv_tr = Vector2(uv_max_x, uv_min_y_flipped)  # Top-right
	var uv_br = Vector2(uv_max_x, uv_max_y_flipped)  # Bottom-right
	var uv_bl = Vector2(uv_min_x, uv_max_y_flipped)  # Bottom-left
	
	# Front face (+Z)
	add_quad.call(
		Vector3(-half_size, -half_size, half_size),  # Bottom-left
		Vector3(half_size, -half_size, half_size),   # Bottom-right
		Vector3(half_size, half_size, half_size),    # Top-right
		Vector3(-half_size, half_size, half_size),   # Top-left
		Vector3(0, 0, 1),  # Normal pointing +Z
		uv_bl, uv_br, uv_tr, uv_tl
	)
	
	# Back face (-Z)
	add_quad.call(
		Vector3(half_size, -half_size, -half_size),   # Bottom-left
		Vector3(-half_size, -half_size, -half_size),  # Bottom-right
		Vector3(-half_size, half_size, -half_size),   # Top-right
		Vector3(half_size, half_size, -half_size),    # Top-left
		Vector3(0, 0, -1),  # Normal pointing -Z
		uv_bl, uv_br, uv_tr, uv_tl
	)
	
	# Top face (+Y)
	add_quad.call(
		Vector3(-half_size, half_size, half_size),   # Front-left
		Vector3(half_size, half_size, half_size),    # Front-right
		Vector3(half_size, half_size, -half_size),  # Back-right
		Vector3(-half_size, half_size, -half_size),  # Back-left
		Vector3(0, 1, 0),  # Normal pointing +Y
		uv_bl, uv_br, uv_tr, uv_tl
	)
	
	# Bottom face (-Y)
	add_quad.call(
		Vector3(-half_size, -half_size, -half_size),  # Back-left
		Vector3(half_size, -half_size, -half_size),  # Back-right
		Vector3(half_size, -half_size, half_size),    # Front-right
		Vector3(-half_size, -half_size, half_size),   # Front-left
		Vector3(0, -1, 0),  # Normal pointing -Y
		uv_bl, uv_br, uv_tr, uv_tl
	)
	
	# Right face (+X)
	add_quad.call(
		Vector3(half_size, -half_size, half_size),   # Front-bottom
		Vector3(half_size, -half_size, -half_size),  # Back-bottom
		Vector3(half_size, half_size, -half_size),  # Back-top
		Vector3(half_size, half_size, half_size),    # Front-top
		Vector3(1, 0, 0),  # Normal pointing +X
		uv_bl, uv_br, uv_tr, uv_tl
	)
	
	# Left face (-X)
	add_quad.call(
		Vector3(-half_size, -half_size, -half_size),  # Back-bottom
		Vector3(-half_size, -half_size, half_size),   # Front-bottom
		Vector3(-half_size, half_size, half_size),     # Front-top
		Vector3(-half_size, half_size, -half_size),    # Back-top
		Vector3(-1, 0, 0),  # Normal pointing -X
		uv_bl, uv_br, uv_tr, uv_tl
	)
	
	# Generate tangents (needed for proper rendering)
	surface_tool.generate_tangents()
	
	# Generate the mesh
	var mesh = surface_tool.commit()
	
	if not mesh:
		print("ERROR: Failed to create mesh with SurfaceTool")
		return null
	
	print("Successfully created custom mesh - tile_pos: ", tile_pos, " UV range: (", uv_min_x, ",", uv_min_y_flipped, ") to (", uv_max_x, ",", uv_max_y_flipped, ")")
	return mesh

func setup_item(stack: ItemStack):
	if stack and not stack.is_empty() and stack.item:
		# Create a new ItemStack with the same item reference (Items are shared resources)
		item_stack = ItemStack.new(stack.item, stack.quantity)
		print("ItemDrop: Setup item - ", stack.quantity, "x ", stack.item.name)
	else:
		item_stack = ItemStack.new()
		print("Warning: ItemDrop.setup_item() called with null or empty stack")
		if stack:
			print("  - Stack exists but is_empty: ", stack.is_empty())
			if stack:
				print("  - Stack item is null: ", stack.item == null)
	
	# Re-setup visual now that item_stack is set
	if is_inside_tree():
		_setup_visual()
	else:
		# If not in tree yet, visual will be set up in _ready()
		call_deferred("_setup_visual")

func _physics_process(delta: float):
	pickup_timer += delta
	player_search_timer += delta
	
	# If no target player found via signals, try to find player manually (periodically)
	if not target_player and player_search_timer >= player_search_interval:
		player_search_timer = 0.0
		_find_player_in_range()
	
	# Handle magnetic attraction to player
	if target_player and pickup_timer > pickup_delay:
		var player_pos = target_player.global_position
		var item_pos = global_position
		
		# Calculate horizontal distance (ignore Y-axis for pickup range)
		# This allows pickup when items are to the side of the player
		var horizontal_distance = Vector2(item_pos.x, item_pos.z).distance_to(Vector2(player_pos.x, player_pos.z))
		var full_distance = global_position.distance_to(target_player.global_position)
		
		# Use full 3D distance for magnetic attraction direction
		var direction = (player_pos - item_pos).normalized()
		
		# Magnetic attraction works within magnetic_range (3D distance)
		if full_distance < magnetic_range:
			var force = direction * magnetic_speed * mass
			apply_central_force(force)
		
		# Auto pickup when horizontally close (within pickup_range horizontally, and reasonably close vertically)
		# This allows pickup when items are to the side of the player, not just directly below
		if horizontal_distance < pickup_range and abs(item_pos.y - player_pos.y) < 2.0:
			_try_pickup()

func _on_body_entered(body: Node3D):
	# Check if it's a player (RigidBody3D or CharacterBody3D)
	if _is_player(body):
		target_player = body

func _on_body_exited(body: Node3D):
	if body == target_player:
		target_player = null

func _on_area_entered(area: Area3D):
	# Check if area belongs to a player
	var parent = area.get_parent()
	if parent and _is_player(parent):
		target_player = parent

func _on_area_exited(area: Area3D):
	var parent = area.get_parent()
	if parent == target_player:
		target_player = null

func _is_player(node: Node) -> bool:
	# Check if node is a player character
	if not node:
		return false
	
	# Check by name
	if node.name == "Player" or node.name == "CharacterAvatar" or node.name.begins_with("Player"):
		return true
	
	# Check by script (character_controller)
	if node.get_script():
		var script_path = node.get_script().resource_path
		if script_path and script_path.ends_with("character_controller.gd"):
			return true
	
	# Check by methods
	if node.has_method("enable_game_ready") or node.has_method("get_inventory_manager"):
		return true
	
	return false

func _find_player_in_range():
	# Manually search for player in pickup range
	var scene_root = get_tree().current_scene
	if not scene_root:
		return
	
	var closest_player = _find_player_recursive(scene_root)
	
	if closest_player:
		# Use 3D distance for initial detection (magnetic_range)
		var dist = global_position.distance_to(closest_player.global_position)
		if dist <= magnetic_range:
			target_player = closest_player

func _find_player_recursive(node: Node) -> Node:
	if _is_player(node) and node is Node3D:
		return node as Node3D
	
	for child in node.get_children():
		var result = _find_player_recursive(child)
		if result:
			return result
	
	return null

func _try_pickup():
	if pickup_timer < pickup_delay:
		return
		
	if not item_stack or item_stack.is_empty():
		print("ItemDrop: Cannot pickup - item_stack is empty")
		queue_free()
		return
	
	if not item_stack.item:
		print("ItemDrop: Cannot pickup - item_stack.item is null")
		queue_free()
		return
	
	# Try to find inventory manager
	var inventory_manager = _find_inventory_manager()
	if not inventory_manager:
		print("ItemDrop: Cannot pickup - InventoryManager not found")
		return
	
	var quantity_to_add = item_stack.quantity
	var remaining = inventory_manager.inventory.add_item(item_stack.item, quantity_to_add)
	var actually_added = quantity_to_add - remaining
	
	print("ItemDrop: Attempted to add ", quantity_to_add, "x ", item_stack.item.name)
	print("ItemDrop: Remaining (couldn't add): ", remaining)
	print("ItemDrop: Actually added: ", actually_added)
	
	if remaining == 0:
		# All items picked up
		print("ItemDrop: Successfully picked up ", quantity_to_add, "x ", item_stack.item.name)
		item_picked_up.emit(self)
		queue_free()
	elif actually_added > 0:
		# Partial pickup - some items were added
		print("ItemDrop: Partial pickup - added ", actually_added, ", ", remaining, " remaining")
		item_stack.quantity = remaining
		_setup_visual()
	else:
		# Nothing could be added (inventory full)
		print("ItemDrop: Inventory full - could not add any items")

func _find_inventory_manager() -> InventoryManager:
	# Look for inventory manager in scene tree
	var scene_root = get_tree().current_scene
	return scene_root.find_child("InventoryManager", true, false) as InventoryManager

static func create_item_drop(stack: ItemStack, spawn_position: Vector3) -> ItemDrop:
	var item_drop = ItemDrop.new()
	item_drop.global_position = spawn_position
	item_drop.setup_item(stack)
	return item_drop
