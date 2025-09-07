class_name InventorySlotUI
extends Panel

# UI component for a single inventory slot

@export var slot_size: Vector2 = Vector2(64, 64)
@export var is_hotbar_slot: bool = false

@onready var icon_display: TextureRect = $IconDisplay
@onready var quantity_label: Label = $QuantityLabel
@onready var selection_highlight: Panel = $SelectionHighlight

var slot_index: int = -1
var item_stack: ItemStack
var inventory_manager: InventoryManager

signal slot_clicked(slot_ui: InventorySlotUI, mouse_button: int)
signal slot_hovered(slot_ui: InventorySlotUI)
signal slot_unhovered(slot_ui: InventorySlotUI)

func _ready():
	custom_minimum_size = slot_size
	size = slot_size
	
	# Ensure slot maintains its size
	set("size_flags_horizontal", Control.SIZE_SHRINK_CENTER)
	set("size_flags_vertical", Control.SIZE_SHRINK_CENTER)
	
	# Create UI elements if they don't exist
	if not icon_display:
		_create_ui_elements()
	
	# Connect input signals
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Initialize display
	update_display()

func _create_ui_elements():
	# Icon display
	icon_display = TextureRect.new()
	icon_display.name = "IconDisplay"
	icon_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon_display)
	
	# Quantity label
	quantity_label = Label.new()
	quantity_label.name = "QuantityLabel"
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	quantity_label.add_theme_color_override("font_color", Color.WHITE)
	quantity_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	quantity_label.add_theme_constant_override("shadow_offset_x", 1)
	quantity_label.add_theme_constant_override("shadow_offset_y", 1)
	quantity_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	quantity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(quantity_label)
	
	# Selection highlight
	selection_highlight = Panel.new()
	selection_highlight.name = "SelectionHighlight"
	selection_highlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	selection_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection_highlight.visible = false
	
	var highlight_style = StyleBoxFlat.new()
	highlight_style.bg_color = Color.YELLOW
	highlight_style.border_width_left = 2
	highlight_style.border_width_right = 2
	highlight_style.border_width_top = 2
	highlight_style.border_width_bottom = 2
	highlight_style.border_color = Color.ORANGE
	selection_highlight.add_theme_stylebox_override("panel", highlight_style)
	add_child(selection_highlight)

func setup(index: int, manager: InventoryManager):
	slot_index = index
	inventory_manager = manager
	update_display()

func set_item_stack(stack: ItemStack):
	item_stack = stack
	update_display()

func update_display():
	if not icon_display or not quantity_label:
		return
	
	if not item_stack or item_stack.is_empty():
		icon_display.texture = null
		quantity_label.text = ""
		tooltip_text = ""
	else:
		icon_display.texture = item_stack.item.icon
		quantity_label.text = str(item_stack.quantity) if item_stack.quantity > 1 else ""
		tooltip_text = item_stack.item.get_display_name() + "\n" + item_stack.item.description

func set_selected(selected: bool):
	if selection_highlight:
		selection_highlight.visible = selected

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		slot_clicked.emit(self, event.button_index)

func _on_mouse_entered():
	slot_hovered.emit(self)

func _on_mouse_exited():
	slot_unhovered.emit(self)