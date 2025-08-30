class_name SpellSystem
extends Node

# This spell system works with VoxelWorldManager and Voxel Tools

# Spell effect definition
class SpellEffect:
	enum EmitterShape { SPHERE, CUBE, CONE, LINE, PLANE }
	
	var shape: EmitterShape = EmitterShape.SPHERE
	var radius: float = 5.0
	var duration: float = 10.0
	var property_modifier: Callable  # Function to modify properties
	var intensity: float = 1.0
	var origin: Vector3 = Vector3.ZERO
	var direction: Vector3 = Vector3.FORWARD  # For cone/line shapes
	
	func get_affected_positions(center: Vector3) -> Array:
		var positions = []
		
		match shape:
			EmitterShape.SPHERE:
				var r = int(ceil(radius))
				for x in range(-r, r + 1):
					for y in range(-r, r + 1):
						for z in range(-r, r + 1):
							var dist_sq = x*x + y*y + z*z
							if dist_sq <= radius * radius:
								positions.append(Vector3i(
									roundi(center.x + x),
									roundi(center.y + y),
									roundi(center.z + z)
								))
			
			EmitterShape.CUBE:
				var r = int(ceil(radius))
				for x in range(-r, r + 1):
					for y in range(-r, r + 1):
						for z in range(-r, r + 1):
							positions.append(Vector3i(
								roundi(center.x + x),
								roundi(center.y + y),
								roundi(center.z + z)
							))
			
			EmitterShape.CONE:
				var r = int(ceil(radius))
				var cone_angle = PI / 4  # 45 degrees
				for x in range(-r, r + 1):
					for y in range(-r, r + 1):
						for z in range(-r, r + 1):
							var offset = Vector3(x, y, z)
							var dist = offset.length()
							if dist <= radius and dist > 0:
								var angle = offset.normalized().angle_to(direction)
								if angle <= cone_angle:
									positions.append(Vector3i(
										roundi(center.x + x),
										roundi(center.y + y),
										roundi(center.z + z)
									))
			
			EmitterShape.LINE:
				var steps = int(radius * 2)
				for i in range(steps):
					var t = i / float(steps - 1)
					var pos = center + direction * radius * t
					positions.append(Vector3i(
						roundi(pos.x),
						roundi(pos.y),
						roundi(pos.z)
					))
			
			EmitterShape.PLANE:
				var r = int(ceil(radius))
				var right = direction.cross(Vector3.UP).normalized()
				var up = direction.cross(right).normalized()
				for x in range(-r, r + 1):
					for y in range(-r, r + 1):
						if x*x + y*y <= radius * radius:
							var pos = center + right * x + up * y
							positions.append(Vector3i(
								roundi(pos.x),
								roundi(pos.y),
								roundi(pos.z)
							))
		
		return positions

# Active spell instance
class ActiveSpell:
	var effect: SpellEffect
	var time_remaining: float
	var affected_positions: Array
	var original_properties: Dictionary  # Vector3i -> DynamicVoxelProperties
	
	func _init(spell_effect: SpellEffect, positions: Array):
		effect = spell_effect
		time_remaining = spell_effect.duration
		affected_positions = positions
		original_properties = {}

# Spell modification queue entry
class VoxelModification:
	var world_position: Vector3i
	var property_modifier: Callable
	var duration: float
	var intensity: float = 1.0

# Main spell system
var active_spells: Array = []
var modification_queue: Array = []
var spell_history: Array = []  # For undo functionality
const MAX_HISTORY = 50

# Predefined spell modifiers
static func modifier_reduce_friction(props: DynamicVoxelProperties, intensity: float):
	props.set_elasticity(DynamicVoxelProperties.Elasticity.BOUNCY)
	props.set_moisture(min(DynamicVoxelProperties.Moisture.SOAKED, 
		props.get_moisture() + int(intensity * 2)))

static func modifier_increase_temperature(props: DynamicVoxelProperties, intensity: float):
	var current = props.get_temperature_index()
	var increase = int(intensity * 5)
	props.set_temperature_index(min(31, current + increase))

