class_name StaticMaterialProperties
extends Resource

# Material identification
@export var material_id: int = 0
@export var material_name: String = ""

# Static thermal properties
@export var conductivity_breakdown_temperature: float = 0.0
@export var melting_temp: float = 0.0
@export var freezing_temp: float = 0.0
@export var transmutation_value: float = 0.0

# Default values for dynamic properties
@export var default_dynamic_properties: DynamicVoxelProperties

# Base physical properties
@export var density: float = 1.0
@export var base_heat_capacity: float = 1.0
@export var thermal_conductivity: float = 0.1

# Visual/Audio properties
@export var base_color: Color = Color.WHITE
@export var texture_path: String = ""
@export var base_reflectivity: float = 0.0

func _init(id: int = 0, name: String = ""):
	material_id = id
	material_name = name
	default_dynamic_properties = DynamicVoxelProperties.new()

func configure_as_air():
	material_name = "Air"
	density = 0.0
	melting_temp = INF
	freezing_temp = -INF
	base_heat_capacity = 1.0  # Standard air heat capacity
	thermal_conductivity = 0.025  # Very low thermal conductivity (air)
	default_dynamic_properties.set_intangible(true)
	default_dynamic_properties.set_friction_level(DynamicVoxelProperties.FrictionLevel.VERY_LOW)
	default_dynamic_properties.set_gravity_level(DynamicVoxelProperties.GravityLevel.NORMAL)

func configure_as_stone():
	material_name = "Stone"
	density = 2.5
	melting_temp = 1473.0
	freezing_temp = 0.0
	conductivity_breakdown_temperature = INF
	transmutation_value = 1.0
	base_heat_capacity = 0.92  # Moderate heat capacity
	thermal_conductivity = 2.0  # Moderate thermal conductivity
	default_dynamic_properties.set_toughness(DynamicVoxelProperties.Toughness.STONE)
	default_dynamic_properties.set_friction_level(DynamicVoxelProperties.FrictionLevel.HIGH)
	base_color = Color(0.5, 0.5, 0.5)

func configure_as_wood():
	material_name = "Wood"
	density = 0.6
	melting_temp = 573.0  # Burns instead of melts
	freezing_temp = 0.0
	conductivity_breakdown_temperature = 573.0
	transmutation_value = 2.0
	base_heat_capacity = 1.7  # Higher heat capacity (wood)
	thermal_conductivity = 0.15  # Very low thermal conductivity
	default_dynamic_properties.set_toughness(DynamicVoxelProperties.Toughness.WOOD)
	default_dynamic_properties.set_elasticity(DynamicVoxelProperties.Elasticity.PLIANT)
	default_dynamic_properties.set_friction_level(DynamicVoxelProperties.FrictionLevel.MODERATE)
	base_color = Color(0.55, 0.27, 0.07)

func configure_as_iron():
	material_name = "Iron"
	density = 7.8
	melting_temp = 1811.0
	freezing_temp = 1811.0
	conductivity_breakdown_temperature = 0.0  # Always conductive
	transmutation_value = 5.0
	base_heat_capacity = 0.45  # Lower heat capacity (metals heat/cool quickly)
	thermal_conductivity = 80.0  # High thermal conductivity
	default_dynamic_properties.set_conductive(true)
	default_dynamic_properties.set_toughness(DynamicVoxelProperties.Toughness.METAL)
	default_dynamic_properties.set_friction_level(DynamicVoxelProperties.FrictionLevel.HIGH)
	base_color = Color(0.7, 0.7, 0.7)

func configure_as_dirt():
	material_name = "Dirt"
	density = 1.5
	melting_temp = 1500.0
	freezing_temp = 273.0
	conductivity_breakdown_temperature = 800.0
	transmutation_value = 1.0
	base_heat_capacity = 1.2  # Moderate heat capacity
	thermal_conductivity = 0.3  # Low thermal conductivity
	default_dynamic_properties.set_toughness(DynamicVoxelProperties.Toughness.STONE)
	default_dynamic_properties.set_elasticity(DynamicVoxelProperties.Elasticity.PLIANT)
	default_dynamic_properties.set_friction_level(DynamicVoxelProperties.FrictionLevel.MODERATE)
	default_dynamic_properties.set_moisture(DynamicVoxelProperties.Moisture.MOIST)
	base_color = Color(0.4, 0.3, 0.2)

func configure_as_grass():
	material_name = "Grass"
	density = 1.3
	melting_temp = 800.0  # Burns easily
	freezing_temp = 273.0
	conductivity_breakdown_temperature = 600.0
	transmutation_value = 1.5
	base_heat_capacity = 1.5  # Higher heat capacity (organic matter)
	thermal_conductivity = 0.2  # Very low thermal conductivity
	default_dynamic_properties.set_toughness(DynamicVoxelProperties.Toughness.WEAK)
	default_dynamic_properties.set_elasticity(DynamicVoxelProperties.Elasticity.BOUNCY)
	default_dynamic_properties.set_friction_level(DynamicVoxelProperties.FrictionLevel.NORMAL)
	default_dynamic_properties.set_moisture(DynamicVoxelProperties.Moisture.WET)
	base_color = Color(0.2, 0.7, 0.2)

