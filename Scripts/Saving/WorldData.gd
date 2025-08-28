extends Resource
class_name WorldData

@export var version: int = 1
@export var world_name: String = "New World"
@export var seed: int = 0
@export var world_type: String = "default"  # default, flat, amplified, etc.
@export var created: int = 0
@export var last_played: int = 0
@export var playtime: int = 0  # seconds
@export var world_size: Vector3i = Vector3i(2048, 256, 2048)  # blocks
@export var spawn_point: Vector3 = Vector3.ZERO
@export var world_time: float = 0.0  # in-game time
@export var difficulty: String = "normal"

# Game rules and settings
@export var game_rules: Dictionary = {
	"enable_magic": true,
	"magic_decay_rate": 0.95,
	"temperature_simulation": true,
	"physics_simulation": true,
	"block_updates": true
}

# World generation parameters
@export var generation_params: Dictionary = {
	"terrain_height_scale": 100.0,
	"cave_frequency": 0.3,
	"ore_density": 1.0,
	"magical_crystal_rarity": 0.1
}

# Performance tracking
@export var statistics: Dictionary = {
	"chunks_generated": 0,
	"blocks_modified": 0,
	"magical_effects_cast": 0,
	"player_deaths": 0
}

func _init():
	if created == 0:
		created = int(Time.get_unix_time_from_system())
		last_played = created
		seed = randi()

func get_last_played_formatted() -> String:
	if last_played <= 0:
		return "Never"
	var dt = Time.get_datetime_dict_from_unix_time(last_played)
	return "%04d-%02d-%02d %02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute]

func get_playtime_formatted() -> String:
	if playtime <= 0:
		return "0m"
	var hours = playtime / 3600
	var minutes = (playtime % 3600) / 60
	if hours > 0:
		return "%dh %dm" % [hours, minutes]
	else:
		return "%dm" % minutes

func get_world_size_formatted() -> String:
	return "%d × %d × %d" % [world_size.x, world_size.y, world_size.z]

func update_last_played():
	last_played = int(Time.get_unix_time_from_system())
