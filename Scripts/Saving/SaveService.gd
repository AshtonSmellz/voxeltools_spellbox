extends Node
# SaveService singleton - no class_name needed for autoloads

const CHAR_DIR := "user://characters"

static func make_id() -> String:
	var c := Crypto.new()
	return c.generate_random_bytes(16).hex_encode()

static func _char_dir(id: String) -> String:
	return "%s/%s" % [CHAR_DIR, id]

static func ensure_dirs() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CHAR_DIR))

static func save_character(id: String, data: CharacterData) -> void:
	ensure_dirs()
	var dir := _char_dir(id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	data.last_played = int(Time.get_unix_time_from_system())
	var path := "%s/character.tres" % dir
	var err := ResourceSaver.save(data, path)
	if err != OK:
		push_error("Failed to save character: %s" % id)

static func load_character(id: String) -> CharacterData:
	var path := "%s/character.tres" % _char_dir(id)
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as CharacterData

static func rename_character(id: String, new_name: String) -> void:
	var data := load_character(id)
	if data == null: return
	data.name = new_name
	save_character(id, data)

static func touch_last_played(id: String) -> void:
	var data := load_character(id)
	if data == null: return
	data.last_played = int(Time.get_unix_time_from_system())
	save_character(id, data)

static func write_icon(id: String, image: Image) -> void:
	var dir := _char_dir(id)
	var path := "%s/icon.png" % dir
	image.save_png(path)

static func delete_character(id: String) -> void:
	var base := _char_dir(id)
	_delete_recursive(base)

static func _delete_recursive(path: String) -> void:
	var d := DirAccess.open(path)
	if d:
		for f in d.get_files():
			d.remove("%s/%s" % [path, f])
		for sub in d.get_directories():
			_delete_recursive("%s/%s" % [path, sub])
	# remove the now-empty directory
	var abs := ProjectSettings.globalize_path(path)
	var root := DirAccess.open("user://")
	if root:
		root.remove_absolute(abs)
