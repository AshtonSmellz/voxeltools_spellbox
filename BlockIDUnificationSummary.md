# Block ID Unification Summary

## Problem
Block IDs were inconsistent across the codebase:
- `SimpleWorldGenerator` used: 0=Air, 1=Dirt, 2=Grass, 3=Sand
- `MaterialDatabase` used: 0=Air, 1=Dirt, 2=Grass, 3=Sand, 4=Stone, 5=Wood, 6=Iron, 7=Glass, 8=Water, 9=Lava
- `VoxelAtlasSetup` created library with: 0=Air, 1=Stone, 2=Wood, 3=Iron, 4=Glass, 5=Water, 6=Lava, 7=Grass
- Hardcoded IDs in various places didn't match

This caused:
- Items not dropping correctly (wrong item IDs)
- Item icons not showing (items couldn't be found)
- Inconsistent behavior across systems

## Solution
Created unified `BlockIDs` system:

### New File: `Scripts/Blocks/BlockIDs.gd`
- Defines `BlockID` enum with all block types
- Provides `block_id_to_item_id()` mapping function
- Provides `item_id_to_block_id()` reverse mapping
- Single source of truth for all ID mappings

### Block ID Order (matches MaterialDatabase):
```
0 = AIR
1 = DIRT
2 = GRASS
3 = SAND
4 = STONE
5 = WOOD
6 = IRON
7 = GLASS
8 = WATER
9 = LAVA
```

## Files Updated

1. **Scripts/Blocks/BlockIDs.gd** (NEW)
   - Unified ID system with enum and mapping functions

2. **Scripts/Blocks/MaterialDatabase.gd**
   - Now uses `BlockIDs.BlockID.*` instead of hardcoded numbers
   - Ensures IDs match BlockIDs enum

3. **Scripts/Blocks/VoxelWorldManager.gd**
   - `_voxel_id_to_item_id()` now uses `BlockIDs.block_id_to_item_id()`
   - Melting/freezing functions use `BlockIDs.BlockID.*` constants

4. **Scripts/WorldGeneration/SimpleWorldGenerator.gd**
   - Removed local `BlockID` enum
   - Now uses `BlockIDs.BlockID.*` constants

5. **Scripts/character_controller.gd**
   - `_voxel_id_to_item_id()` now uses `BlockIDs.block_id_to_item_id()`

6. **Scripts/Tools/VoxelAtlasSetup.gd**
   - Updated model creation order to match BlockIDs
   - Added comments showing which BlockID each model represents

## Important Notes

### Voxel Library Setup
When creating/updating the voxel library, models MUST be added in BlockIDs order:
1. Air (ID 0)
2. Dirt (ID 1)
3. Grass (ID 2)
4. Sand (ID 3)
5. Stone (ID 4)
6. Wood (ID 5)
7. Iron (ID 6)
8. Glass (ID 7)
9. Water (ID 8)
10. Lava (ID 9)

### Item Icons
Items still need icons assigned. To add icons:
1. Create icon textures (can extract from block atlas)
2. Assign in `InventoryManager._initialize_item_database()`:
   ```gdscript
   dirt.icon = preload("res://textures/icons/dirt_icon.png")
   ```

### Testing
- Destroy blocks and verify correct items drop
- Check that item IDs match block IDs
- Verify items appear in inventory with correct names
- Item drops should now have proper item references (icons will show if assigned)

## Next Steps

1. **Update actual voxel library** - The `.tres` file needs to be regenerated with models in BlockIDs order
2. **Add item icons** - Extract or create icons from block textures
3. **Update BiomeWorldGenerator** - Should also use BlockIDs instead of local enum
4. **Update StructureGenerator** - Should use BlockIDs constants
