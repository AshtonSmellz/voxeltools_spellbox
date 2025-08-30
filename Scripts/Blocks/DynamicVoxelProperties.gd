class_name DynamicVoxelProperties
extends Resource

# Bit-packed dynamic properties (32 bits total)
# We'll store this in the voxel metadata system
@export var packed_data: int = 0

# Temperature lookup table (in Kelvin)
const TEMPERATURE_VALUES = [
	0.0, 50.0, 100.0, 150.0, 190.0, 210.0, 250.0, 270.0,
	290.0, 310.0, 330.0, 350.0, 370.0, 400.0, 450.0, 500.0,
	550.0, 600.0, 650.0, 700.0, 750.0, 800.0, 900.0, 1000.0,
	1250.0, 1500.0, 1750.0, 2000.0, 2250.0, 2500.0, 2750.0, 3000.0
]

# Bit layout constants
const TEMP_SHIFT = 0
const TEMP_MASK = 0x1F  # 5 bits

const CONDUCTIVE_SHIFT = 5
const CONDUCTIVE_MASK = 0x1  # 1 bit

const TOUGHNESS_SHIFT = 6
const TOUGHNESS_MASK = 0x7  # 3 bits

const ELASTICITY_SHIFT = 9
const ELASTICITY_MASK = 0x3  # 2 bits

const INTANGIBLE_SHIFT = 11
const INTANGIBLE_MASK = 0x1  # 1 bit

const MOISTURE_SHIFT = 12
const MOISTURE_MASK = 0x3  # 2 bits

const LOUDNESS_SHIFT = 14
const LOUDNESS_MASK = 0x3  # 2 bits

const HEAT_CAPACITY_SHIFT = 16
const HEAT_CAPACITY_MASK = 0xF  # 4 bits

const CHARGE_SHIFT = 20
const CHARGE_MASK = 0x7  # 3 bits

# Enums for property values
enum Toughness {
	FRAGILE = 0,
	VERY_WEAK = 1,
	WEAK = 2,
	WOOD = 3,
	STONE = 4,
	METAL = 5,
	DIAMOND = 6,
	INDESTRUCTIBLE = 7
}

enum Elasticity {
	BRITTLE = 0,
	RIGID = 1,
	PLIANT = 2,
	BOUNCY = 3
}

enum Moisture {
	DRY = 0,
	MOIST = 1,
	WET = 2,
	SOAKED = 3
}

enum Loudness {
	MUTED = 0,
	LOW = 1,
	NORMAL = 2,
	LOUD = 3
}

enum ChargeLevel {
	MAX_NEGATIVE = 0,  # -3
	NEGATIVE_2 = 1,    # -2
	NEGATIVE_1 = 2,    # -1
	NEUTRAL = 3,       # 0
	POSITIVE_1 = 4,    # 1
	POSITIVE_2 = 5,    # 2
	POSITIVE_3 = 6,    # 3
	MAX_POSITIVE = 7   # 4
}

func _init(data: int = 0):
	packed_data = data
	if packed_data == 0:
		set_defaults()

func set_defaults():
	set_temperature_index(8)  # Room temp (290K)
	set_toughness(Toughness.STONE)
	set_elasticity(Elasticity.RIGID)
	set_moisture(Moisture.DRY)
	set_loudness(Loudness.NORMAL)
	set_heat_capacity_index(7)  # Middle value
	set_charge_level(ChargeLevel.NEUTRAL)

# Static helper to create from voxel metadata
static func from_metadata(metadata: Variant) -> DynamicVoxelProperties:
	if metadata == null:
		return DynamicVoxelProperties.new()
	
	# Metadata can be stored as int directly
	if metadata is int:
		return DynamicVoxelProperties.new(metadata)
	# Or as a dictionary with packed_data
	elif metadata is Dictionary and metadata.has("props"):
		return DynamicVoxelProperties.new(metadata["props"])
	
	return DynamicVoxelProperties.new()

# Convert to metadata for storage in voxel
func to_metadata() -> int:
	return packed_data

