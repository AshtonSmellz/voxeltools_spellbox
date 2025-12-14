# Texture Bleeding Fix Guide

## Problem
Adjacent tiles from the texture atlas are showing on blocks, causing texture bleeding/tiling issues.

## Root Causes
1. **Texture Filtering**: Linear filtering causes interpolation between adjacent pixels
2. **Missing UV Margins**: UV coordinates touching tile edges can sample adjacent tiles
3. **Texture Import Settings**: Mipmaps or filtering enabled in import settings
4. **Atlas Padding**: Texture atlas might not have padding between tiles

## Solutions

### 1. Material Settings (Already Applied)
The material is configured with:
- `texture_filter = TEXTURE_FILTER_NEAREST` ✓
- This prevents interpolation between pixels

### 2. Texture Import Settings (CRITICAL)
Check your texture atlas import settings in Godot:

1. Select your texture file (e.g., `BlockSpriteSheet.png`)
2. Go to Import tab
3. Set these settings:
   - **Filter**: OFF (unchecked) - This is critical!
   - **Mipmaps**: OFF or "Disable"
   - **Fix Alpha Border**: ON (checked)
   - **Compress**: Lossless or Disabled (for pixel art)

### 3. Texture Atlas Padding (Best Solution)
The most effective fix is to add 1-2 pixel padding around each tile in your texture atlas:

**Option A: Recreate Atlas with Padding**
- Add 1-2px border around each 16x16 tile
- This prevents any edge sampling issues
- Example: 16x16 tiles with 1px padding = 18x18 tiles per block

**Option B: Use UV Margins (If Voxel Tools Supports It)**
- Some versions of Voxel Tools support UV margin settings
- Check VoxelBlockyLibrary or VoxelBlockyModelCube for margin properties

### 4. Verify Current Settings

Check `materials/voxel_atlas_material.tres`:
- Should have `texture_filter = 0` (NEAREST)
- Should reference your texture atlas

Check texture import:
- Open texture in Godot
- Import tab → Filter: OFF
- Import tab → Mipmaps: OFF

## Quick Fix Steps

1. **Open your texture atlas** in Godot (e.g., `BlockSpriteSheet.png`)
2. **Click Import tab**
3. **Uncheck "Filter"** - This is the most important step!
4. **Click "Reimport"**
5. **Test in-game** - Bleeding should be reduced or eliminated

If bleeding persists:
- Check that the material is using the correct texture
- Verify the atlas has proper spacing between tiles
- Consider recreating the atlas with padding

## Testing

After applying fixes:
1. Look at blocks up close - edges should be crisp
2. Check adjacent blocks - no texture bleeding between them
3. Verify all block types render correctly
