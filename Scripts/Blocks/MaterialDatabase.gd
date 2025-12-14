class_name MaterialDatabase
extends Resource

var materials: Dictionary = {}  # int -> StaticMaterialProperties

func _init():
	_initialize_default_materials()

func _initialize_default_materials():
	# IMPORTANT: These IDs must match BlockIDs enum
	# Air (ID: 0)
	var air = StaticMaterialProperties.new(BlockIDs.BlockID.AIR, "Air")
	air.configure_as_air()
	register_material(air)
	
	# Dirt (ID: 1)
	var dirt = StaticMaterialProperties.new(BlockIDs.BlockID.DIRT, "Dirt")
	dirt.configure_as_dirt()
	register_material(dirt)
	
	# Grass (ID: 2)
	var grass = StaticMaterialProperties.new(BlockIDs.BlockID.GRASS, "Grass")
	grass.configure_as_grass()
	register_material(grass)
	
	# Sand (ID: 3)
	var sand = StaticMaterialProperties.new(BlockIDs.BlockID.SAND, "Sand")
	sand.configure_as_sand()
	register_material(sand)
	
	# Stone (ID: 4)
	var stone = StaticMaterialProperties.new(BlockIDs.BlockID.STONE, "Stone")
	stone.configure_as_stone()
	register_material(stone)
	
	# Wood (ID: 5)
	var wood = StaticMaterialProperties.new(BlockIDs.BlockID.WOOD, "Wood")
	wood.configure_as_wood()
	register_material(wood)
	
	# Iron (ID: 6)
	var iron = StaticMaterialProperties.new(BlockIDs.BlockID.IRON, "Iron")
	iron.configure_as_iron()
	register_material(iron)
	
	# Glass (ID: 7)
	var glass = StaticMaterialProperties.new(BlockIDs.BlockID.GLASS, "Glass")
	glass.configure_as_glass()
	register_material(glass)
	
	# Water (ID: 8)
	var water = StaticMaterialProperties.new(BlockIDs.BlockID.WATER, "Water")
	water.configure_as_water()
	register_material(water)
	
	# Lava (ID: 9)
	var lava = StaticMaterialProperties.new(BlockIDs.BlockID.LAVA, "Lava")
	lava.configure_as_lava()
	register_material(lava)
	
	# Log (ID: 10)
	var log = StaticMaterialProperties.new(BlockIDs.BlockID.LOG, "Log")
	log.configure_as_log()
	register_material(log)
	
	# Leaves (ID: 11)
	var leaves = StaticMaterialProperties.new(BlockIDs.BlockID.LEAVES, "Leaves")
	leaves.configure_as_leaves()
	register_material(leaves)

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
