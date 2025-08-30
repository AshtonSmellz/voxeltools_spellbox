extends Node

# Import your custom scripts
const MainMenu = preload("res://Scripts/Menu/main_menu.gd")
const CharacterData = preload("res://Scripts/CharacterData.gd")
const WorldData = preload("res://Scripts/WorldData.gd")
const WorldSaveSystem = preload("res://Scripts/WorldSaveSystem.gd")
const BlockLibrary = preload("res://Scripts/BlockLibrary.gd")
const BlockPropertyManager = preload("res://Scripts/BlockPropertyManager.gd")

# Import blocky game components
const BlockyGameScene = preload("res://Scenes/game_world.tscn")

#const UPNPHelper = preload("res://Scripts/upnp_helper.gd")

const UPNPHelper = preload("res://Scripts/UPNPHelper.gd")

@onready var _main_menu: Control = $MainMenu

# Game state
var _game: Node
var _upnp_helper: UPNPHelper
var _world_save_system: WorldSaveSystem
var _block_library: BlockLibrary
var _block_property_manager: BlockPropertyManager

# Selected game data
var selected_character: CharacterData
var selected_world_data: WorldData
var selected_world_id: String
var network_mode: String = ""

# Network constants
const NETWORK_MODE_SINGLEPLAYER = 0
const NETWORK_MODE_CLIENT = 1
const NETWORK_MODE_HOST = 2

func _ready():
	print("Main: Initializing game systems...")
	
	# Initialize core systems
	_initialize_systems()
	
	# Connect menu signals
	_connect_menu_signals()
	
	print("Main: Ready")

func _initialize_systems():
	# Initialize world save system
	_world_save_system = WorldSaveSystem.new()
	add_child(_world_save_system)
	
	# Initialize block library
	_block_library = BlockLibrary.new()
	add_child(_block_library)
	
	# Initialize block property manager
	_block_property_manager = BlockPropertyManager.new()
	add_child(_block_property_manager)
	
	print("Main: Core systems initialized")

func _connect_menu_signals():
	if _main_menu:
		# Connect new signal structure
		if _main_menu.has_signal("singleplayer_requested"):
			_main_menu.singleplayer_requested.connect(_on_singleplayer_requested)
		if _main_menu.has_signal("host_server_requested"):
			_main_menu.host_server_requested.connect(_on_host_server_requested)
		if _main_menu.has_signal("connect_to_server_requested"):
			_main_menu.connect_to_server_requested.connect(_on_connect_to_server_requested)
		if _main_menu.has_signal("upnp_toggled"):
			_main_menu.upnp_toggled.connect(_on_upnp_toggled)
		if _main_menu.has_signal("game_ready_to_start"):
			_main_menu.game_ready_to_start.connect(_on_game_ready_to_start)

# Menu signal handlers
func _on_singleplayer_requested():
	print("Main: Singleplayer mode selected")
	network_mode = "singleplayer"
	# Menu will handle character/world selection

func _on_host_server_requested(port: int, use_upnp: bool):
	print("Main: Starting server on port ", port, " with UPnP: ", use_upnp)
	network_mode = "host"
	
	# Set up UPnP first if requested
	if use_upnp:
		_setup_upnp(port)
	
	# Create server
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, 32)
	
	if error == OK:
		multiplayer.multiplayer_peer = peer
		
		# Connect multiplayer signals
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		
		print("Main: Server started successfully")
		if _main_menu and _main_menu.has_method("on_server_started_successfully"):
			_main_menu.on_server_started_successfully()
	else:
		print("Main: Failed to start server: ", error)
		if _main_menu and _main_menu.has_method("on_server_start_failed"):
			_main_menu.on_server_start_failed("Failed to create server on port " + str(port))

func _on_connect_to_server_requested(ip: String, port: int):
	print("Main: Connecting to server ", ip, ":", port)
	network_mode = "client"
	
	# Create client
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, port)
	
	if error == OK:
		multiplayer.multiplayer_peer = peer
		
		# Connect multiplayer signals
		multiplayer.connected_to_server.connect(_on_connected_to_server)
		multiplayer.connection_failed.connect(_on_connection_failed)
		multiplayer.server_disconnected.connect(_on_server_disconnected)
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		
		print("Main: Attempting connection...")
	else:
		print("Main: Failed to create client: ", error)
		if _main_menu and _main_menu.has_method("on_connection_failed"):
			_main_menu.on_connection_failed("Failed to create client connection")

