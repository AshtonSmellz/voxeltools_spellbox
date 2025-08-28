extends Resource
class_name BlockDrop

@export var item_id: int
@export var min_quantity: int = 1
@export var max_quantity: int = 1
@export var drop_chance: float = 1.0  # 0.0 to 1.0
@export var requires_tool: String = ""  # empty string = any tool/hand
@export var tool_level_required: int = 0
