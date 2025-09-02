class_name WorldData
extends Resource

# Metadata for a saved world

@export var world_name: String = "New World"
@export var world_type: String = "default"  # default, flat, void, etc.
@export var seed: int = 0
@export var creation_date: int = 0  # Unix timestamp
@export var last_played: int = 0    # Unix timestamp
@export var playtime: float = 0.0  # Total playtime in seconds
@export var game_version: String = "1.0.0"

# Player data
@export var player_position: Vector3 = Vector3.ZERO
@export var player_rotation: Vector3 = Vector3.ZERO
@export var player_inventory: Dictionary = {}  # Item ID -> quantity

# World statistics
@export var statistics: Dictionary = {
	"blocks_placed": 0,
	"blocks_destroyed": 0,
	"spells_cast": 0,
	"chunks_generated": 0,
	"distance_traveled": 0.0,
}

# World settings
@export var settings: Dictionary = {
	"difficulty": "normal",  # peaceful, easy, normal, hard
	"enable_spells": true,
	"enable_temperature": true,
	"enable_physics": true,
	"day_night_cycle": true,
	"weather_enabled": true,
}

func _init():
	creation_date = int(Time.get_unix_time_from_system())
	last_played = creation_date

func update_last_played():
	last_played = int(Time.get_unix_time_from_system())

func get_formatted_playtime() -> String:
	var hours = int(playtime / 3600)
	var minutes = int((playtime - hours * 3600) / 60)
	var seconds = int(playtime - hours * 3600 - minutes * 60)
	
	if hours > 0:
		return "%dh %dm %ds" % [hours, minutes, seconds]
	elif minutes > 0:
		return "%dm %ds" % [minutes, seconds]
	else:
		return "%ds" % seconds

func get_formatted_creation_date() -> String:
	return _format_timestamp(creation_date)

func get_formatted_last_played() -> String:
	return _format_timestamp(last_played)

func _format_timestamp(timestamp: int) -> String:
	if timestamp == 0:
		return "Unknown"
	
	var datetime = Time.get_datetime_dict_from_unix_time(timestamp)
	return "%02d/%02d/%04d %02d:%02d" % [
		datetime.month,
		datetime.day,
		datetime.year,
		datetime.hour,
		datetime.minute
	]

func get_days_since_creation() -> int:
	var current_time = Time.get_unix_time_from_system()
	var seconds_passed = current_time - creation_date
	return int(seconds_passed / 86400)  # 86400 seconds in a day

func get_days_since_last_played() -> int:
	var current_time = Time.get_unix_time_from_system()
	var seconds_passed = current_time - last_played
	return int(seconds_passed / 86400)

func update_statistic(stat_name: String, value):
	if statistics.has(stat_name):
		if typeof(statistics[stat_name]) == TYPE_INT:
			statistics[stat_name] += int(value)
		elif typeof(statistics[stat_name]) == TYPE_FLOAT:
			statistics[stat_name] += float(value)