func _on_upnp_toggled(pressed: bool):
	print("Main: UPnP toggled: ", pressed)
	if pressed:
		if _upnp_helper == null:
			_upnp_helper = UPNPHelper.new()
			add_child(_upnp_helper)
	else:
		if _upnp_helper != null:
			_upnp_helper.queue_free()
			_upnp_helper = null

func _on_game_ready_to_start(character: CharacterData, world_id: String, world_data: WorldData, mode: String):
	print("Main: Starting game with:")
	print("  Character: ", character.name)
	print("  World: ", world_data.world_name)
	print("  Mode: ", mode)
	
	# Store selected data
	selected_character = character
	selected_world_data = world_data
	selected_world_id = world_id
	
	# Load world in save system
	if not _world_save_system.load_world(world_id):
		print("Main: Failed to load world, creating new save...")
		# For new worlds, we might need to save the world data first
		var save_error = ResourceSaver.save(world_data, "user://worlds/" + world_id + "/world.tres")
		if save_error != OK:
			print("Main: Failed to save world data: ", save_error)
			return
		_world_save_system.load_world(world_id)
	
	# Load game world scene
	_load_game_world()

func _load_game_world():
	print("Main: Loading game world...")
	
	# Hide menu
	_main_menu.hide()
	
	# Instantiate game world
	_game = BlockyGameScene.instantiate()
	
	# Configure network mode for the game
	var net_mode = NETWORK_MODE_SINGLEPLAYER
	match network_mode:
		"singleplayer":
			net_mode = NETWORK_MODE_SINGLEPLAYER
		"host":
			net_mode = NETWORK_MODE_HOST
		"client":
			net_mode = NETWORK_MODE_CLIENT
	
	# Set up the game with our data
	if _game.has_method("set_network_mode"):
		_game.set_network_mode(net_mode)
	
	if _game.has_method("initialize_with_game_data"):
		_game.initialize_with_game_data(selected_character, selected_world_data, selected_world_id)
	
	# Add to scene tree
	add_child(_game)
	
	# Set window title
	match network_mode:
		"host":
			get_viewport().get_window().title = "Server - " + selected_world_data.world_name
		"client":
			get_viewport().get_window().title = "Client - " + selected_world_data.world_name
		"singleplayer":
			get_viewport().get_window().title = selected_world_data.world_name

# Network event handlers
func _on_connected_to_server():
	print("Main: Connected to server")
	if _main_menu and _main_menu.has_method("on_connected_to_server"):
		_main_menu.on_connected_to_server()

func _on_connection_failed():
	print("Main: Connection to server failed")
	if _main_menu and _main_menu.has_method("on_connection_failed"):
		_main_menu.on_connection_failed("Connection to server failed")

func _on_server_disconnected():
	print("Main: Server disconnected")
	if _main_menu and _main_menu.has_method("on_disconnected_from_server"):
		_main_menu.on_disconnected_from_server()
	
	# Return to menu
	_return_to_menu()

func _on_peer_connected(peer_id: int):
	print("Main: Peer ", peer_id, " connected")

func _on_peer_disconnected(peer_id: int):
	print("Main: Peer ", peer_id, " disconnected")

# UPnP setup
func _setup_upnp(port: int):
	if _upnp_helper != null and not _upnp_helper.is_setup():
		print("Main: Setting up UPnP for port ", port)
		_upnp_helper.setup(port, PackedStringArray(["TCP", "UDP"]), "VoxelMagicGame", 20 * 60)

# Utility methods
func _return_to_menu():
	if _game:
		_game.queue_free()
		_game = null
	
	# Reset state
	selected_character = null
	selected_world_data = null
	selected_world_id = ""
	network_mode = ""
	
	# Disconnect multiplayer
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	# Show menu
	_main_menu.show()
	_main_menu._reset_and_return_home()
	
	# Reset window title
	get_viewport().get_window().title = "Voxel Magic Game"

func _notification(what: int):
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			# Save game when closing
			if _game and _game.has_method("save_world"):
				print("Main: Saving world before exit...")
				_game.save_world()
			get_tree().quit()

# Debug helpers
func _unhandled_input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1:
				# Toggle debug info
				print("Main: Debug info toggle")
			KEY_ESCAPE:
				if _game:
					# Return to menu (for testing)
					_return_to_menu()
