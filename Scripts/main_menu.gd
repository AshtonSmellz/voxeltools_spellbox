extends Control

@onready var _ip_line_edit : LineEdit = \
	$CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/IP
@onready var _port_spinbox : SpinBox = \
	$CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/Port

@onready var homescreenContainer = $CenterContainer/HomeScreen
@onready var characterSelectContainer = $CenterContainer/CharacterSelect
@onready var worldSelectContainer = $CenterContainer/WorldSelect
@onready var multiplayerContainer = $CenterContainer/Multiplayer
@onready var settingsContainer = $CenterContainer/Settings
@onready var creditsContainer = $CenterContainer/Credits

signal singleplayer_requested()
signal connect_to_server_requested(ip, port)
signal host_server_requested(port)
signal upnp_toggled(pressed)

func _ready():
	# Connect character select signals
	var character_select = characterSelectContainer
	if character_select.has_signal("character_chosen"):
		character_select.character_chosen.connect(_on_character_chosen)
	if character_select.has_signal("back_pressed"):
		character_select.back_pressed.connect(_on_character_back_pressed)

func _on_singleplayer_button_pressed():
	singleplayer_requested.emit()

func _on_connect_to_server_button_pressed():
	var ip := _ip_line_edit.text.strip_edges()
	if ip == "":
		return
	# TODO Do more validation on the syntax of IP address
	var port : int = _port_spinbox.value
	connect_to_server_requested.emit(ip, port)

func _on_host_server_button_pressed():
	var port : int = _port_spinbox.value
	host_server_requested.emit(port)

func _on_upnp_checkbox_toggled(button_pressed: bool):
	upnp_toggled.emit(button_pressed)

# Home Screen Navigation
func _on_singleplayer_pressed() -> void:
	print("Singleplayer pressed - navigating to character select")
	print("Before hiding - HomeScreen visible: ", homescreenContainer.visible)
	print("Before hiding - CharacterSelect visible: ", characterSelectContainer.visible)
	
	_hide_all_containers()
	
	print("After hiding all - CharacterSelect visible: ", characterSelectContainer.visible)
	
	characterSelectContainer.visible = true
	
	print("After showing CharacterSelect - visible: ", characterSelectContainer.visible)
	print("CharacterSelect size: ", characterSelectContainer.size)
	print("CharacterSelect global position: ", characterSelectContainer.global_position)
	
	# Refresh the character list when showing
	var character_select = characterSelectContainer
	if character_select.has_method("refresh_character_list"):
		print("Calling refresh_character_list...")
		character_select.refresh_character_list()

func _on_multiplayer_pressed() -> void:
	_hide_all_containers()
	multiplayerContainer.visible = true

func _on_settings_pressed() -> void:
	_hide_all_containers()
	settingsContainer.visible = true

func _on_quit_pressed() -> void:
	get_tree().quit()

# Character Select Navigation
func _on_character_chosen(character_data: CharacterData):
	print("Chosen character: ", character_data.name)
	# Store the selected character for later use
	# TODO: Move to world selection screen
	_hide_all_containers()
	worldSelectContainer.visible = true
	
	# Here you would pass the character to world selection
	# and let the player choose which world to load the character into

func _on_character_back_pressed():
	_hide_all_containers()
	homescreenContainer.visible = true

# Settings Navigation  
func _on_settings_back_pressed() -> void:
	_hide_all_containers()
	homescreenContainer.visible = true

# Helper function to hide all containers
func _hide_all_containers():
	print("Hiding all containers...")
	homescreenContainer.visible = false
	characterSelectContainer.visible = false
	worldSelectContainer.visible = false
	multiplayerContainer.visible = false
	settingsContainer.visible = false
	creditsContainer.visible = false
	print("All containers hidden")

# Credits button (connected in scene)
func _on_credits_pressed():
	_hide_all_containers()
	creditsContainer.visible = true
