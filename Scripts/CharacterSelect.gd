extends Control

@export var CharacterItemScene: PackedScene

@onready var scroll_container: ScrollContainer = $VBoxContainer/ScrollContainer
@onready var character_list: VBoxContainer = $VBoxContainer/ScrollContainer/VBoxContainer
@onready var create_button: Button = $VBoxContainer/HBoxContainer/CreateButton
@onready var rename_button: Button = $VBoxContainer/HBoxContainer/RenameButton
@onready var delete_button: Button = $VBoxContainer/HBoxContainer/DeleteButton
@onready var back_button: Button = $VBoxContainer/Button

signal character_chosen(character_data: CharacterData)
signal back_pressed()

const CHARACTER_DIR = "user://characters/"
var character_items: Array[CharacterListItem] = []
var selected_item: CharacterListItem = null

func _ready():
	# Connect button signals
	create_button.pressed.connect(_on_create_pressed)
	rename_button.pressed.connect(_on_rename_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	back_button.pressed.connect(_on_back_pressed)
	
	# Ensure character directory exists
	_ensure_character_directory()
	
	# Load characters
	refresh_character_list()
	
	# Update button states
	_update_button_states()

func _ensure_character_directory():
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("characters"):
		dir.make_dir("characters")

func refresh_character_list():
	print("Refreshing character list...")
	print("CharacterSelect visible: ", visible)
	print("ScrollContainer visible: ", scroll_container.visible if scroll_container else "NULL")
	print("CharacterList visible: ", character_list.visible if character_list else "NULL")
	print("CharacterSelect size: ", size)
	print("ScrollContainer size: ", scroll_container.size if scroll_container else "NULL")
	print("CharacterList size: ", character_list.size if character_list else "NULL")
	
	# Clear existing items
	for item in character_items:
		item.queue_free()
	character_items.clear()
	selected_item = null
	
	# Load all character files
	var dir = DirAccess.open(CHARACTER_DIR)
	if dir == null:
		print("Could not open character directory: ", CHARACTER_DIR)
		print("Attempting to create directory...")
		_ensure_character_directory()
		dir = DirAccess.open(CHARACTER_DIR)
		if dir == null:
			print("Still cannot open character directory!")
			return
	
	print("Successfully opened character directory")
	
	var character_files: Array[String] = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		print("Found file: ", file_name)
		if file_name.ends_with(".tres") and not dir.current_is_dir():
			character_files.append(file_name)
			print("Added character file: ", file_name)
		file_name = dir.get_next()
	
	print("Total character files found: ", character_files.size())
	
	# Sort by last played (most recent first)
	character_files.sort_custom(_compare_characters_by_last_played)
	
	# Create character items
	for file in character_files:
		var full_path = CHARACTER_DIR + file
		print("Loading character from: ", full_path)
		var character_data = ResourceLoader.load(full_path) as CharacterData
		
		if character_data == null:
			print("Failed to load character data from: ", full_path)
			continue
		
		print("Loaded character: ", character_data.name)
		
		# Create list item
		var item = CharacterItemScene.instantiate() as CharacterListItem
		if item == null:
			print("ERROR: Failed to instantiate CharacterItemScene!")
			continue
			
		print("Instantiated character item, adding to list...")
		character_list.add_child(item)
		
		# Give it one frame to initialize instead of awaiting ready
		await get_tree().process_frame
		
		print("Item added to tree, calling setup...")
		item.setup(character_data, full_path)
		
		print("Item size after setup: ", item.size, " visible: ", item.visible)
		
		# Connect signals
		item.selected.connect(_on_item_selected)
		item.double_clicked.connect(_on_item_double_clicked)
		item.play_pressed.connect(_on_item_play_pressed)
		
		character_items.append(item)
		
		print("Character item fully configured and added to array")
	
	print("Created ", character_items.size(), " character items")
	
	# Select first item if available
	if character_items.size() > 0:
		_select_item(character_items[0])
	
	_update_button_states()

func _compare_characters_by_last_played(a: String, b: String) -> bool:
	var char_a = ResourceLoader.load(CHARACTER_DIR + a) as CharacterData
	var char_b = ResourceLoader.load(CHARACTER_DIR + b) as CharacterData
	
	if char_a == null or char_b == null:
		return false
	
	return char_a.last_played > char_b.last_played

func _select_item(item: CharacterListItem):
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
	rename_button.disabled = not has_selection
	delete_button.disabled = not has_selection

func _generate_unique_filename() -> String:
	var counter = 1
	var filename = "character_%d.tres" % counter
	
	while FileAccess.file_exists(CHARACTER_DIR + filename):
		counter += 1
		filename = "character_%d.tres" % counter
	
	return filename

func _show_text_dialog(title: String, placeholder: String, callback: Callable):
	var dialog = AcceptDialog.new()
	dialog.title = title
	
	var line_edit = LineEdit.new()
	line_edit.text = placeholder
	line_edit.custom_minimum_size.x = 300
	
	var vbox = VBoxContainer.new()
	var label = Label.new()
	label.text = "Enter name:"
	
	vbox.add_child(label)
	vbox.add_child(line_edit)
	dialog.add_child(vbox)
	
	get_tree().root.add_child(dialog)
	dialog.popup_centered()
	line_edit.grab_focus()
	line_edit.select_all()
	
	dialog.confirmed.connect(func(): 
		callback.call(line_edit.text)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())

# Button handlers
func _on_create_pressed():
	_show_text_dialog("Create New Character", "New Hero", _create_character)

func _create_character(character_name: String):
	if character_name.strip_edges() == "":
		character_name = "New Hero"
	
	var character_data = CharacterData.new()
	character_data.name = character_name
	character_data.level = 1
	character_data.archetype = "Adventurer"
	character_data.last_played = int(Time.get_unix_time_from_system())
	
	var filename = _generate_unique_filename()
	var full_path = CHARACTER_DIR + filename
	
	var error = ResourceSaver.save(character_data, full_path)
	if error != OK:
		print("Failed to save character: ", error)
		return
	
	print("Created new character: ", character_name)
	refresh_character_list()

func _on_rename_pressed():
	if selected_item == null:
		return
	
	_show_text_dialog("Rename Character", selected_item.character_data.name, _rename_character)

func _rename_character(new_name: String):
	if selected_item == null or new_name.strip_edges() == "":
		return
	
	selected_item.character_data.name = new_name
	var error = ResourceSaver.save(selected_item.character_data, selected_item.save_path)
	if error != OK:
		print("Failed to rename character: ", error)
		return
	
	print("Renamed character to: ", new_name)
	refresh_character_list()

func _on_delete_pressed():
	if selected_item == null:
		return
	
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "Delete character '%s'? This cannot be undone." % selected_item.character_data.name
	get_tree().root.add_child(dialog)
	dialog.popup_centered()
	
	dialog.confirmed.connect(func():
		_delete_character()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())

func _delete_character():
	if selected_item == null:
		return
	
	var dir = DirAccess.open("user://")
	var error = dir.remove(selected_item.save_path)
	
	if error != OK:
		print("Failed to delete character file: ", error)
		return
	
	print("Deleted character: ", selected_item.character_data.name)
	refresh_character_list()

func _on_back_pressed():
	back_pressed.emit()

# Item selection handlers
func _on_item_selected(item: CharacterListItem):
	_select_item(item)

func _on_item_double_clicked(item: CharacterListItem):
	_select_item(item)
	if item.character_data != null:
		character_chosen.emit(item.character_data)

func _on_item_play_pressed(item: CharacterListItem):
	_select_item(item)
	if item.character_data != null:
		character_chosen.emit(item.character_data)
