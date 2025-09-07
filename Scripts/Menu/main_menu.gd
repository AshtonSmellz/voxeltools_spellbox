extends Control

@onready var _ip_line_edit: LineEdit = \
	$CenterContainer/Multiplayer/MarginContainer/VBoxContainer/HBoxContainer/IP
@onready var _port_spinbox: SpinBox = \
	$CenterContainer/Multiplayer/MarginContainer/VBoxContainer/HBoxContainer/Port
@onready var _upnp_checkbox: CheckBox = \
	$CenterContainer/Multiplayer/MarginContainer/VBoxContainer/UPNPCheckbox

@onready var homescreenContainer = $CenterContainer/HomeScreen
@onready var characterSelectContainer = $CenterContainer/CharacterSelect
@onready var worldSelectContainer = $CenterContainer/WorldSelect
@onready var multiplayerContainer = $CenterContainer/Multiplayer
@onready var settingsContainer = $CenterContainer/Settings
@onready var creditsContainer = $CenterContainer/Credits

# Game world container (created programmatically)
var gameWorldContainer: Control

# Game state tracking
var selected_character: CharacterData
var selected_world_id: String
var selected_world_data: WorldData
var game_mode: String = "" # "singleplayer", "host", or "client"

# Network state
var is_connected: bool = false
var is_hosting: bool = false
var use_upnp: bool = false

# Signals that match the existing blocky game system
signal singleplayer_requested()
signal connect_to_server_requested(ip: String, port: int)
signal host_server_requested(port: int, use_upnp: bool)
signal upnp_toggled(pressed: bool)
signal game_ready_to_start(character: CharacterData, world_id: String, world_data: WorldData, mode: String)

func _ready():
	# Create game world container
	_create_game_world_container()
	
	# Connect character select signals
	var character_select = characterSelectContainer
	if character_select.has_signal("character_chosen"):
		character_select.character_chosen.connect(_on_character_chosen)
	if character_select.has_signal("back_pressed"):
		character_select.back_pressed.connect(_on_character_back_pressed)
	
	# Connect world select signals
	var world_select = worldSelectContainer
	if world_select.has_signal("world_chosen"):
		world_select.world_chosen.connect(_on_world_chosen)
	if world_select.has_signal("back_pressed"):
		world_select.back_pressed.connect(_on_world_back_pressed)
		
	# Connect game ready signal
	game_ready_to_start.connect(_on_game_ready_to_start)

# Home Screen Navigation
func _on_singleplayer_pressed() -> void:
	print("Starting singleplayer flow")
	game_mode = "singleplayer"
	is_connected = true  # Singleplayer is always "connected"
	is_hosting = true    # Singleplayer is hosting locally
	_navigate_to_character_select()

func _on_multiplayer_pressed() -> void:
	print("Showing multiplayer options")
	_hide_all_containers()
	multiplayerContainer.visible = true

func _on_settings_pressed() -> void:
	_hide_all_containers()
	settingsContainer.visible = true

func _on_quit_pressed() -> void:
	get_tree().quit()

# Multiplayer Network Handling
func _on_host_server_button_pressed():
	print("Attempting to host server...")
	game_mode = "host"
	var port = int(_port_spinbox.value)
	use_upnp = _upnp_checkbox.button_pressed
	
	# Emit signal for the main game to handle networking
	host_server_requested.emit(port, use_upnp)

func _on_connect_to_server_button_pressed():
	var ip = _ip_line_edit.text.strip_edges()
	if ip.is_empty():
		print("Please enter a valid IP address")
		return
	
	print("Attempting to connect to server: ", ip, ":", _port_spinbox.value)
	game_mode = "client"
	var port = int(_port_spinbox.value)
	
	# Emit signal for the main game to handle networking
	connect_to_server_requested.emit(ip, port)

func _on_upnp_checkbox_toggled(button_pressed: bool):
	upnp_toggled.emit(button_pressed)

# Network status callbacks (to be called by main.gd)
func on_server_started_successfully():
	print("Server started successfully")
	is_connected = true
	is_hosting = true
	_navigate_to_character_select()

func on_server_start_failed(error_message: String):
	print("Failed to start server: ", error_message)
	_show_error_dialog("Failed to Start Server", error_message)

func on_connected_to_server():
	print("Connected to server successfully")
	is_connected = true
	is_hosting = false
	_navigate_to_character_select()

func on_connection_failed(error_message: String):
	print("Failed to connect to server: ", error_message)
	_show_error_dialog("Connection Failed", error_message)

