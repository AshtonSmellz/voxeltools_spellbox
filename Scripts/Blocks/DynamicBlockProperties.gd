extends Resource
class_name DynamicBlockProperties

# Efficient storage for per-block dynamic properties
# Only stores properties that differ from BlockType defaults

# Core dynamic properties (most common overrides)
@export var temperature: float = NAN  # NAN = use environment default
@export var custom_friction: float = NAN  # NAN = use BlockType default
@export var local_gravity: Vector3 = Vector3.INF  # INF = use world default
@export var magical_charge: float = 0.0  # Always stored, very common in magic system

# Property override dictionary for less common properties
# Key: property_name (String), Value: property_value (Variant)
@export var property_overrides: Dictionary = {}

# Active magical effects on this block
@export var magical_effects: Array[int] = []  # Array of effect IDs for performance

# Bitfield for boolean states (very memory efficient)
enum BlockStates {
	NONE = 0,
	WET = 1,
	FROZEN = 2,
	HEATED = 4,
	MAGNETIZED = 8,
	CHARGED = 16,
	CORRODED = 32,
	REINFORCED = 64,
	CURSED = 128,
	BLESSED = 256,
	INVISIBLE = 512,
	PHASED = 1024  # Can be walked through
}
@export var state_flags: int = BlockStates.NONE

# Timestamp for time-based effects (decay, cooling, etc.)
@export var last_update_time: float = 0.0

# Helper methods for common operations
func has_state(state: BlockStates) -> bool:
	return (state_flags & state) != 0

func add_state(state: BlockStates):
	state_flags |= state

func remove_state(state: BlockStates):
	state_flags &= ~state

func toggle_state(state: BlockStates):
	state_flags ^= state

# Temperature methods
func has_custom_temperature() -> bool:
	return not is_nan(temperature)

func get_temperature(default_temp: float = 20.0) -> float:
	return temperature if has_custom_temperature() else default_temp

func set_temperature(new_temp: float):
	temperature = new_temp
	last_update_time = Time.get_ticks_msec() * 0.001

# Friction methods
func has_custom_friction() -> bool:
	return not is_nan(custom_friction)

func get_friction(block_type: BlockType) -> float:
	return custom_friction if has_custom_friction() else block_type.friction

func set_friction(new_friction: float):
	custom_friction = new_friction

# Gravity methods
func has_local_gravity() -> bool:
	return local_gravity != Vector3.INF

func get_gravity(world_gravity: Vector3) -> Vector3:
	return local_gravity if has_local_gravity() else world_gravity

func set_gravity(new_gravity: Vector3):
	local_gravity = new_gravity

# Generic property override system
func set_property(property_name: String, value: Variant):
	if value == null:
		property_overrides.erase(property_name)
	else:
		property_overrides[property_name] = value

func get_property(property_name: String, default_value: Variant = null) -> Variant:
	return property_overrides.get(property_name, default_value)

func has_property(property_name: String) -> bool:
	return property_overrides.has(property_name)

# Magical effect management
func add_magical_effect(effect_id: int):
	if not magical_effects.has(effect_id):
		magical_effects.append(effect_id)

func remove_magical_effect(effect_id: int):
	magical_effects.erase(effect_id)

func has_magical_effect(effect_id: int) -> bool:
	return magical_effects.has(effect_id)

func clear_magical_effects():
	magical_effects.clear()

# Update time tracking
func mark_updated():
	last_update_time = Time.get_ticks_msec() * 0.001

func get_time_since_update() -> float:
	return (Time.get_ticks_msec() * 0.001) - last_update_time

# Memory optimization: check if this block needs dynamic storage
func is_default_state(block_type: BlockType) -> bool:
	if magical_charge != 0.0:
		return false
	if state_flags != BlockStates.NONE:
		return false
	if not magical_effects.is_empty():
		return false
	if has_custom_temperature() or has_custom_friction() or has_local_gravity():
		return false
	if not property_overrides.is_empty():
		return false
	return true

# Serialization optimization: pack common properties into bytes
func pack_to_bytes() -> PackedByteArray:
	var buffer = PackedByteArray()
	var stream = StreamPeerBuffer.new()
	stream.data_array = buffer
	
	# Pack common properties efficiently
	stream.put_32(state_flags)
	stream.put_float(magical_charge)
	
	# Pack optional properties with flags
	var has_flags: int = 0
	if has_custom_temperature():
		has_flags |= 1
	if has_custom_friction():
		has_flags |= 2
	if has_local_gravity():
		has_flags |= 4
	
	stream.put_8(has_flags)
	
	if has_flags & 1:
		stream.put_float(temperature)
	if has_flags & 2:
		stream.put_float(custom_friction)
	if has_flags & 4:
		stream.put_vector3(local_gravity)
	
	# Pack magical effects (assume max 255 effects per block)
	stream.put_8(magical_effects.size())
	for effect_id in magical_effects:
		stream.put_16(effect_id)
	
	# Pack property overrides count and data
	stream.put_16(property_overrides.size())
	for key in property_overrides:
		stream.put_var(key)
		stream.put_var(property_overrides[key])
	
	return buffer

func unpack_from_bytes(data: PackedByteArray) -> bool:
	if data.is_empty():
		return false
		
	var stream = StreamPeerBuffer.new()
	stream.data_array = data
	stream.seek(0)
	
	# Unpack common properties
	state_flags = stream.get_32()
	magical_charge = stream.get_float()
	
	# Unpack optional properties
	var has_flags = stream.get_8()
	
	if has_flags & 1:
		temperature = stream.get_float()
	else:
		temperature = NAN
		
	if has_flags & 2:
		custom_friction = stream.get_float()
	else:
		custom_friction = NAN
		
	if has_flags & 4:
		local_gravity = stream.get_vector3()
	else:
		local_gravity = Vector3.INF
	
	# Unpack magical effects
	var effect_count = stream.get_8()
	magical_effects.clear()
	for i in range(effect_count):
		magical_effects.append(stream.get_16())
	
	# Unpack property overrides
	var override_count = stream.get_16()
	property_overrides.clear()
	for i in range(override_count):
		var key = stream.get_var()
		var value = stream.get_var()
		property_overrides[key] = value
	
	return true
