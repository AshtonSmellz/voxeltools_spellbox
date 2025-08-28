extends PanelContainer
class_name WorldListItem

@onready var name_label: Label = $HBoxContainer/VBoxContainer/Label
@onready var info_label: Label = $HBoxContainer/VBoxContainer/Label2
@onready var play_button: Button = $HBoxContainer/PlayButton

signal selected(item: WorldListItem)
signal double_clicked(item: WorldListItem)
signal play_pressed(item: WorldListItem)

var world_data: WorldData
var world_id: String
var is_selected: bool = false

func _ready():
	# Set up focus and interaction
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(_on_mouse_entered)
	gui_input.connect(_on_gui_input)
	
	# Connect play button
	if play_button:
		play_button.pressed.connect(_on_play_button_pressed)
	
	# Set minimum size for proper display
	custom_minimum_size = Vector2(400, 64)
	
	# Style the panel
	_update_style()

func setup(data: WorldData, id: String):
	world_data = data
	world_id = id
	
	# Set up the display
	name_label.text = data.world_name
	info_label.text = "Type: %s • Last played: %s • Playtime: %s" % [
		data.world_type.capitalize(), 
		data.get_last_played_formatted(),
		data.get_playtime_formatted()
	]
	
	# Set up play button
	if play_button:
		play_button.text = "Play"
		play_button.custom_minimum_size = Vector2(60, 32)

func set_selected(selected: bool):
	is_selected = selected
	_update_style()
	if selected:
		grab_focus()

func _update_style():
	var style_box = StyleBoxFlat.new()
	
	if is_selected:
		style_box.bg_color = Color(0.3, 0.5, 0.8, 0.6)
		style_box.border_width_left = 3
		style_box.border_width_right = 3
		style_box.border_width_top = 3
		style_box.border_width_bottom = 3
		style_box.border_color = Color(0.4, 0.6, 1.0, 1.0)
	else:
		style_box.bg_color = Color(0.2, 0.2, 0.2, 0.3)
		style_box.border_width_left = 1
		style_box.border_width_right = 1
		style_box.border_width_top = 1
		style_box.border_width_bottom = 1
		style_box.border_color = Color(0.4, 0.4, 0.4, 0.5)
	
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	
	add_theme_stylebox_override("panel", style_box)

func _on_mouse_entered():
	if not is_selected:
		grab_focus()

func _on_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.double_click:
				double_clicked.emit(self)
			else:
				selected.emit(self)
	elif event.is_action_pressed("ui_accept"):
		double_clicked.emit(self)

func _on_play_button_pressed():
	play_pressed.emit(self)
