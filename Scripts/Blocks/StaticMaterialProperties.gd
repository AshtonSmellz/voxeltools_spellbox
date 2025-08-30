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
	default_dynamic_properties.set_intangible(true)

func configure_as_stone():
	material_name = "Stone"
	density = 2.5
	melting_temp = 1473.0
	freezing_temp = 0.0
	conductivity_breakdown_temperature = INF
	transmutation_value = 1.0
	default_dynamic_properties.set_toughness(DynamicVoxelProperties.Toughness.STONE)
	base_color = Color(0.5, 0.5, 0.5)

func configure_as_wood():
	material_name = "Wood"
	density = 0.6
	melting_temp = 573.0  # Burns instead of melts
	freezing_temp = 0.0
	conductivity_breakdown_temperature = 573.0
	transmutation_value = 2.0
	default_dynamic_properties.set_toughness(DynamicVoxelProperties.Toughness.WOOD)
	default_dynamic_properties.set_elasticity(DynamicVoxelProperties.Elasticity.PLIANT)
	base_color = Color(0.55, 0.27, 0.07)

func configure_as_iron():
	material_name = "Iron"
	density = 7.8
	melting_temp = 1811.0
	freezing_temp = 1811.0
	conductivity_breakdown_temperature = 0.0  # Always conductive
	transmutation_value = 5.0
	default_dynamic_properties.set_conductive(true)
	default_dynamic_properties.set_toughness(DynamicVoxelProperties.Toughness.METAL)
	base_color = Color(0.7, 0.7, 0.7)

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
