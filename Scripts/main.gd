# main.gd — manager-centric bootstrap that preserves prior functionality
extends Node

# -----------------------
# Scene wiring (set these in the Inspector if your node names differ)
# -----------------------
@export_node_path("Node") var voxel_world_manager_path
@export_node_path("Node") var terrain_path
@export_node_path("Node") var player_spawn_path
@export_node_path("CanvasItem") var debug_label_path
@export var player_scene: PackedScene

# -----------------------
# World resources & options
# -----------------------
@export var use_runtime_setup := true
@export var library_path := "res://VoxelToolFiles/voxel_blocky_library.tres"
@export var mesher_path  := "res://VoxelToolFiles/voxel_mesher_blocky.tres"
@export var generator_path := ""            # optional: e.g. "res://VoxelToolFiles/fast_noise_generator.tres"
@export var save_path := ""                 # optional: e.g. "user://worlds/slot1"
@export var world_seed: int = 1337
@export var initial_region_radius_chunks := 6

# -----------------------
# Ticking / simulation hooks
# -----------------------
@export var enable_game_tick := true
@export var game_tick_hz := 20.0
@export var enable_random_tick := true
@export var random_tick_hz := 2.0

# -----------------------
# Time of day / lighting
# -----------------------
@export var enable_time_of_day := false
@export var minutes_per_day := 20.0

# -----------------------
# Internals
# -----------------------
const PATH_MANAGER_FALLBACK := "res://Scripts/Blocks/VoxelWorldManager.gd"

var _mgr: Node
var _terrain: Node
var _player: Node
var _debug_label: CanvasItem
var _game_timer: Timer
var _random_timer: Timer
var _clock_timer: Timer
var _clock_minutes := 8.0 * 60.0

func _ready() -> void:
	_mgr = _get_or_make_manager()
	if _mgr == null:
		push_error("[main] No VoxelWorldManager available.")
		return

	_terrain = _get_or_find_terrain()
	if _terrain == null:
		push_error("[main] No terrain node found.")
		return

	_player = _ensure_player()
	_debug_label = debug_label_path and get_node_or_null(debug_label_path)

	if use_runtime_setup:
		_configure_world()

	_connect_manager_signals()
	_setup_timers()
	
	# Connect VoxelWorldManager to WorldSaveSystem singleton
	if _mgr is VoxelWorldManager:
		WorldSaveSystem.set_voxel_world_manager(_mgr)
	
	_bootstrap_world()
	print("[main] Initialization complete.")

# ... (rest of the script stays the same as the version I sent before)


# -------------------------------------------------------------------------
# SETUP HELPERS
# -------------------------------------------------------------------------

func _get_or_make_manager() -> Node:
	# A) Explicit reference
	if voxel_world_manager_path:
		var n := get_node_or_null(voxel_world_manager_path)
		if n != null:
			return n

	# B) Heuristic by name
	for c in get_children():
		if c.name.begins_with("VoxelWorldManager"):
			return c

	# C) Instance from script on disk
	if ResourceLoader.exists(PATH_MANAGER_FALLBACK):
		var S := load(PATH_MANAGER_FALLBACK)
		if S:
			var inst: Node = S.new()
			inst.name = "VoxelWorldManager"
			add_child(inst)
			return inst

	# D) Last resort placeholder
	var fallback := Node.new()
	fallback.name = "VoxelWorldManager"
	add_child(fallback)
	push_warning("[main] Using placeholder manager; some features will be disabled.")
	return fallback

func _get_or_find_terrain() -> Node:
	if terrain_path:
		var n := get_node_or_null(terrain_path)
		if n: return n
	var n1 := get_node_or_null("VoxelTerrain")
	if n1: return n1
	var n2 := get_node_or_null("VoxelLodTerrain")
	if n2: return n2
	# shallow scan
	for c in get_children():
		if c and (c.get_class() == "VoxelTerrain" or c.get_class() == "VoxelLodTerrain"):
			return c
	return null

func _ensure_player() -> Node:
	# If a player already exists as a child, use it
	for c in get_children():
		if c and c.name.begins_with("Player"):
			return c
	# Else instance from scene if provided
	if player_scene:
		var p := player_scene.instantiate()
		p.name = "Player"
		add_child(p)
		_position_player_at_spawn(p)
		return p
	return null

func _position_player_at_spawn(p: Node) -> void:
	if player_spawn_path:
		var sp := get_node_or_null(player_spawn_path)
		if sp and sp is Node3D and p is Node3D:
			p.global_transform = sp.global_transform

func _configure_world() -> void:
	var lib := _safe_load(library_path)
	var mesher := _safe_load(mesher_path)
	var gen := _safe_load(generator_path) if generator_path != "" else null


	# Preferred: let manager configure everything if it exposes a function
	if _mgr.has_method("configure"):
		_mgr.call("configure", {
			"terrain": _terrain,
			"library": lib,
			"mesher": mesher,
			"generator": gen,
			"seed": world_seed,
			"save_path": save_path,
			"initial_region_radius_chunks": initial_region_radius_chunks
		})
		return

	# Compatibility: assign directly if manager doesn't do it
	_assign_mesher_and_library(_terrain, mesher, lib)

	# If manager exposes individual setters, use them
	if gen and _mgr.has_method("set_generator"):
		_mgr.call("set_generator", gen)
	if _mgr.has_method("set_seed"):
		_mgr.call("set_seed", world_seed)
	if save_path != "" and _mgr.has_method("set_save_path"):
		_mgr.call("set_save_path", save_path)
	if _mgr.has_method("set_player"):
		_mgr.call("set_player", _player)

