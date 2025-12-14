# New Blocks Setup Guide - Stone, Logs, and Leaves

## Overview
This guide walks you through registering the new blocks (stone, logs, leaves) with all systems and setting up tree generation.

## Step 1: Verify Block IDs in Voxel Library

**IMPORTANT**: The blocks must be added to your `VoxelBlockyLibrary` in this exact order:
1. Air (ID 0)
2. Dirt (ID 1)
3. Grass (ID 2)
4. Sand (ID 3)
5. **Stone (ID 4)** ← Your new block
6. Wood (ID 5)
7. Iron (ID 6)
8. Glass (ID 7)
9. Water (ID 8)
10. Lava (ID 9)
11. **Log (ID 10)** ← Your new block
12. **Leaves (ID 11)** ← Your new block

### To Check/Update Your Library:
1. Open `Scripts/Tools/VoxelAtlasSetup.gd` in the editor
2. Run it (File → Run in Script Editor)
3. This will create/update `res://materials/voxel_library.tres` with all blocks in the correct order

**OR** manually ensure your `.tres` library file has models in this order.

## Step 2: Code Updates (Already Done)

The following files have been updated:

### ✅ BlockIDs.gd
- Added `LOG = 10` and `LEAVES = 11` to enum
- Added mappings for `block_id_to_item_id()` and `item_id_to_block_id()`

### ✅ StaticMaterialProperties.gd
- Added `configure_as_log()` function
- Added `configure_as_leaves()` function

### ✅ MaterialDatabase.gd
- Registered log material (ID 10)
- Registered leaves material (ID 11)

### ✅ SimpleWorldGenerator.gd
- Updated to generate **stone under dirt** (at depth > 8 blocks)
- Added tree generation system:
  - Trees spawn on grass blocks in non-desert biomes
  - Tree height: 4-6 blocks
  - Canopy radius: 2 blocks
  - Uses `LOG` blocks for trunk
  - Uses `LEAVES` blocks for canopy

## Step 3: Verify Your Voxel Library

**Critical**: Your voxel library must have the blocks in the correct order. If you manually added stone, logs, and leaves:

1. **Check the library file** (`res://materials/voxel_library.tres` or wherever your library is)
2. **Verify the model order** matches BlockIDs:
   - Model 0 = Air
   - Model 1 = Dirt
   - Model 2 = Grass
   - Model 3 = Sand
   - Model 4 = Stone ← Must be here
   - Model 5 = Wood
   - Model 6 = Iron
   - Model 7 = Glass
   - Model 8 = Water
   - Model 9 = Lava
   - Model 10 = Log ← Must be here
   - Model 11 = Leaves ← Must be here

3. **If order is wrong**, you need to:
   - Reorder models in the library file, OR
   - Run `VoxelAtlasSetup.gd` to regenerate the library

## Step 4: Test the Changes

1. **Create a new world** (or regenerate with Ctrl+R)
2. **Check for stone**: Dig down 9+ blocks - you should see stone instead of dirt
3. **Check for trees**: Look around grass areas - trees should spawn randomly
4. **Verify blocks**: Destroy a log or leaves block - should drop correct items

## Troubleshooting

### Trees Not Appearing
- Check that `tree_density` is set (default: 0.02 = 2% chance)
- Trees only spawn on grass blocks in non-desert biomes
- Make sure your library has LOG and LEAVES models at IDs 10 and 11

### Stone Not Appearing
- Stone only generates at depth > 8 blocks below surface
- Check that your library has STONE model at ID 4

### Wrong Blocks Appearing
- **Most likely cause**: Library model order doesn't match BlockIDs
- Solution: Reorder models in your library file or regenerate it

### Blocks Not Dropping Items
- Check `BlockIDs.block_id_to_item_id()` has mappings for log and leaves
- Verify `InventoryManager` has items registered for "log" and "leaves"

## Next Steps

If you want to customize:
- **Tree density**: Adjust `tree_density` in `SimpleWorldGenerator.gd`
- **Tree size**: Modify `tree_height` and `canopy_radius` in `_generate_tree()`
- **Stone depth**: Change the depth threshold (currently 8) in `_get_block_at()`
