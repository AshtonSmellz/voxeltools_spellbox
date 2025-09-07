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

signal item_picked_up(item_drop: ItemDrop)

func _ready():
	# Setup physics
	gravity_scale = 1.0
	mass = 0.1
	
	# Create pickup area if it doesn't exist
	if not pickup_area:
		_create_pickup_area()
	
	# Setup visual representation
	_setup_visual()
	
	# Connect area signals
	if pickup_area:
		pickup_area.body_entered.connect(_on_body_entered)
		pickup_area.body_exited.connect(_on_body_exited)

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
	
	# Setup basic cube mesh for dropped items
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.3, 0.3, 0.3)
	mesh_instance.mesh = box_mesh
	
	# Setup collision
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(0.3, 0.3, 0.3)
	collision_shape.shape = box_shape
	
	# Create material based on item
	if item_stack and not item_stack.is_empty():
		var material = StandardMaterial3D.new()
		
		# Set color based on item type
		match item_stack.item.item_type:
			Item.ItemType.BLOCK:
				material.albedo_color = Color.BROWN
			Item.ItemType.MATERIAL:
				material.albedo_color = Color.GRAY
			Item.ItemType.TOOL:
				material.albedo_color = Color.ORANGE
			Item.ItemType.WEAPON:
				material.albedo_color = Color.RED
			Item.ItemType.CONSUMABLE:
				material.albedo_color = Color.GREEN
		
		mesh_instance.material_override = material

func setup_item(stack: ItemStack):
	item_stack = stack.duplicate() if stack else ItemStack.new()
	_setup_visual()

func _physics_process(delta: float):
	pickup_timer += delta
	
	# Handle magnetic attraction to player
	if target_player and pickup_timer > pickup_delay:
		var direction = (target_player.global_position - global_position).normalized()
		var distance = global_position.distance_to(target_player.global_position)
		
		if distance < magnetic_range:
			var force = direction * magnetic_speed * mass
			apply_central_force(force)
		
		# Auto pickup when very close
		if distance < 0.5:
			_try_pickup()

func _on_body_entered(body: Node3D):
	# Check if it's a player (you might need to adjust this check)
	if body.name == "Player" or body.has_method("get_inventory_manager"):
		target_player = body

func _on_body_exited(body: Node3D):
	if body == target_player:
		target_player = null

func _try_pickup():
	if pickup_timer < pickup_delay:
		return
		
	if not item_stack or item_stack.is_empty():
		queue_free()
		return
	
	# Try to find inventory manager
	var inventory_manager = _find_inventory_manager()
	if inventory_manager:
		var remaining = inventory_manager.inventory.add_item(item_stack.item, item_stack.quantity)
		
		if remaining == 0:
			# All items picked up
			item_picked_up.emit(self)
			queue_free()
		else:
			# Partial pickup
			item_stack.quantity = remaining
			_setup_visual()

func _find_inventory_manager() -> InventoryManager:
	# Look for inventory manager in scene tree
	var scene_root = get_tree().current_scene
	return scene_root.find_child("InventoryManager", true, false) as InventoryManager

static func create_item_drop(stack: ItemStack, spawn_position: Vector3) -> ItemDrop:
	var item_drop = ItemDrop.new()
	item_drop.setup_item(stack)
	item_drop.global_position = spawn_position
	return item_drop