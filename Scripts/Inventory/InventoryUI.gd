class_name InventoryUI
extends Panel

# Main inventory UI with 6x4 grid (24 slots)

const INVENTORY_COLS = 6
const INVENTORY_ROWS = 4
const TOTAL_SLOTS = 24
const SLOT_SIZE = Vector2(64, 64)
const SLOT_SPACING = 4

@onready var grid_container: GridContainer = $VBoxContainer/GridContainer
@onready var close_button: Button = $VBoxContainer/HBoxContainer/CloseButton
@onready var inventory_title: Label = $VBoxContainer/HBoxContainer/InventoryTitle

var slot_uis: Array[InventorySlotUI] = []
var inventory_manager: InventoryManager
var drag_preview: Control
var dragging_slot: InventorySlotUI

signal inventory_closed()

func _ready():
	visible = false
	_setup_ui()
	_create_inventory_slots()

func _setup_ui():
	# Create main container if it doesn't exist
	if not has_node("VBoxContainer"):
		var vbox = VBoxContainer.new()
		vbox.name = "VBoxContainer"
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vbox.add_theme_constant_override("separation", 8)
		add_child(vbox)
		
		# Header with title and close button
		var hbox = HBoxContainer.new()
		hbox.name = "HBoxContainer"
		hbox.add_theme_constant_override("separation", 8)
		vbox.add_child(hbox)
		
		inventory_title = Label.new()
		inventory_title.name = "InventoryTitle"
		inventory_title.text = "Inventory"
		inventory_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inventory_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inventory_title.add_theme_font_size_override("font_size", 18)
		hbox.add_child(inventory_title)
		
		close_button = Button.new()
		close_button.name = "CloseButton"
		close_button.text = "×"
		close_button.custom_minimum_size = Vector2(32, 32)
		close_button.pressed.connect(_on_close_button_pressed)
		hbox.add_child(close_button)
		
		# Create a centered container for the grid
		var center_container = CenterContainer.new()
		center_container.name = "CenterContainer"
		vbox.add_child(center_container)
		
		# Grid container for inventory slots
		grid_container = GridContainer.new()
		grid_container.name = "GridContainer"
		grid_container.columns = INVENTORY_COLS
		grid_container.add_theme_constant_override("h_separation", SLOT_SPACING)
		grid_container.add_theme_constant_override("v_separation", SLOT_SPACING)
		center_container.add_child(grid_container)
	
	# Setup panel styling
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.3, 0.3, 0.3, 1.0)
	add_theme_stylebox_override("panel", panel_style)
	
	# Set appropriate size for the panel
	var panel_width = INVENTORY_COLS * SLOT_SIZE.x + (INVENTORY_COLS - 1) * SLOT_SPACING + 40  # 40 for padding
	var panel_height = INVENTORY_ROWS * SLOT_SIZE.y + (INVENTORY_ROWS - 1) * SLOT_SPACING + 80  # 80 for header and padding
	custom_minimum_size = Vector2(panel_width, panel_height)
	size = custom_minimum_size
	
	# Add padding to the main container
	if has_node("VBoxContainer"):
		var vbox = get_node("VBoxContainer")
		# Add margin around the content
		vbox.add_theme_constant_override("margin_left", 16)
		vbox.add_theme_constant_override("margin_right", 16)
		vbox.add_theme_constant_override("margin_top", 16)
		vbox.add_theme_constant_override("margin_bottom", 16)
	
	# Positioning will be handled by parent (main menu)
	print("InventoryUI initialized with size: ", size)

func _create_inventory_slots():
	for i in range(TOTAL_SLOTS):
		var slot_ui = InventorySlotUI.new()
		slot_ui.slot_size = SLOT_SIZE
		slot_ui.slot_clicked.connect(_on_slot_clicked)
		slot_ui.slot_hovered.connect(_on_slot_hovered)
		slot_ui.slot_unhovered.connect(_on_slot_unhovered)
		grid_container.add_child(slot_ui)
		slot_uis.append(slot_ui)

func setup_with_manager(manager: InventoryManager):
	inventory_manager = manager
	
	# Setup all slots
	for i in range(TOTAL_SLOTS):
		slot_uis[i].setup(i, manager)
	
	# Connect to inventory changes
	if manager and manager.inventory:
		manager.inventory.inventory_changed.connect(_on_inventory_changed)
		
		# Initial update
		for i in range(TOTAL_SLOTS):
			_on_inventory_changed(i)

func _on_inventory_changed(slot_index: int):
	if slot_index < slot_uis.size():
		var stack = inventory_manager.inventory.get_slot(slot_index)
		slot_uis[slot_index].set_item_stack(stack)

func _on_slot_clicked(slot_ui: InventorySlotUI, mouse_button: int):
	if not inventory_manager:
		return
	
	var slot_index = slot_uis.find(slot_ui)
	if slot_index < 0:
		return
	
	match mouse_button:
		MOUSE_BUTTON_LEFT:
			_handle_left_click(slot_index)
		MOUSE_BUTTON_RIGHT:
			_handle_right_click(slot_index)

func _handle_left_click(slot_index: int):
	# TODO: Implement drag and drop, item swapping, etc.
	print("Left clicked slot ", slot_index)

func _handle_right_click(slot_index: int):
	# TODO: Implement split stack, quick use, etc.
	print("Right clicked slot ", slot_index)

func _on_slot_hovered(slot_ui: InventorySlotUI):
	# TODO: Show item tooltip
	pass

func _on_slot_unhovered(slot_ui: InventorySlotUI):
	# TODO: Hide item tooltip
	pass

func show_inventory():
	visible = true
	# Release mouse capture while inventory is open
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func hide_inventory():
	visible = false
	inventory_closed.emit()

func _on_close_button_pressed():
	hide_inventory()

func _input(event: InputEvent):
	if visible and event.is_action_pressed("ui_cancel"):
		hide_inventory()
		get_viewport().set_input_as_handled()