static func modifier_decrease_temperature(props: DynamicVoxelProperties, intensity: float):
	var current = props.get_temperature_index()
	var decrease = int(intensity * 5)
	props.set_temperature_index(max(0, current - decrease))

static func modifier_make_intangible(props: DynamicVoxelProperties, intensity: float):
	props.set_intangible(true)
	props.set_loudness(DynamicVoxelProperties.Loudness.MUTED)

static func modifier_increase_toughness(props: DynamicVoxelProperties, intensity: float):
	var current = props.get_toughness()
	var increase = int(intensity * 2)
	props.set_toughness(min(DynamicVoxelProperties.Toughness.INDESTRUCTIBLE, 
		current + increase))

static func modifier_electrify(props: DynamicVoxelProperties, intensity: float):
	props.set_conductive(true)
	var charge = int(intensity * 3)
	props.set_charge_level(min(DynamicVoxelProperties.ChargeLevel.MAX_POSITIVE,
		DynamicVoxelProperties.ChargeLevel.NEUTRAL + charge))

static func modifier_make_bouncy(props: DynamicVoxelProperties, intensity: float):
	props.set_elasticity(DynamicVoxelProperties.Elasticity.BOUNCY)
	props.set_toughness(max(DynamicVoxelProperties.Toughness.WEAK,
		props.get_toughness() - 1))

# Create predefined spells
func create_fire_spell(radius: float = 5.0, duration: float = 30.0) -> SpellEffect:
	var spell = SpellEffect.new()
	spell.shape = SpellEffect.EmitterShape.SPHERE
	spell.radius = radius
	spell.duration = duration
	spell.intensity = 1.0
	spell.property_modifier = modifier_increase_temperature
	return spell

func create_freeze_spell(radius: float = 5.0, duration: float = 30.0) -> SpellEffect:
	var spell = SpellEffect.new()
	spell.shape = SpellEffect.EmitterShape.SPHERE
	spell.radius = radius
	spell.duration = duration
	spell.intensity = 1.0
	spell.property_modifier = modifier_decrease_temperature
	return spell

func create_phase_spell(radius: float = 3.0, duration: float = 10.0) -> SpellEffect:
	var spell = SpellEffect.new()
	spell.shape = SpellEffect.EmitterShape.SPHERE
	spell.radius = radius
	spell.duration = duration
	spell.intensity = 1.0
	spell.property_modifier = modifier_make_intangible
	return spell

func create_fortify_spell(radius: float = 4.0, duration: float = 60.0) -> SpellEffect:
	var spell = SpellEffect.new()
	spell.shape = SpellEffect.EmitterShape.CUBE
	spell.radius = radius
	spell.duration = duration
	spell.intensity = 1.0
	spell.property_modifier = modifier_increase_toughness
	return spell

func create_lightning_spell(length: float = 10.0, duration: float = 5.0) -> SpellEffect:
	var spell = SpellEffect.new()
	spell.shape = SpellEffect.EmitterShape.LINE
	spell.radius = length
	spell.duration = duration
	spell.intensity = 2.0
	spell.property_modifier = modifier_electrify
	return spell

func create_slippery_spell(radius: float = 6.0, duration: float = 20.0) -> SpellEffect:
	var spell = SpellEffect.new()
	spell.shape = SpellEffect.EmitterShape.PLANE
	spell.radius = radius
	spell.duration = duration
	spell.intensity = 1.0
	spell.property_modifier = modifier_reduce_friction
	return spell

# Apply a spell effect at a world position
func cast_spell(spell: SpellEffect, world_position: Vector3):
	var affected_positions = spell.get_affected_positions(world_position)
	
	# Create active spell instance
	var active = ActiveSpell.new(spell, affected_positions)
	active_spells.append(active)
	
	# Queue modifications for each affected position
	for pos in affected_positions:
		var mod = VoxelModification.new()
		mod.world_position = pos
		mod.property_modifier = spell.property_modifier
		mod.duration = spell.duration
		mod.intensity = spell.intensity
		modification_queue.append(mod)
	
	# Add to history
	if spell_history.size() >= MAX_HISTORY:
		spell_history.pop_front()
	spell_history.append({
		"spell": spell,
		"position": world_position,
		"timestamp": Time.get_ticks_msec()
	})

