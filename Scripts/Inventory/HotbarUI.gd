class_name HotbarUI
extends HBoxContainer

# Hotbar UI with 6 slots

const HOTBAR_SIZE = 6
const SLOT_SIZE = Vector2(64, 64)

var slot_uis: Array[InventorySlotUI] = []
var selected_slot: int = 0
var inventory_manager: InventoryManager

signal hotbar_selection_changed(slot_index: int)

func _ready():
	_create_hotbar_slots()
	
	# Set up styling
	add_theme_constant_override("separation", 4)
	
	# Create background panel
	var bg_panel = Panel.new()
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	bg_style.corner_radius_top_left = 8
	bg_style.corner_radius_top_right = 8
	bg_style.corner_radius_bottom_left = 8
	bg_style.corner_radius_bottom_right = 8
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg_panel)
	move_child(bg_panel, 0)  # Move to back
	
	# Set proper size for centering - give it plenty of space
	var hotbar_width = SLOT_SIZE.x * HOTBAR_SIZE + 4 * (HOTBAR_SIZE - 1) + 16  # Add background padding
	var hotbar_height = SLOT_SIZE.y + 16  # Add padding for background
	custom_minimum_size = Vector2(hotbar_width, hotbar_height)
	size = custom_minimum_size
	
	# Ensure HBoxContainer doesn't constrain children
	set("size_flags_horizontal", Control.SIZE_EXPAND_FILL)
	
	print("HotbarUI created, size: ", size, " slots: ", slot_uis.size())

func _create_hotbar_slots():
	for i in range(HOTBAR_SIZE):
		var slot_ui = InventorySlotUI.new()
		slot_ui.is_hotbar_slot = true
		slot_ui.slot_size = SLOT_SIZE
		slot_ui.slot_clicked.connect(_on_slot_clicked)
		add_child(slot_ui)
		slot_uis.append(slot_ui)
		
		print("Created hotbar slot ", i, " at position: ", slot_ui.position)
	
	# Select first slot by default
	update_selection()
	
	print("Hotbar slots created: ", slot_uis.size(), " total children: ", get_children().size())

func setup_with_manager(manager: InventoryManager):
	inventory_manager = manager
	for i in range(HOTBAR_SIZE):
		slot_uis[i].setup(i, manager)
	
	# Connect to inventory changes
	if manager and manager.inventory:
		manager.inventory.inventory_changed.connect(_on_inventory_changed)

func _on_inventory_changed(slot_index: int):
	if slot_index < HOTBAR_SIZE:
		var stack = inventory_manager.inventory.get_slot(slot_index)
		slot_uis[slot_index].set_item_stack(stack)

func _on_slot_clicked(slot_ui: InventorySlotUI, mouse_button: int):
	var slot_index = slot_uis.find(slot_ui)
	if slot_index >= 0:
		select_slot(slot_index)

func select_slot(slot_index: int):
	if slot_index < 0 or slot_index >= HOTBAR_SIZE:
		return
	
	selected_slot = slot_index
	update_selection()
	hotbar_selection_changed.emit(selected_slot)

func update_selection():
	for i in range(slot_uis.size()):
		slot_uis[i].set_selected(i == selected_slot)

func get_selected_item() -> ItemStack:
	if inventory_manager and inventory_manager.inventory:
		return inventory_manager.inventory.get_slot(selected_slot)
	return null

func _input(event: InputEvent):
	# Handle number keys for hotbar selection
	if event.is_action_pressed("hotbar_1"):
		select_slot(0)
	elif event.is_action_pressed("hotbar_2"):
		select_slot(1)
	elif event.is_action_pressed("hotbar_3"):
		select_slot(2)
	elif event.is_action_pressed("hotbar_4"):
		select_slot(3)
	elif event.is_action_pressed("hotbar_5"):
		select_slot(4)
	elif event.is_action_pressed("hotbar_6"):
		select_slot(5)
	elif event.is_action_pressed("hotbar_scroll_up"):
		select_slot((selected_slot - 1) % HOTBAR_SIZE)
	elif event.is_action_pressed("hotbar_scroll_down"):
		select_slot((selected_slot + 1) % HOTBAR_SIZE)