func on_disconnected_from_server():
	print("Disconnected from server")
	is_connected = false
	is_hosting = false
	_reset_to_multiplayer_menu()

# Character Select Navigation
func _navigate_to_character_select():
	_hide_all_containers()
	characterSelectContainer.visible = true
	
	# Refresh the character list when showing
	var character_select = characterSelectContainer
	if character_select.has_method("refresh_character_list"):
		character_select.refresh_character_list()

func _on_character_chosen(character_data: CharacterData):
	print("Character chosen: ", character_data.name, " for ", game_mode)
	selected_character = character_data
	
	if game_mode == "singleplayer" or game_mode == "host":
		# Host or singleplayer chooses world
		_navigate_to_world_select()
	else:
		# Client waits for host to choose world
		_wait_for_host_world_selection()

func _on_character_back_pressed():
	if is_connected and game_mode != "singleplayer":
		# If we're in multiplayer, go back to multiplayer menu but stay connected
		selected_character = null
		_hide_all_containers()
		multiplayerContainer.visible = true
	else:
		# Reset everything and go to home
		_reset_and_return_home()

# World Select Navigation (Host/Singleplayer only)
func _navigate_to_world_select():
	_hide_all_containers()
	worldSelectContainer.visible = true
	
	# Refresh world list
	var world_select = worldSelectContainer
	if world_select.has_method("refresh_world_list"):
		world_select.refresh_world_list()

func _on_world_chosen(world_id: String, world_data: WorldData):
	print("World chosen: ", world_data.world_name, " with character: ", selected_character.name, " in ", game_mode, " mode")
	selected_world_id = world_id
	selected_world_data = world_data
	
	# Update world's last played time
	world_data.update_last_played()
	
	# Start the game
	_start_game()

func _on_world_back_pressed():
	# Go back to character selection
	selected_world_id = ""
	selected_world_data = null
	_navigate_to_character_select()

# Client waiting for host's world selection
func _wait_for_host_world_selection():
	print("Waiting for host to select world...")
	# TODO: Show a "Waiting for host..." UI
	# This would be handled by the networking system calling on_host_selected_world()

func on_host_selected_world(world_id: String, world_data: WorldData):
	print("Host selected world: ", world_data.world_name)
	selected_world_id = world_id
	selected_world_data = world_data
	_start_game()

# Game startup
func _start_game():
	if not selected_character or not selected_world_data or game_mode.is_empty():
		print("ERROR: Missing required game startup data")
		return
	
	print("Starting game with:")
	print("  Character: ", selected_character.name)
	print("  World: ", selected_world_data.world_name)
	print("  Mode: ", game_mode)
	print("  Connected: ", is_connected)
	
	# Emit signal for main.gd to handle
	game_ready_to_start.emit(selected_character, selected_world_id, selected_world_data, game_mode)
	
	# The main.gd should handle the scene transition to maintain network state
	# Don't call get_tree().change_scene_to_file() here

# Utility methods
func _show_error_dialog(title: String, message: String):
	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	get_tree().root.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func _reset_to_multiplayer_menu():
	selected_character = null
	selected_world_id = ""
	selected_world_data = null
	game_mode = ""
	_hide_all_containers()
	multiplayerContainer.visible = true

func _reset_and_return_home():
	selected_character = null
	selected_world_id = ""
	selected_world_data = null
	game_mode = ""
	is_connected = false
	is_hosting = false
	_hide_all_containers()
	homescreenContainer.visible = true

# Settings Navigation  
func _on_settings_back_pressed() -> void:
	_hide_all_containers()
	homescreenContainer.visible = true

# Helper function to hide all containers
func _hide_all_containers():
	homescreenContainer.visible = false
	characterSelectContainer.visible = false
	worldSelectContainer.visible = false
	multiplayerContainer.visible = false
	settingsContainer.visible = false
	creditsContainer.visible = false
	if gameWorldContainer:
		gameWorldContainer.visible = false
	
	# Hide game UI when not in game
	var hotbar = find_child("HotbarUI", false, false)
	if hotbar:
		hotbar.visible = false
	
	var inventory_ui = find_child("InventoryUI", false, false)
	if inventory_ui:
		inventory_ui.visible = false

# Credits button (connected in scene)
func _on_credits_pressed():
	_hide_all_containers()
	creditsContainer.visible = true

