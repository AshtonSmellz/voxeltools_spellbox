extends Node
class_name BlockPropertyManager

# Manages dynamic block properties across chunks efficiently
# Uses sparse storage - only stores blocks with modified properties

# Chunk-based storage for spatial locality
var chunk_dynamic_properties: Dictionary = {}  # Vector3i(chunk_coord) -> Dictionary[Vector3i(local_pos), DynamicBlockProperties]
var property_cache: Dictionary = {}  # Vector3i(world_pos) -> cached property values

# Performance settings
const CACHE_UPDATE_INTERVAL = 0.1  # seconds
const MAX_CACHED_PROPERTIES = 10000
const CHUNK_SIZE = 16

var block_library: BlockLibrary
var cache_timer: float = 0.0

func _ready():
	block_library = BlockLibrary.get_instance()

func _process(delta):
	cache_timer += delta
	if cache_timer >= CACHE_UPDATE_INTERVAL:
		_update_time_based_effects()
		_cleanup_cache()
		cache_timer = 0.0

# Core property access methods - optimized for frequent calls
func get_block_friction(world_pos: Vector3i, block_type_id: int) -> float:
	var dynamic_props = get_dynamic_properties(world_pos)
	if dynamic_props and dynamic_props.has_custom_friction():
		return dynamic_props.get_friction(block_library.get_block_type(block_type_id))
	return block_library.get_friction(block_type_id)

func get_block_temperature(world_pos: Vector3i, default_temp: float = 20.0) -> float:
	var dynamic_props = get_dynamic_properties(world_pos)
	if dynamic_props:
		return dynamic_props.get_temperature(default_temp)
	return default_temp

func get_block_gravity(world_pos: Vector3i, world_gravity: Vector3) -> Vector3:
	var dynamic_props = get_dynamic_properties(world_pos)
	if dynamic_props and dynamic_props.has_local_gravity():
		return dynamic_props.get_gravity(world_gravity)
	return world_gravity

func get_magical_charge(world_pos: Vector3i) -> float:
	var dynamic_props = get_dynamic_properties(world_pos)
	return dynamic_props.magical_charge if dynamic_props else 0.0

# Dynamic property management
func get_dynamic_properties(world_pos: Vector3i) -> DynamicBlockProperties:
	var chunk_pos = world_to_chunk(world_pos)
	var local_pos = world_to_local(world_pos)
	
	var chunk_data = chunk_dynamic_properties.get(chunk_pos)
	if chunk_data == null:
		return null
	
	return chunk_data.get(local_pos)

func set_dynamic_properties(world_pos: Vector3i, properties: DynamicBlockProperties):
	var chunk_pos = world_to_chunk(world_pos)
	var local_pos = world_to_local(world_pos)
	
	# Ensure chunk exists
	if not chunk_dynamic_properties.has(chunk_pos):
		chunk_dynamic_properties[chunk_pos] = {}
	
	var chunk_data = chunk_dynamic_properties[chunk_pos]
	
	if properties == null or properties.is_default_state(block_library.get_block_type(0)):
		# Remove if returning to default state
		chunk_data.erase(local_pos)
		if chunk_data.is_empty():
			chunk_dynamic_properties.erase(chunk_pos)
	else:
		chunk_data[local_pos] = properties
		properties.mark_updated()
	
	# Invalidate cache for this position
	property_cache.erase(world_pos)

func ensure_dynamic_properties(world_pos: Vector3i) -> DynamicBlockProperties:
	var existing = get_dynamic_properties(world_pos)
	if existing:
		return existing
	
	var new_props = DynamicBlockProperties.new()
	set_dynamic_properties(world_pos, new_props)
	return new_props

# Convenient property setters
func set_block_temperature(world_pos: Vector3i, temperature: float):
	var props = ensure_dynamic_properties(world_pos)
	props.set_temperature(temperature)

func set_block_friction(world_pos: Vector3i, friction: float):
	var props = ensure_dynamic_properties(world_pos)
	props.set_friction(friction)

