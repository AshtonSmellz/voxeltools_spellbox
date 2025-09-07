class_name StructureGenerator
extends RefCounted

# Generates complex structures using stairs, rails, and other blocks
# This complements the main world generator with placed structures

enum BlockID {
	AIR = 0,
	DIRT = 1, 
	GRASS = 2,
	LOG_X = 3,
	LOG_Y = 4, 
	LOG_Z = 5,
	STAIRS_NX = 6,
	PLANKS = 7,
	TALL_GRASS = 8,
	STAIRS_NZ = 9,
	STAIRS_PX = 10,
	STAIRS_PZ = 11,
	GLASS = 12,
	WATER_TOP = 13,
	WATER_FULL = 14,
	RAIL_X = 15,
	RAIL_Z = 16,
	RAIL_TURN_NX = 17,
	RAIL_TURN_PX = 18,
	RAIL_TURN_NZ = 19,
	RAIL_TURN_PZ = 20,
	RAIL_SLOPE_NX = 21,
	RAIL_SLOPE_PX = 22,
	RAIL_SLOPE_NZ = 23,
	RAIL_SLOPE_PZ = 24,
	LEAVES = 25,
	DEAD_SHRUB = 26
}

static func place_structure(voxel_tool: VoxelToolTerrain, structure_type: String, position: Vector3i):
	match structure_type:
		"cabin":
			_place_cabin(voxel_tool, position)
		"mine_entrance":
			_place_mine_entrance(voxel_tool, position)
		"bridge":
			_place_bridge(voxel_tool, position)
		"rail_track":
			_place_rail_track(voxel_tool, position)

static func _place_cabin(voxel_tool: VoxelToolTerrain, pos: Vector3i):
	# Simple 5x5x4 cabin using planks and glass
	for x in range(5):
		for z in range(5):
			for y in range(4):
				var current_pos = pos + Vector3i(x, y, z)
				
				# Walls
				if x == 0 or x == 4 or z == 0 or z == 4:
					if y == 0:  # Foundation
						voxel_tool.set_voxel(current_pos, BlockID.PLANKS)
					elif y <= 2:  # Walls with windows
						if (x == 2 and z == 0) or (x == 4 and z == 2):
							voxel_tool.set_voxel(current_pos, BlockID.GLASS)  # Windows
						else:
							voxel_tool.set_voxel(current_pos, BlockID.LOG_Y)  # Wall logs
					else:  # Roof
						voxel_tool.set_voxel(current_pos, BlockID.PLANKS)
				
				# Door
				elif x == 2 and z == 0 and y <= 2:
					voxel_tool.set_voxel(current_pos, BlockID.AIR)
				
				# Floor
				elif y == 0:
					voxel_tool.set_voxel(current_pos, BlockID.PLANKS)

static func _place_mine_entrance(voxel_tool: VoxelToolTerrain, pos: Vector3i):
	# Mine shaft entrance with stairs going down
	
	# Clear entrance area
	for x in range(3):
		for z in range(3):
			for y in range(3):
				voxel_tool.set_voxel(pos + Vector3i(x, y, z), BlockID.AIR)
	
	# Support beams
	voxel_tool.set_voxel(pos + Vector3i(0, 0, 0), BlockID.LOG_Y)
	voxel_tool.set_voxel(pos + Vector3i(2, 0, 0), BlockID.LOG_Y)
	voxel_tool.set_voxel(pos + Vector3i(0, 0, 2), BlockID.LOG_Y)
	voxel_tool.set_voxel(pos + Vector3i(2, 0, 2), BlockID.LOG_Y)
	
	# Stairs going down
	for i in range(5):
		var stair_pos = pos + Vector3i(1, -i, 1 + i)
		voxel_tool.set_voxel(stair_pos, BlockID.STAIRS_NZ)
		
		# Clear air above stairs
		voxel_tool.set_voxel(stair_pos + Vector3i(0, 1, 0), BlockID.AIR)
		voxel_tool.set_voxel(stair_pos + Vector3i(0, 2, 0), BlockID.AIR)

static func _place_bridge(voxel_tool: VoxelToolTerrain, pos: Vector3i):
	# Simple bridge using planks and log supports
	var bridge_length = 10
	
	for i in range(bridge_length):
		var bridge_pos = pos + Vector3i(i, 0, 0)
		
		# Bridge deck
		voxel_tool.set_voxel(bridge_pos, BlockID.PLANKS)
		voxel_tool.set_voxel(bridge_pos + Vector3i(0, 0, 1), BlockID.PLANKS)
		voxel_tool.set_voxel(bridge_pos + Vector3i(0, 0, 2), BlockID.PLANKS)
		
		# Support posts every 3 blocks
		if i % 3 == 0:
			for j in range(1, 4):  # Supports going down
				voxel_tool.set_voxel(bridge_pos + Vector3i(0, -j, 0), BlockID.LOG_Y)
				voxel_tool.set_voxel(bridge_pos + Vector3i(0, -j, 2), BlockID.LOG_Y)
		
		# Railings
		voxel_tool.set_voxel(bridge_pos + Vector3i(0, 1, -1), BlockID.PLANKS)
		voxel_tool.set_voxel(bridge_pos + Vector3i(0, 1, 3), BlockID.PLANKS)

static func _place_rail_track(voxel_tool: VoxelToolTerrain, pos: Vector3i):
	# Railway track with turns and slopes
	var track_positions = [
		{pos = Vector3i(0, 0, 0), block = BlockID.RAIL_X},
		{pos = Vector3i(1, 0, 0), block = BlockID.RAIL_X},
		{pos = Vector3i(2, 0, 0), block = BlockID.RAIL_X},
		{pos = Vector3i(3, 0, 0), block = BlockID.RAIL_TURN_PX},
		{pos = Vector3i(3, 0, 1), block = BlockID.RAIL_Z},
		{pos = Vector3i(3, 0, 2), block = BlockID.RAIL_Z},
		{pos = Vector3i(3, 0, 3), block = BlockID.RAIL_SLOPE_NZ},
		{pos = Vector3i(3, 1, 4), block = BlockID.RAIL_Z},
		{pos = Vector3i(3, 1, 5), block = BlockID.RAIL_Z},
		{pos = Vector3i(3, 1, 6), block = BlockID.RAIL_TURN_NZ},
		{pos = Vector3i(2, 1, 6), block = BlockID.RAIL_X},
		{pos = Vector3i(1, 1, 6), block = BlockID.RAIL_X},
		{pos = Vector3i(0, 1, 6), block = BlockID.RAIL_X}
	]
	
	for track_data in track_positions:
		var rail_pos = pos + track_data.pos
		# Place rail
		voxel_tool.set_voxel(rail_pos, track_data.block)
		
		# Ensure there's a foundation block
		voxel_tool.set_voxel(rail_pos + Vector3i(0, -1, 0), BlockID.PLANKS)