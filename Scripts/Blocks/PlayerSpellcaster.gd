class_name PlayerSpellcaster
extends Node

# Example player controller for casting spells
# Attach this to your player character

@export var world_manager: VoxelWorldManager
@export var cast_range: float = 50.0
@export var spell_cooldown: float = 0.5

@onready var camera: Camera3D = $"../Camera3D"  # Adjust path to your camera

var current_cooldown: float = 0.0
var selected_spell: SpellSystem.SpellEffect
var spell_inventory: Array = []

signal spell_cast(spell: SpellSystem.SpellEffect, position: Vector3)

func _ready():
	# Find world manager if not set
	if not world_manager:
		world_manager = get_node("/root/Main/VoxelWorldManager")  # Adjust path
	
	# Initialize spell inventory
	_setup_spell_inventory()

func _setup_spell_inventory():
	# Create available spells
	spell_inventory = [
		world_manager.spell_system.create_fire_spell(),
		world_manager.spell_system.create_freeze_spell(),
		world_manager.spell_system.create_phase_spell(),
		world_manager.spell_system.create_fortify_spell(),
		world_manager.spell_system.create_lightning_spell(),
		world_manager.spell_system.create_slippery_spell(),
		world_manager.spell_system.create_steam_spell(),
		world_manager.spell_system.create_permafrost_spell()
	]
	
	# Select first spell by default
	if spell_inventory.size() > 0:
		selected_spell = spell_inventory[0]

func _process(delta):
	# Update cooldown
	if current_cooldown > 0:
		current_cooldown -= delta
	
	# Handle spell selection
	_handle_spell_selection()

func _input(event):
	# Cast spell on left click
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if current_cooldown <= 0:
				cast_spell_at_cursor()
	
	# Place/remove blocks with right click (optional)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			interact_with_voxel()

func _handle_spell_selection():
	# Number keys to select spells
	for i in range(min(9, spell_inventory.size())):
		if Input.is_action_just_pressed("slot_" + str(i + 1)):
			selected_spell = spell_inventory[i]
			print("Selected spell: ", i + 1)

func cast_spell_at_cursor():
	if not selected_spell or not world_manager:
		return
	
	# Raycast from camera to find target position
	var from = camera.global_position
	var to = from + camera.global_transform.basis.z * -cast_range
	
	# Use VoxelTool raycast
	var result = world_manager.raycast_voxel(
		from, 
		camera.global_transform.basis.z * -1,
		cast_range
	)
	
	var cast_position: Vector3
	
	if result.hit:
		# Cast at the surface of the hit voxel
		cast_position = Vector3(result.position)
		
		# Adjust position based on spell shape
		if selected_spell.shape == SpellSystem.SpellEffect.EmitterShape.PLANE:
			# Place plane spells on top of surface
			cast_position.y += 1
	else:
		# Cast at max range if no hit
		cast_position = to
	
	# Cast the spell
	world_manager.cast_spell(selected_spell, cast_position)
	spell_cast.emit(selected_spell, cast_position)
	
	# Apply cooldown
	current_cooldown = spell_cooldown
	
	# Visual/audio feedback
	_create_spell_effect_visual(cast_position)

func interact_with_voxel():
	if not world_manager:
		return
	
	var from = camera.global_position
	var result = world_manager.raycast_voxel(
		from,
		camera.global_transform.basis.z * -1,
		cast_range
	)
	
	if result.hit:
		if Input.is_action_pressed("shift"):
			# Place block
			var place_pos = result.previous_position
			world_manager.set_voxel_at_pos(place_pos, 1)  # Place stone
		else:
			# Remove block
			world_manager.set_voxel_at_pos(result.position, 0)

func _create_spell_effect_visual(position: Vector3):
	# Create particle effect or other visual feedback
	# This is a placeholder - implement your own VFX
	var particles = GPUParticles3D.new()
	particles.amount = 50
	particles.lifetime = 1.0
	particles.global_position = position
	particles.emitting = true
	
	get_tree().current_scene.add_child(particles)
	
	# Clean up after effect
	await get_tree().create_timer(2.0).timeout
	particles.queue_free()

# Get current spell info for UI
func get_current_spell_info() -> Dictionary:
	if not selected_spell:
		return {}
	
	return {
		"shape": selected_spell.shape,
		"radius": selected_spell.radius,
		"duration": selected_spell.duration,
		"cooldown_remaining": current_cooldown,
		"cooldown_total": spell_cooldown
	}