func configure_as_sand():
	material_name = "Sand"
	density = 1.6
	melting_temp = 1700.0  # High melting point (becomes glass)
	freezing_temp = 273.0
	conductivity_breakdown_temperature = 1000.0
	transmutation_value = 2.0
	base_heat_capacity = 0.8  # Lower heat capacity
	thermal_conductivity = 0.5  # Moderate thermal conductivity
	default_dynamic_properties.set_toughness(DynamicVoxelProperties.Toughness.VERY_WEAK)
	default_dynamic_properties.set_elasticity(DynamicVoxelProperties.Elasticity.RIGID)
	default_dynamic_properties.set_friction_level(DynamicVoxelProperties.FrictionLevel.LOW)
	base_color = Color(0.9, 0.8, 0.6)

func configure_as_glass():
	material_name = "Glass"
	density = 2.5
	melting_temp = 1700.0
	freezing_temp = 1700.0
	conductivity_breakdown_temperature = INF
	transmutation_value = 3.0
	base_heat_capacity = 0.84  # Moderate heat capacity
	thermal_conductivity = 1.0  # Low thermal conductivity
	default_dynamic_properties.set_toughness(DynamicVoxelProperties.Toughness.FRAGILE)
	default_dynamic_properties.set_elasticity(DynamicVoxelProperties.Elasticity.BRITTLE)
	default_dynamic_properties.set_friction_level(DynamicVoxelProperties.FrictionLevel.NORMAL)
	base_color = Color(0.8, 0.9, 1.0, 0.3)
	base_reflectivity = 0.8

func configure_as_water():
	material_name = "Water"
	density = 1.0
	melting_temp = 273.0
	freezing_temp = 273.0
	conductivity_breakdown_temperature = INF
	transmutation_value = 1.0
	base_heat_capacity = 4.18  # Very high heat capacity (water)
	thermal_conductivity = 0.6  # Moderate thermal conductivity
	default_dynamic_properties.set_toughness(DynamicVoxelProperties.Toughness.FRAGILE)
	default_dynamic_properties.set_moisture(DynamicVoxelProperties.Moisture.SOAKED)
	default_dynamic_properties.set_friction_level(DynamicVoxelProperties.FrictionLevel.VERY_LOW)
	default_dynamic_properties.set_gravity_level(DynamicVoxelProperties.GravityLevel.NORMAL)
	base_color = Color(0.2, 0.4, 0.8, 0.7)

func configure_as_lava():
	material_name = "Lava"
	density = 3.0
	melting_temp = INF  # Already melted
	freezing_temp = 1000.0
	conductivity_breakdown_temperature = 0.0
	transmutation_value = 10.0
	base_heat_capacity = 1.2  # Moderate heat capacity
	thermal_conductivity = 2.0  # Higher thermal conductivity (molten rock)
	default_dynamic_properties.set_temperature_index(24)  # 1250K
	default_dynamic_properties.set_conductive(true)
	default_dynamic_properties.set_friction_level(DynamicVoxelProperties.FrictionLevel.VERY_LOW)
	base_color = Color(1.0, 0.3, 0.0)

# Helper function to create a copy with same properties
func duplicate_properties() -> StaticMaterialProperties:
	var copy = StaticMaterialProperties.new(material_id, material_name)
	copy.conductivity_breakdown_temperature = conductivity_breakdown_temperature
	copy.melting_temp = melting_temp
	copy.freezing_temp = freezing_temp
	copy.transmutation_value = transmutation_value
	copy.density = density
	copy.base_heat_capacity = base_heat_capacity
	copy.thermal_conductivity = thermal_conductivity
	copy.base_color = base_color
	copy.texture_path = texture_path
	copy.base_reflectivity = base_reflectivity
	copy.default_dynamic_properties = default_dynamic_properties.duplicate_and_modify()
	return copy

# Check if this material can transmute to another
func can_transmute_to(other_material: StaticMaterialProperties) -> bool:
	# Transmutation rules - customize as needed
	if transmutation_value <= 0:
		return false
	
	var value_difference = abs(other_material.transmutation_value - transmutation_value)
	return value_difference <= 2.0  # Can only transmute to similar value materials

# Get the material state at a given temperature
func get_state_at_temperature(temp_kelvin: float) -> String:
	if temp_kelvin >= melting_temp:
		return "liquid"
	elif temp_kelvin <= freezing_temp:
		return "solid"
	else:
		return "normal"
