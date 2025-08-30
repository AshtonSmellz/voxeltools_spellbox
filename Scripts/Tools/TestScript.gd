extends Node3D

func _ready():
	var library = VoxelBlockyLibrary.new()
	
	# Test creating models
	var empty = VoxelBlockyModelEmpty.new()
	var cube = VoxelBlockyModelCube.new()
	
	library.add_model(empty)  # ID 0
	library.add_model(cube)   # ID 1
	
	print("Library has ", library.get_model_count(), " models")
	print("Setup successful!")