# Game World Management
func _create_game_world_container():
	# Create the game world container
	gameWorldContainer = Control.new()
	gameWorldContainer.name = "GameWorldContainer"
	gameWorldContainer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gameWorldContainer.visible = false
	
	# Add it to the same parent as other containers
	var parent = homescreenContainer.get_parent()
	parent.add_child(gameWorldContainer)
	
	# Load the game world scene
	var game_world_scene = load("res://Scenes/game_world.tscn")
	if game_world_scene:
		var game_world_instance = game_world_scene.instantiate()
		gameWorldContainer.add_child(game_world_instance)
		
		# Add inventory manager to game world
		var inventory_manager = InventoryManager.new()
		inventory_manager.name = "InventoryManager"
		var starting_items: Array[String] = ["stone", "wood", "pickaxe", "bread"]
		inventory_manager.initial_items = starting_items
		game_world_instance.add_child(inventory_manager)
		
		# Move hotbar to main menu root for proper screen positioning
		var hotbar = inventory_manager.hotbar_ui
		inventory_manager.remove_child(hotbar)
		# Add hotbar to the main menu itself (this node), not gameWorldContainer
		add_child(hotbar)
		
		# Anchor hotbar to bottom center of screen
		hotbar.anchor_left = 0.5
		hotbar.anchor_right = 0.5
		hotbar.anchor_top = 1.0
		hotbar.anchor_bottom = 1.0
		
		# Wait one frame for proper sizing, then position
		await get_tree().process_frame
		
		# Center horizontally and position from bottom
		# Calculate proper width: 6 slots * 64px + 5 gaps * 4px + background padding
		var slot_width = 64
		var gap_width = 4
		var background_padding = 16
		var total_width = (slot_width * 6) + (gap_width * 5) + background_padding
		
		hotbar.offset_left = -total_width / 2
		hotbar.offset_right = total_width / 2
		hotbar.offset_top = -80  # 80px from bottom
		hotbar.offset_bottom = -16  # 16px from bottom
		
		print("Hotbar positioned at bottom center, anchors set to bottom, offset_top: ", hotbar.offset_top)
		
		# Move inventory UI to main menu root for proper screen positioning
		var inventory_ui = inventory_manager.inventory_ui
		inventory_manager.remove_child(inventory_ui)
		add_child(inventory_ui)
		
		# Wait one frame for proper sizing, then center on screen
		await get_tree().process_frame
		
		# Anchor to screen center
		inventory_ui.anchor_left = 0.5
		inventory_ui.anchor_right = 0.5
		inventory_ui.anchor_top = 0.5
		inventory_ui.anchor_bottom = 0.5
		
		# Center using calculated size
		var inv_width = inventory_ui.size.x if inventory_ui.size.x > 0 else 440  # fallback size
		var inv_height = inventory_ui.size.y if inventory_ui.size.y > 0 else 340
		inventory_ui.offset_left = -inv_width / 2
		inventory_ui.offset_right = inv_width / 2
		inventory_ui.offset_top = -inv_height / 2
		inventory_ui.offset_bottom = inv_height / 2
		
		print("Inventory centered on screen, size: ", inventory_ui.size)
	else:
		print("WARNING: Could not load game_world.tscn")

func _on_game_ready_to_start(character: CharacterData, world_id: String, world_data: WorldData, mode: String):
	print("Transitioning to game world...")
	
	# Load the world data using WorldSaveSystem
	var success = WorldSaveSystem.load_world(world_id)
	if not success:
		_show_error_dialog("Load Error", "Failed to load world: " + world_data.world_name)
		return
	
	# Hide all menu containers and show game world
	_hide_all_containers()
	gameWorldContainer.visible = true
	
	# Show game UI when entering game
	var hotbar = find_child("HotbarUI", false, false)
	if hotbar:
		hotbar.visible = true
	
	var inventory_ui = find_child("InventoryUI", false, false)
	if inventory_ui:
		inventory_ui.visible = true
		# Start with inventory hidden (player opens with Tab)
		inventory_ui.hide_inventory()
	
	# Capture mouse for FPS gameplay
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# TODO: Initialize the game world with character and world data
	print("Game world active - Character: %s, World: %s, Mode: %s" % [character.name, world_data.world_name, mode])

func return_to_menu():
	"""Call this function to return from game world to menu"""
	# Release mouse capture
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	_hide_all_containers()
	homescreenContainer.visible = true

func _input(event):
	# Allow ESC to return to menu from game world
	if event.is_action_pressed("ui_cancel") and gameWorldContainer and gameWorldContainer.visible:
		return_to_menu()
		get_viewport().set_input_as_handled()
