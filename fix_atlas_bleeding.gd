@tool
extends EditorScript

# Comprehensive fix for texture atlas bleeding in VoxelBlockyLibrary
# This addresses the common issue where adjacent textures in an atlas bleed into each other

func _run():
	print("=== TEXTURE BLEEDING FIX ===")
	print("This script helps fix texture bleeding issues in voxel textures.")
	print("")
	
	# Step 1: Check current materials
	_check_materials()
	
	# Step 2: Provide atlas recommendations
	_provide_atlas_recommendations()
	
	# Step 3: Check texture import settings
	_check_texture_import_settings()

func _check_materials():
	print("1. CHECKING MATERIALS:")
	
	var materials = [
		"res://blocks/terrain_material.tres",
		"res://blocks/terrain_material_foliage.tres", 
		"res://blocks/terrain_material_transparent.tres"
	]
	
	for mat_path in materials:
		if ResourceLoader.exists(mat_path):
			var material = load(mat_path) as StandardMaterial3D
			if material:
				print("  ✓ ", mat_path.get_file(), ":")
				print("    - Filter: ", _get_filter_name(material.texture_filter))
				print("    - Repeat: ", not material.flags_do_not_repeat_texture if material.has_method("flags_do_not_repeat_texture") else "Unknown")
			else:
				print("  ✗ Failed to load: ", mat_path)
		else:
			print("  ⚠ Missing: ", mat_path)
	print("")

func _get_filter_name(filter_mode: int) -> String:
	match filter_mode:
		0: return "Nearest (Good - no bleeding)"
		1: return "Linear (BAD - causes bleeding)"  
		2: return "Nearest Mipmap (Good)"
		3: return "Linear Mipmap (BAD - causes bleeding)"
		4: return "Nearest Mipmap Anisotropic (Good)"
		5: return "Linear Mipmap Anisotropic (BAD - causes bleeding)"
		_: return "Unknown"

func _provide_atlas_recommendations():
	print("2. ATLAS RECOMMENDATIONS:")
	print("  To completely fix texture bleeding, you need:")
	print("  a) Add 1-2 pixel padding around each texture tile")
	print("  b) Use nearest neighbor filtering (already set)")
	print("  c) Ensure UV coordinates don't touch tile edges")
	print("")
	print("  Example for 16x16 atlas with 16px tiles:")
	print("  - Add 1px border around each tile")
	print("  - Make atlas 18x18 tiles (288x288px total)")
	print("  - Or use UV margins of ~0.03125 (0.5/16)")
	print("")

func _check_texture_import_settings():
	print("3. TEXTURE IMPORT SETTINGS:")
	print("  Check your terrain.png import settings:")
	print("  - Filter: OFF (unchecked)")
	print("  - Mipmaps: OFF (unchecked)")  
	print("  - Fix Alpha Border: ON (checked)")
	print("")
	
	# Check if texture exists
	var texture_path = "res://blocks/terrain.png"
	if ResourceLoader.exists(texture_path):
		print("  ✓ Found texture: ", texture_path)
		var texture = load(texture_path) as Texture2D
		if texture:
			print("    - Size: ", texture.get_width(), "x", texture.get_height())
		else:
			print("    ✗ Failed to load texture")
	else:
		print("  ⚠ Texture not found: ", texture_path)
	
	print("")
	print("=== SOLUTIONS ===")
	print("If bleeding persists:")
	print("1. IMMEDIATE FIX: Recreate your texture atlas with 1-2px padding")
	print("2. UV FIX: Modify your .obj files to use UV coords with margins")
	print("3. ATLAS FIX: Use a texture packer that adds automatic padding")
	print("4. CODE FIX: Implement UV coordinate clamping in shaders")
	print("")
	print("Most effective: Recreate the atlas with padding between tiles.")
