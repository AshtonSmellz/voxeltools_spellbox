extends Node3D

@export var speed := 5.0
@export var gravity := 9.8
@export var jump_force := 5.0
@export var head : NodePath
@export var mouse_sensitivity := 0.003
@export var reach_distance := 10.0

@export var terrain : NodePath

var _velocity := Vector3()
var _grounded := false
var _head : Node3D = null
var _box_mover := VoxelBoxMover.new()
var _terrain : VoxelTerrain = null
var _voxel_tool : VoxelToolTerrain = null

# Camera rotation variables
var _mouse_delta := Vector2()
var _rotation_x := 0.0

# Game state control
var _game_ready := false
var _initial_position_set := false


func _ready():
	_box_mover.set_collision_mask(1) # Excludes rails
	_box_mover.set_step_climbing_enabled(true)
	_box_mover.set_max_step_height(0.5)

	_head = get_node(head)
	
	# Setup terrain and voxel tool
	if has_node(terrain):
		_terrain = get_node(terrain)
		if _terrain:
			_voxel_tool = _terrain.get_voxel_tool()
	
	# Note: Mouse capture is handled by the main menu system

func _input(event):
	# Handle mouse movement for camera rotation
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_delta += event.relative
	
	# Handle mouse clicks for block destruction
	if event is InputEventMouseButton and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_try_destroy_block()

func _physics_process(delta: float):
	# Apply mouse rotation
	if _mouse_delta.length() > 0:
		_apply_mouse_rotation()
		_mouse_delta = Vector2()
	
	# Don't process movement/physics until game is ready
	if not _game_ready:
		return
	
	# Use player body rotation for movement, not head rotation
	var forward = -global_transform.basis.z.normalized()  # Forward is -Z in Godot
	var right = global_transform.basis.x.normalized()
	var motor = Vector3()
	
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_W):
		motor += forward
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		motor -= forward
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_A):
		motor -= right
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		motor += right
	
	motor = motor.normalized() * speed
	
	_velocity.x = motor.x
	_velocity.z = motor.z
	_velocity.y -= gravity * delta
	
	if _grounded and Input.is_key_pressed(KEY_SPACE):
		_velocity.y = jump_force
		_grounded = false
	
	var motion := _velocity * delta
	
	if has_node(terrain):
		var aabb := AABB(Vector3(-0.4, -0.9, -0.4), Vector3(0.8, 1.8, 0.8))
		var terrain_node : VoxelTerrain = get_node(terrain)
		
		var vt := terrain_node.get_voxel_tool()
		if vt.is_area_editable(AABB(aabb.position + position, aabb.size)):
			var prev_motion := motion

			# Modify motion taking collisions into account
			motion = _box_mover.get_motion(position, motion, aabb, terrain_node)

			# Apply motion with a raw translation.
			global_translate(motion)

			# If new motion doesnt move vertically and we were falling before, we just landed
			if absf(motion.y) < 0.001 and prev_motion.y < -0.001:
				_grounded = true

			if _box_mover.has_stepped_up():
				# When we step up, the motion vector will have vertical movement,
				# however it is not caused by falling or jumping, but by snapping the body on
				# top of the step. So after we applied motion, we consider it grounded,
				# and we reset motion.y so we don't induce a "jump" velocity later.
				motion.y = 0
				_grounded = true
			
			# Otherwise, if new motion is moving vertically, we may not be grounded anymore
			elif absf(motion.y) > 0.001:
				_grounded = false

			# TODO Stepping up stairs is quite janky. Minecraft seems to smooth it out a little.
			# That would be a visual-only trick to apply it seems.
		
		else:
			# Don't fall to infinity, wait until terrain loads
			motion = Vector3()

	assert(delta > 0)
	# Re-inject velocity from resulting motion
	_velocity = motion / delta

	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer():
		# Broadcast our position to other peers.
		# Note, for other peers, this is a different script (remote_character.gd).
		# Each peer is authoritative of its own position for now.
		# TODO Make sure this RPC is not sent when we are not connected
		rpc(&"receive_position", position)