func set_block_gravity(world_pos: Vector3i, gravity: Vector3):
	var props = ensure_dynamic_properties(world_pos)
	props.set_gravity(gravity)

func add_magical_charge(world_pos: Vector3i, charge_delta: float):
	var props = ensure_dynamic_properties(world_pos)
	props.magical_charge += charge_delta
	props.mark_updated()

func set_magical_charge(world_pos: Vector3i, charge: float):
	if charge == 0.0:
		var props = get_dynamic_properties(world_pos)
		if props:
			props.magical_charge = 0.0
	else:
		var props = ensure_dynamic_properties(world_pos)
		props.magical_charge = charge
		props.mark_updated()

# State management
func add_block_state(world_pos: Vector3i, state: DynamicBlockProperties.BlockStates):
	var props = ensure_dynamic_properties(world_pos)
	props.add_state(state)

func remove_block_state(world_pos: Vector3i, state: DynamicBlockProperties.BlockStates):
	var props = get_dynamic_properties(world_pos)
	if props:
		props.remove_state(state)

func has_block_state(world_pos: Vector3i, state: DynamicBlockProperties.BlockStates) -> bool:
	var props = get_dynamic_properties(world_pos)
	return props != null and props.has_state(state)

# Magical effect management
func add_magical_effect(world_pos: Vector3i, effect_id: int):
	var props = ensure_dynamic_properties(world_pos)
	props.add_magical_effect(effect_id)

func remove_magical_effect(world_pos: Vector3i, effect_id: int):
	var props = get_dynamic_properties(world_pos)
	if props:
		props.remove_magical_effect(effect_id)

func get_magical_effects(world_pos: Vector3i) -> Array[int]:
	var props = get_dynamic_properties(world_pos)
	return props.magical_effects if props else []

# Area effect operations (for spells affecting multiple blocks)
func set_area_temperature(center: Vector3i, radius: int, temperature: float):
	for x in range(center.x - radius, center.x + radius + 1):
		for y in range(center.y - radius, center.y + radius + 1):
			for z in range(center.z - radius, center.z + radius + 1):
				var pos = Vector3i(x, y, z)
				var distance = center.distance_to(pos)
				if distance <= radius:
					# Temperature falloff with distance
					var effective_temp = temperature * (1.0 - distance / float(radius))
					set_block_temperature(pos, effective_temp)

func set_area_friction(center: Vector3i, radius: int, friction: float):
	for x in range(center.x - radius, center.x + radius + 1):
		for y in range(center.y - radius, center.y + radius + 1):
			for z in range(center.z - radius, center.z + radius + 1):
				var pos = Vector3i(x, y, z)
				if center.distance_to(pos) <= radius:
					set_block_friction(pos, friction)

func add_area_magical_charge(center: Vector3i, radius: int, charge: float):
	for x in range(center.x - radius, center.x + radius + 1):
		for y in range(center.y - radius, center.y + radius + 1):
			for z in range(center.z - radius, center.z + radius + 1):
				var pos = Vector3i(x, y, z)
				var distance = center.distance_to(pos)
				if distance <= radius:
					var effective_charge = charge * (1.0 - distance / float(radius))
					add_magical_charge(pos, effective_charge)

# Coordinate conversion utilities
func world_to_chunk(world_pos: Vector3i) -> Vector3i:
	return Vector3i(
		world_pos.x >> 4,  # Divide by 16, faster than /16
		world_pos.y >> 4,
		world_pos.z >> 4
	)

func world_to_local(world_pos: Vector3i) -> Vector3i:
	return Vector3i(
		world_pos.x & 15,  # Modulo 16, faster than %16
		world_pos.y & 15,
		world_pos.z & 15
	)

func chunk_and_local_to_world(chunk_pos: Vector3i, local_pos: Vector3i) -> Vector3i:
	return Vector3i(
		(chunk_pos.x << 4) + local_pos.x,
		(chunk_pos.y << 4) + local_pos.y,
		(chunk_pos.z << 4) + local_pos.z
	)