# Process all pending modifications (called by VoxelWorldManager)
func process_modifications(world_manager: VoxelWorldManager):
	# Batch process for efficiency with VoxelTool
	var modifications_to_apply = []
	
	while modification_queue.size() > 0:
		var mod = modification_queue.pop_front()
		
		# Get current voxel data
		var voxel_data = world_manager.get_voxel_at_pos(mod.world_position)
		
		if voxel_data.id == 0:  # Skip air blocks
			continue
		
		# Store original properties for restoration
		for active_spell in active_spells:
			if mod.world_position in active_spell.affected_positions:
				if not active_spell.original_properties.has(mod.world_position):
					active_spell.original_properties[mod.world_position] = voxel_data.properties.duplicate_and_modify()
				break
		
		# Apply property modification
		var new_props = voxel_data.properties.duplicate_and_modify()
		mod.property_modifier.call(new_props, mod.intensity)
		
		modifications_to_apply.append({
			"position": mod.world_position,
			"properties": new_props
		})
	
	# Apply all modifications in batch
	if modifications_to_apply.size() > 0:
		for mod in modifications_to_apply:
			world_manager.modify_voxel_properties(mod.position, mod.properties)

# Update active spells (called by VoxelWorldManager)
func update_spells(delta: float, world_manager: VoxelWorldManager):
	var spells_to_remove = []
	
	for i in range(active_spells.size() - 1, -1, -1):
		var spell = active_spells[i]
		spell.time_remaining -= delta
		
		if spell.time_remaining <= 0:
			# Restore original properties
			_restore_spell_properties(spell, world_manager)
			spells_to_remove.append(i)
	
	# Remove expired spells
	for i in spells_to_remove:
		active_spells.remove_at(i)

# Restore properties after spell expires
func _restore_spell_properties(spell: ActiveSpell, world_manager: VoxelWorldManager):
	for world_pos in spell.original_properties:
		# Check if voxel still exists
		var current_voxel = world_manager.get_voxel_at_pos(world_pos)
		if current_voxel.id > 0:  # Only restore if block still exists
			world_manager.modify_voxel_properties(
				world_pos,
				spell.original_properties[world_pos]
			)

# Cancel all active spells
func dispel_all(world_manager: VoxelWorldManager):
	for spell in active_spells:
		_restore_spell_properties(spell, world_manager)
	active_spells.clear()
	modification_queue.clear()

# Get information about active spells
func get_active_spell_count() -> int:
	return active_spells.size()

func get_active_spells_info() -> Array:
	var info = []
	for spell in active_spells:
		info.append({
			"shape": spell.effect.shape,
			"time_remaining": spell.time_remaining,
			"affected_voxels": spell.affected_positions.size()
		})
	return info

# Create combined spell effects
func create_combined_spell(modifiers: Array, shape: SpellEffect.EmitterShape = SpellEffect.EmitterShape.SPHERE, radius: float = 5.0, duration: float = 20.0) -> SpellEffect:
	var spell = SpellEffect.new()
	spell.shape = shape
	spell.radius = radius
	spell.duration = duration
	
	# Combine multiple modifiers into one
	spell.property_modifier = func(props: DynamicVoxelProperties, intensity: float):
		for modifier in modifiers:
			modifier.call(props, intensity)
	
	return spell

# Special spell combinations
func create_steam_spell(radius: float = 8.0, duration: float = 15.0) -> SpellEffect:
	# Combines heat and moisture
	return create_combined_spell(
		[modifier_increase_temperature, modifier_reduce_friction],
		SpellEffect.EmitterShape.SPHERE,
		radius,
		duration
	)

func create_permafrost_spell(radius: float = 6.0, duration: float = 45.0) -> SpellEffect:
	# Combines freezing and fortification
	return create_combined_spell(
		[modifier_decrease_temperature, modifier_increase_toughness],
		SpellEffect.EmitterShape.CUBE,
		radius,
		duration
	)