func _assign_mesher_and_library(terrain: Node, mesher: Resource, lib: Resource) -> void:
	var mesher_set := false
	if terrain and "mesher" in terrain:
		terrain.mesher = mesher
		mesher_set = true
	elif terrain and terrain.has_method("set_mesher"):
		terrain.call("set_mesher", mesher)
		mesher_set = true
	if mesher:
		if "library" in mesher:
			mesher.library = lib
		elif mesher.has_method("set_library"):
			mesher.call("set_library", lib)
	if not mesher_set:
		push_warning("[main] Could not assign mesher to terrain (plugin API mismatch?).")

func _connect_manager_signals() -> void:
	var map = {
		"chunk_generated": "_on_chunk_generated",
		"region_generated": "_on_region_generated",
		"block_updated": "_on_block_updated",
		"save_requested": "_on_save_requested",
		"error": "_on_manager_error",
		"info": "_on_manager_info"
	}
	for sig in map.keys():
		if _mgr.has_signal(sig):
			_mgr.connect(sig, Callable(self, map[sig]))

func _setup_timers() -> void:
	if enable_game_tick and _mgr.has_method("game_tick"):
		_game_timer = Timer.new()
		_game_timer.one_shot = false
		_game_timer.wait_time = 1.0 / max(1.0, game_tick_hz)
		add_child(_game_timer)
		_game_timer.timeout.connect(func(): _mgr.call("game_tick"))
		_game_timer.start()

	if enable_random_tick and _mgr.has_method("random_tick"):
		_random_timer = Timer.new()
		_random_timer.one_shot = false
		_random_timer.wait_time = 1.0 / max(0.1, random_tick_hz)
		add_child(_random_timer)
		_random_timer.timeout.connect(func(): _mgr.call("random_tick"))
		_random_timer.start()

	if enable_time_of_day and _mgr.has_method("set_time_of_day_minutes"):
		_clock_timer = Timer.new()
		_clock_timer.one_shot = false
		_clock_timer.wait_time = 0.25
		add_child(_clock_timer)
		_clock_timer.timeout.connect(_advance_clock)
		_clock_timer.start()

func _bootstrap_world() -> void:
	# Preferred: manager handles load/create
	if save_path != "" and _mgr.has_method("load_world"):
		var ok: bool = _mgr.has_method("load_world") and (_mgr.call("load_world") == true)
		if ok == true:
			if _mgr.has_method("post_load_warmup"):
				_mgr.call("post_load_warmup")
			return

	# No save or failed to load — create new
	if _mgr.has_method("create_world"):
		_mgr.call("create_world", {
			"seed": world_seed,
			# In _bootstrap_world():
			"around_position": (_player as Node3D).global_transform.origin if _player is Node3D else Vector3.ZERO
		})
	elif _mgr.has_method("pregenerate_region"):
		var center: Vector3 = (_player as Node3D).global_transform.origin if _player is Node3D else Vector3.ZERO
		_mgr.call("pregenerate_region", center, initial_region_radius_chunks)

# -------------------------------------------------------------------------
# RUNTIME
# -------------------------------------------------------------------------

func _process(_dt: float) -> void:
	_update_debug_label()

func _input(event: InputEvent) -> void:
	# Forward input to manager if it wants it
	if _mgr and _mgr.has_method("_input_from_main"):
		_mgr.call("_input_from_main", event)

# -------------------------------------------------------------------------
# CLOCK / LIGHTING
# -------------------------------------------------------------------------

func _advance_clock() -> void:
	if not enable_time_of_day:
		return
	var minutes_per_tick := (24.0 * 60.0) / (minutes_per_day * (1.0 / _clock_timer.wait_time))
	_clock_minutes = fmod(_clock_minutes + minutes_per_tick, 24.0 * 60.0)
	if _mgr.has_method("set_time_of_day_minutes"):
		_mgr.call("set_time_of_day_minutes", _clock_minutes)

# -------------------------------------------------------------------------
# SIGNAL HANDLERS (only used if manager exposes signals)
# -------------------------------------------------------------------------

func _on_chunk_generated(pos) -> void:
	# Hook for effects/analytics
	pass

func _on_region_generated(aabb) -> void:
	pass

func _on_block_updated(vpos: Vector3i) -> void:
	pass

func _on_save_requested() -> void:
	if _mgr.has_method("save_world"):
		_mgr.call("save_world")

func _on_manager_error(msg: String) -> void:
	push_error("[VoxelWorldManager] " + msg)

func _on_manager_info(msg: String) -> void:
	print("[VoxelWorldManager] " + msg)

# -------------------------------------------------------------------------
# UTIL
# -------------------------------------------------------------------------

func _update_debug_label() -> void:
	if _debug_label == null:
		return
	var lines := PackedStringArray()
	lines.append("FPS: %d" % Engine.get_frames_per_second())
	if _mgr:
		if _mgr.has_method("get_loaded_chunk_count"):
			lines.append("Chunks: %s" % str(_mgr.call("get_loaded_chunk_count")))
		if _mgr.has_method("get_active_block_updates"):
			lines.append("Active Updates: %s" % str(_mgr.call("get_active_block_updates")))
		if enable_time_of_day:
			lines.append("Time: %02d:%02d" % [int(_clock_minutes/60.0), int(_clock_minutes)%60])
	var txt := "\n".join(lines)
	if "text" in _debug_label:
		_debug_label.text = txt
	elif _debug_label.has_method("set_text"):
		_debug_label.call("set_text", txt)

func _safe_load(p: String) -> Resource:
	if p == null or p == "":
		return null
	if ResourceLoader.exists(p):
		var r := load(p)
		if r == null:
			push_warning("[main] Failed to load resource at %s" % p)
		return r
	push_warning("[main] Resource not found: %s" % p)
	return null