@rpc("authority", "call_remote", "unreliable")
func receive_position(pos: Vector3):
	# We currently don't expect this to be called. The actual targetted script is different.
	# I had to define it otherwise Godot throws a lot of errors everytime I call the RPC...
	push_error("Didn't expect to receive RPC position")

func _apply_mouse_rotation():
	# Rotate player body horizontally (Y-axis)
	rotate_y(-_mouse_delta.x * mouse_sensitivity)
	
	# Rotate camera vertically (X-axis) with clamping
	_rotation_x -= _mouse_delta.y * mouse_sensitivity
	_rotation_x = clamp(_rotation_x, -PI/2, PI/2)
	
	if _head:
		_head.rotation.x = _rotation_x

func _try_destroy_block():
	if not _terrain or not _voxel_tool or not _head:
		return
	
	# Cast ray from camera center
	var camera: Camera3D = null
	# Try to find camera in head node hierarchy
	camera = _find_camera_recursive(_head)
	
	if not camera:
		print("No camera found in head node hierarchy")
		print("Head node children: ", _head.get_children().map(func(n): return n.name + " (" + n.get_class() + ")"))
		return
	
	var from = camera.global_position
	var to = from + (-camera.global_transform.basis.z * reach_distance)
	
	# Use physics space to raycast
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Terrain layer
	
	var result = space_state.intersect_ray(query)
	if result.is_empty():
		return
	
	# Convert world position to voxel coordinates
	var hit_pos = result.position
	var normal = result.normal
	
	# Calculate the voxel position by moving slightly inward from the surface
	var local_hit_pos = _terrain.to_local(hit_pos)
	var offset_pos = local_hit_pos - normal * 0.1
	var voxel_pos = Vector3i(floor(offset_pos.x), floor(offset_pos.y), floor(offset_pos.z))
	
	print("Hit pos: ", hit_pos, " Local: ", local_hit_pos, " Normal: ", normal, " Voxel: ", voxel_pos)
	
	# Get the voxel value at this position
	var voxel_value = _voxel_tool.get_voxel(voxel_pos)
	if voxel_value == 0:  # Air, nothing to destroy
		return
	
	# Remove the voxel
	_voxel_tool.set_voxel(voxel_pos, 0)
	
	# Find VoxelWorldManager and emit voxel_destroyed signal
	var world_manager = get_tree().current_scene.find_child("VoxelWorldManager", true, false)
	if world_manager and world_manager.has_signal("voxel_destroyed"):
		world_manager.voxel_destroyed.emit(voxel_pos, voxel_value)
	else:
		# Fallback to direct item drop creation if no VoxelWorldManager
		_create_item_drop(voxel_value, _terrain.to_global(Vector3(voxel_pos)) + Vector3(0.5, 0.5, 0.5))

func _create_item_drop(voxel_id: int, world_position: Vector3):
	# Map voxel IDs to item IDs (you might want to create a proper mapping system)
	var item_id = _voxel_id_to_item_id(voxel_id)
	if item_id.is_empty():
		return
	
	# Find inventory manager to get item data
	var inventory_manager = get_tree().current_scene.find_child("InventoryManager", true, false) as InventoryManager
	if not inventory_manager:
		return
	
	var item = inventory_manager.get_item_by_id(item_id)
	if not item:
		return
	
	# Create item stack
	var item_stack = ItemStack.new(item, 1)
	
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

func _voxel_id_to_item_id(voxel_id: int) -> String:
	# Use unified BlockIDs system
	return BlockIDs.block_id_to_item_id(voxel_id)

func enable_game_ready():
	_game_ready = true
	print("Game ready - character controller enabled")

func set_spawn_position(pos: Vector3):
	if not _initial_position_set:
		global_position = pos
		_initial_position_set = true
		print("Set player spawn position: ", pos)

func _find_camera_recursive(node: Node) -> Camera3D:
	# Check if this node is a Camera3D
	if node is Camera3D:
		return node as Camera3D
	
	# Search children recursively
	for child in node.get_children():
		var camera = _find_camera_recursive(child)
		if camera:
			return camera
	
	return null