# Performance optimization methods
func _update_time_based_effects():
	var current_time = Time.get_ticks_msec() * 0.001
	
	for chunk_pos in chunk_dynamic_properties.keys():
		var chunk_data = chunk_dynamic_properties[chunk_pos]
		var positions_to_remove: Array[Vector3i] = []
		
		for local_pos in chunk_data.keys():
			var props: DynamicBlockProperties = chunk_data[local_pos]
			var time_since_update = current_time - props.last_update_time
			
			# Example: Gradual temperature equilibration with environment
			if props.has_custom_temperature() and time_since_update > 1.0:
				var ambient_temp = 20.0  # Could be biome-based
				var temp_diff = props.temperature - ambient_temp
				if abs(temp_diff) > 0.1:
					props.temperature -= temp_diff * 0.1 * time_since_update
					props.mark_updated()
				else:
					props.temperature = NAN  # Return to default
			
			# Example: Magical charge decay
			if props.magical_charge != 0.0 and time_since_update > 5.0:
				props.magical_charge *= pow(0.95, time_since_update)  # 5% decay per second
				props.mark_updated()
				if abs(props.magical_charge) < 0.01:
					props.magical_charge = 0.0
			
			# Clean up blocks that returned to default state
			var world_pos = chunk_and_local_to_world(chunk_pos, local_pos)
			var block_type = block_library.get_block_type(0)  # Would need actual block type
			if props.is_default_state(block_type):
				positions_to_remove.append(local_pos)
		
		# Remove positions that returned to default
		for local_pos in positions_to_remove:
			chunk_data.erase(local_pos)
		
		# Remove empty chunks
		if chunk_data.is_empty():
			chunk_dynamic_properties.erase(chunk_pos)

func _cleanup_cache():
	if property_cache.size() > MAX_CACHED_PROPERTIES:
		# Simple cleanup: remove oldest entries
		var keys = property_cache.keys()
		var to_remove = keys.slice(0, keys.size() - MAX_CACHED_PROPERTIES)
		for key in to_remove:
			property_cache.erase(key)

# Chunk loading/unloading for memory management
func unload_chunk(chunk_pos: Vector3i):
	chunk_dynamic_properties.erase(chunk_pos)
	
	# Clear related cache entries
	for cached_pos in property_cache.keys():
		if world_to_chunk(cached_pos) == chunk_pos:
			property_cache.erase(cached_pos)

func get_chunk_memory_usage(chunk_pos: Vector3i) -> int:
	var chunk_data = chunk_dynamic_properties.get(chunk_pos)
	if chunk_data == null:
		return 0
	
	# Rough estimate of memory usage in bytes
	var usage = 0
	for local_pos in chunk_data:
		var props: DynamicBlockProperties = chunk_data[local_pos]
		usage += 64  # Base DynamicBlockProperties size estimate
		usage += props.property_overrides.size() * 32  # Rough dictionary overhead
		usage += props.magical_effects.size() * 4  # Array of ints
	
	return usage

# Debugging and inspection methods
func get_modified_blocks_in_chunk(chunk_pos: Vector3i) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	var chunk_data = chunk_dynamic_properties.get(chunk_pos)
	if chunk_data:
		for local_pos in chunk_data.keys():
			result.append(chunk_and_local_to_world(chunk_pos, local_pos))
	return result

func get_total_modified_blocks() -> int:
	var total = 0
	for chunk_data in chunk_dynamic_properties.values():
		total += chunk_data.size()
	return total

func get_memory_usage_summary() -> Dictionary:
	var chunk_count = chunk_dynamic_properties.size()
	var total_blocks = get_total_modified_blocks()
	var estimated_memory = total_blocks * 64  # rough estimate in bytes
	
	return {
		"active_chunks": chunk_count,
		"modified_blocks": total_blocks,
		"estimated_memory_kb": estimated_memory / 1024,
		"cache_entries": property_cache.size()
	}