# Temperature property
func get_temperature_index() -> int:
	return (packed_data >> TEMP_SHIFT) & TEMP_MASK

func set_temperature_index(value: int):
	packed_data = (packed_data & ~(TEMP_MASK << TEMP_SHIFT)) | ((value & TEMP_MASK) << TEMP_SHIFT)

func get_temperature_kelvin() -> float:
	var index = min(get_temperature_index(), 31)
	return TEMPERATURE_VALUES[index]

# Conductive property
func is_conductive() -> bool:
	return ((packed_data >> CONDUCTIVE_SHIFT) & CONDUCTIVE_MASK) == 1

func set_conductive(value: bool):
	if value:
		packed_data |= (CONDUCTIVE_MASK << CONDUCTIVE_SHIFT)
	else:
		packed_data &= ~(CONDUCTIVE_MASK << CONDUCTIVE_SHIFT)

# Toughness property
func get_toughness() -> Toughness:
	return (packed_data >> TOUGHNESS_SHIFT) & TOUGHNESS_MASK

func set_toughness(value: Toughness):
	packed_data = (packed_data & ~(TOUGHNESS_MASK << TOUGHNESS_SHIFT)) | (value << TOUGHNESS_SHIFT)

# Elasticity property
func get_elasticity() -> Elasticity:
	return (packed_data >> ELASTICITY_SHIFT) & ELASTICITY_MASK

func set_elasticity(value: Elasticity):
	packed_data = (packed_data & ~(ELASTICITY_MASK << ELASTICITY_SHIFT)) | (value << ELASTICITY_SHIFT)

# Intangible property
func is_intangible() -> bool:
	return ((packed_data >> INTANGIBLE_SHIFT) & INTANGIBLE_MASK) == 1

func set_intangible(value: bool):
	if value:
		packed_data |= (INTANGIBLE_MASK << INTANGIBLE_SHIFT)
	else:
		packed_data &= ~(INTANGIBLE_MASK << INTANGIBLE_SHIFT)

# Moisture property
func get_moisture() -> Moisture:
	return (packed_data >> MOISTURE_SHIFT) & MOISTURE_MASK

func set_moisture(value: Moisture):
	packed_data = (packed_data & ~(MOISTURE_MASK << MOISTURE_SHIFT)) | (value << MOISTURE_SHIFT)

# Loudness property
func get_loudness() -> Loudness:
	return (packed_data >> LOUDNESS_SHIFT) & LOUDNESS_MASK

func set_loudness(value: Loudness):
	packed_data = (packed_data & ~(LOUDNESS_MASK << LOUDNESS_SHIFT)) | (value << LOUDNESS_SHIFT)

# Heat Capacity property
func get_heat_capacity_index() -> int:
	return (packed_data >> HEAT_CAPACITY_SHIFT) & HEAT_CAPACITY_MASK

func set_heat_capacity_index(value: int):
	packed_data = (packed_data & ~(HEAT_CAPACITY_MASK << HEAT_CAPACITY_SHIFT)) | ((value & HEAT_CAPACITY_MASK) << HEAT_CAPACITY_SHIFT)

# Charge property
func get_charge_level() -> ChargeLevel:
	return (packed_data >> CHARGE_SHIFT) & CHARGE_MASK

func set_charge_level(value: ChargeLevel):
	packed_data = (packed_data & ~(CHARGE_MASK << CHARGE_SHIFT)) | (value << CHARGE_SHIFT)

func get_charge_value() -> int:
	return get_charge_level() - 3  # Convert to -3 to 4 range

# Create a copy with modifications
func duplicate_and_modify() -> DynamicVoxelProperties:
	var new_props = DynamicVoxelProperties.new(packed_data)
	return new_props

# Check if properties match another set
func equals(other: DynamicVoxelProperties) -> bool:
	return packed_data == other.packed_data

# Apply a modifier function
func apply_modifier(modifier: Callable, intensity: float = 1.0):
	modifier.call(self, intensity)
