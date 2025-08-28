extends Resource
class_name BlockType

# Static properties that never change per block type
@export var id: int
@export var name: String
@export var texture_id: int

# Physical properties
@export var density: float = 1.0
@export var hardness: float = 1.0
@export var friction: float = 0.8
@export var restitution: float = 0.2  # bounciness
@export var specific_heat: float = 1.0  # J/g°C
@export var thermal_conductivity: float = 0.5  # W/m°C
@export var electrical_conductivity: float = 0.0  # S/m
@export var melting_point: float = 1000.0  # °C
@export var freezing_point: float = 0.0  # °C

# Magical properties
@export var magical_conductivity: float = 0.0  # How well it conducts magic
@export var magical_resistance: float = 1.0  # Resistance to magical effects
@export var magical_affinity: Dictionary = {}  # element_type: affinity_value

# Behavior flags (use bitmasks for performance)
enum BlockFlags {
	NONE = 0,
	SOLID = 1,
	LIQUID = 2,
	GAS = 4,
	TRANSPARENT = 8,
	LIGHT_SOURCE = 16,
	FLAMMABLE = 32,
	CONDUCTIVE = 64,
	MAGNETIC = 128,
	ORGANIC = 256,
	CRYSTALLINE = 512
}
@export var flags: int = BlockFlags.SOLID

# Tool interaction
@export var tool_effectiveness: Dictionary = {}  # tool_type: effectiveness_multiplier
@export var drop_table: Array[BlockDrop] = []

# Environmental
@export var light_emission: int = 0  # 0-15 light level
@export var light_absorption: float = 1.0  # 0.0 = transparent, 1.0 = opaque

# Performance optimization: frequently accessed properties as separate variables
var is_solid: bool
var is_transparent: bool
var is_liquid: bool

func _init():
	_cache_common_flags()

func _cache_common_flags():
	is_solid = (flags & BlockFlags.SOLID) != 0
	is_transparent = (flags & BlockFlags.TRANSPARENT) != 0
	is_liquid = (flags & BlockFlags.LIQUID) != 0

# Helper methods for common queries
func has_flag(flag: BlockFlags) -> bool:
	return (flags & flag) != 0

func get_tool_effectiveness(tool_type: String) -> float:
	return tool_effectiveness.get(tool_type, 1.0)

func can_conduct_magic() -> bool:
	return magical_conductivity > 0.0

func get_affinity_for_element(element: String) -> float:
	return magical_affinity.get(element, 0.0)
