class_name Item
extends Resource

# Basic item data structure

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var max_stack_size: int = 99
@export var item_type: ItemType = ItemType.MATERIAL

enum ItemType {
	MATERIAL,
	TOOL,
	WEAPON,
	CONSUMABLE,
	BLOCK
}

func _init(item_id: String = "", item_name: String = "", item_description: String = ""):
	id = item_id
	name = item_name
	description = item_description

func can_stack_with(other_item: Item) -> bool:
	if not other_item:
		return false
	return id == other_item.id

func get_display_name() -> String:
	return name if not name.is_empty() else id
