class_name MaterialDatabase
extends Resource

var materials: Dictionary = {}  # int -> StaticMaterialProperties

func _init():
	_initialize_default_materials()

func _initialize_default_materials():
	# Air (ID: 0)
	var air = StaticMaterialProperties.new(0, "Air")
	air.configure_as_air()
	register_material(air)
	
	# Stone (ID: 1)
	var stone = StaticMaterialProperties.new(1, "Stone")
	stone.configure_as_stone()
	register_material(stone)
	
	# Wood (ID: 2)
	var wood = StaticMaterialProperties.new(2, "Wood")
	wood.configure_as_wood()
	register_material(wood)
	
	# Iron (ID: 3)
	var iron = StaticMaterialProperties.new(3, "Iron")
	iron.configure_as_iron()
	register_material(iron)
	
	# Glass (ID: 4)
	var glass = StaticMaterialProperties.new(4, "Glass")
	glass.material_name = "Glass"
	glass.density = 2.5
	glass.melting_temp = 1700.0
	glass.freezing_temp = 1700.0
	glass.conductivity_breakdown_temperature = INF
	glass.transmutation_value = 3.0
	glass.default_dynamic_properties.set_toughness(DynamicVoxelProperties.Toughness.FRAGILE)
	glass.default_dynamic_properties.set_elasticity(DynamicVoxelProperties.Elasticity.BRITTLE)
	glass.base_color = Color(0.8, 0.9, 1.0, 0.3)
	glass.base_reflectivity = 0.8
	register_material(glass)
	
	# Water (ID: 5)
	var water = StaticMaterialProperties.new(5, "Water")
	water.material_name = "Water"
	water.density = 1.0
	water.melting_temp = 273.0
	water.freezing_temp = 273.0
	water.conductivity_breakdown_temperature = INF
	water.transmutation_value = 1.0
	water.default_dynamic_properties.set_toughness(DynamicVoxelProperties.Toughness.FRAGILE)
	water.default_dynamic_properties.set_moisture(DynamicVoxelProperties.Moisture.SOAKED)
	water.base_color = Color(0.2, 0.4, 0.8, 0.7)
	register_material(water)
	
	# Lava (ID: 6)
	var lava = StaticMaterialProperties.new(6, "Lava")
	lava.material_name = "Lava"
	lava.density = 3.0
	lava.melting_temp = INF  # Already melted
	lava.freezing_temp = 1000.0
	lava.conductivity_breakdown_temperature = 0.0
	lava.transmutation_value = 10.0
	lava.default_dynamic_properties.set_temperature_index(24)  # 1250K
	lava.default_dynamic_properties.set_conductive(true)
	lava.base_color = Color(1.0, 0.3, 0.0)
	register_material(lava)

func register_material(material: StaticMaterialProperties):
	materials[material.material_id] = material

func get_material(id: int) -> StaticMaterialProperties:
	if materials.has(id):
		return materials[id]
	return null

func get_all_materials() -> Array:
	return materials.values()

func create_custom_material(id: int, name: String) -> StaticMaterialProperties:
	var material = StaticMaterialProperties.new(id, name)
	register_material(material)
	return material

# Helper function to check if a material should change state
func check_state_change(voxel_props: DynamicVoxelProperties, material: StaticMaterialProperties) -> Dictionary:
	var result = {
		"should_melt": false,
		"should_freeze": false,
		"should_become_conductive": false,
		"should_destroy": false
	}
	
	var temp = voxel_props.get_temperature_kelvin()
	
	# Check melting
	if temp >= material.melting_temp:
		result.should_melt = true
	
	# Check freezing
	if temp <= material.freezing_temp:
		result.should_freeze = true
	
	# Check conductivity breakdown
	if temp >= material.conductivity_breakdown_temperature and not voxel_props.is_conductive():
		result.should_become_conductive = true
	
	# Check destruction temperature
	if temp >= 3000.0:
		result.should_destroy = true
	
	return result
