extends Control

@export var WorldItemScene: PackedScene

@onready var scroll_container: ScrollContainer = $VBoxContainer/ScrollContainer
@onready var world_list: VBoxContainer = $VBoxContainer/ScrollContainer/VBoxContainer
@onready var create_button: Button = $VBoxContainer/HBoxContainer/CreateButton
@onready var delete_button: Button = $VBoxContainer/HBoxContainer/DeleteButton
@onready var back_button: Button = $VBoxContainer/Button

signal world_chosen(world_id: String, world_data: WorldData)
signal back_pressed()

var world_save_system: WorldSaveSystem
var world_items: Array[WorldListItem] = []
var selected_item: WorldListItem = null

func _ready():
	# Connect button signals
	create_button.pressed.connect(_on_create_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	back_button.pressed.connect(_on_back_pressed)
	
	# Get or create WorldSaveSystem
	world_save_system = WorldSaveSystem.new()
	
	# Load worlds
	refresh_world_list()
	
	# Update button states
	_update_button_states()

func refresh_world_list():
	# Clear existing items
	for item in world_items:
		item.queue_free()
	world_items.clear()
	selected_item = null
	
	# Load all available worlds
	var available_worlds = world_save_system.get_available_worlds()
	
	print("Found ", available_worlds.size(), " worlds")
	
	# Create world items
	for world_info in available_worlds:
		var world_data: WorldData = world_info["data"]
		var world_id: String = world_info["id"]
		
		# Create list item
		var item = WorldItemScene.instantiate() as WorldListItem
		world_list.add_child(item)
		
		# Wait one frame for the item to be ready
		await get_tree().process_frame
		
		item.setup(world_data, world_id)
		
		# Connect signals
		item.selected.connect(_on_item_selected)
		item.double_clicked.connect(_on_item_double_clicked)
		item.play_pressed.connect(_on_item_play_pressed)
		
		world_items.append(item)
	
	# Select first item if available
	if world_items.size() > 0:
		_select_item(world_items[0])
	
	_update_button_states()

func _select_item(item: WorldListItem):
	# Deselect previous item
	if selected_item != null:
		selected_item.set_selected(false)
	
	# Select new item
	selected_item = item
	item.set_selected(true)
	
	# Ensure item is visible
	scroll_container.ensure_control_visible(item)
	
	_update_button_states()

func _update_button_states():
	var has_selection = selected_item != null
	delete_button.disabled = not has_selection

func _show_world_creation_dialog():
	var dialog = AcceptDialog.new()
	dialog.title = "Create New World"
	
	var vbox = VBoxContainer.new()
	
	# World name input
	var name_label = Label.new()
	name_label.text = "World Name:"
	vbox.add_child(name_label)
	
	var name_edit = LineEdit.new()
	name_edit.text = "New World"
	name_edit.custom_minimum_size.x = 300
	vbox.add_child(name_edit)
	
	# World type selection
	var type_label = Label.new()
	type_label.text = "World Type:"
	vbox.add_child(type_label)
	
	var type_option = OptionButton.new()
	type_option.add_item("Default")
	type_option.add_item("Flat")
	type_option.add_item("Amplified")
	type_option.add_item("Custom")
	vbox.add_child(type_option)
	
	# Seed input (optional)
	var seed_label = Label.new()
	seed_label.text = "Seed (optional):"
	vbox.add_child(seed_label)
	
	var seed_edit = LineEdit.new()
	seed_edit.placeholder_text = "Leave empty for random"
	vbox.add_child(seed_edit)
	
	dialog.add_child(vbox)
	get_tree().root.add_child(dialog)
	dialog.popup_centered()
	name_edit.grab_focus()
	name_edit.select_all()
	
	dialog.confirmed.connect(func():
		var world_name = name_edit.text.strip_edges()
		if world_name.is_empty():
			world_name = "New World"
		
		var world_types = ["default", "flat", "amplified", "custom"]
		var world_type = world_types[type_option.selected]
		
		var seed = -1
		if not seed_edit.text.is_empty():
			if seed_edit.text.is_valid_int():
				seed = seed_edit.text.to_int()
			else:
				seed = seed_edit.text.hash()
		
		_create_world(world_name, world_type, seed)
		dialog.queue_free()
	)
	
	dialog.canceled.connect(func(): dialog.queue_free())

func _create_world(world_name: String, world_type: String, seed: int):
	var world_data = world_save_system.create_world(world_name, world_type, seed)
	if world_data:
		print("Created world: ", world_name)
		refresh_world_list()
	else:
		print("Failed to create world: ", world_name)

# Button handlers
func _on_create_pressed():
	_show_world_creation_dialog()

func _on_delete_pressed():
	if selected_item == null:
		return
	
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "Delete world '%s'? This cannot be undone." % selected_item.world_data.world_name
	get_tree().root.add_child(dialog)
	dialog.popup_centered()
	
	dialog.confirmed.connect(func():
		_delete_world()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())

func _delete_world():
	if selected_item == null:
		return
	
	var success = world_save_system.delete_world(selected_item.world_id)
	if success:
		print("Deleted world: ", selected_item.world_data.world_name)
		refresh_world_list()
	else:
		print("Failed to delete world: ", selected_item.world_data.world_name)

func _on_back_pressed():
	back_pressed.emit()

# Item selection handlers
func _on_item_selected(item: WorldListItem):
	_select_item(item)

func _on_item_double_clicked(item: WorldListItem):
	_select_item(item)
	if item.world_data != null:
		world_chosen.emit(item.world_id, item.world_data)

func _on_item_play_pressed(item: WorldListItem):
	_select_item(item)
	if item.world_data != null:
		world_chosen.emit(item.world_id, item.world_data)
