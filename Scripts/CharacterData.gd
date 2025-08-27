extends Resource
class_name CharacterData

@export var version: int = 1
@export var name: String = "New Hero"
@export var level: int = 1
@export var archetype: String = "Adventurer"
@export var stats: Dictionary = {}
@export var inventory: Array = []
@export var last_played: int = 0  # unix timestamp
@export var created: int = 0      # unix timestamp
@export var playtime: int = 0     # seconds played

func _init():
	if created == 0:
		created = int(Time.get_unix_time_from_system())
		last_played = created

func get_last_played_formatted() -> String:
	if last_played <= 0:
		return "Never"
	var dt = Time.get_datetime_dict_from_unix_time(last_played)
	return "%04d-%02d-%02d" % [dt.year, dt.month, dt.day]

func get_playtime_formatted() -> String:
	if playtime <= 0:
		return "0m"
	var hours = playtime / 3600
	var minutes = (playtime % 3600) / 60
	if hours > 0:
		return "%dh %dm" % [hours, minutes]
	else:
		return "%dm" % minutes
