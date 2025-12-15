extends Node3D
class_name DayNightCycle

## Day/Night Cycle Controller
## Rotates the directional light and updates the world environment over time

# -----------------------
# Configuration
# -----------------------
@export var enabled: bool = true
@export var minutes_per_day: float = 20.0  # Real-world minutes for a full day cycle
@export var start_time_hours: float = 8.0  # Starting time (0-24 hours)
@export var sun_rotation_axis: Vector3 = Vector3(0, 0, 1)  # Axis around which sun rotates

# -----------------------
# Light Settings
# -----------------------
@export_group("Sun Light")
@export var sun_light_path: NodePath = "DirectionalLight3D"
@export var sun_light_intensity_day: float = 1.0
@export var sun_light_intensity_night: float = 0.1
@export var sun_color_day: Color = Color(1.0, 0.95, 0.9, 1.0)  # Warm daylight
@export var sun_color_dawn: Color = Color(1.0, 0.7, 0.5, 1.0)  # Orange dawn
@export var sun_color_dusk: Color = Color(1.0, 0.6, 0.4, 1.0)  # Reddish dusk
@export var sun_color_night: Color = Color(0.3, 0.4, 0.6, 1.0)  # Cool moonlight

# -----------------------
# Environment Settings
# -----------------------
@export_group("World Environment")
@export var world_environment_path: NodePath = "WorldEnvironment"
@export var ambient_light_day: float = 1.18
@export var ambient_light_night: float = 0.15  # Subtle starlight
@export var ambient_light_color_day: Color = Color(0.4, 0.67, 0.67, 1.0)  # Sky blue tint
@export var ambient_light_color_night: Color = Color(0.1, 0.15, 0.25, 1.0)  # Dark blue starlight
@export var fog_color_day: Color = Color(0.44, 0.85, 0.95, 1.0)  # Sky blue
@export var fog_color_night: Color = Color(0.05, 0.05, 0.15, 1.0)  # Dark blue
@export var fog_energy_day: float = 0.59
@export var fog_energy_night: float = 0.1
@export var disable_sun_below_horizon: bool = true  # Disable sun light when below horizon

# -----------------------
# Sky Settings
# -----------------------
@export_group("Sky")
@export var sky_ground_color_day: Color = Color(0.15, 0.09, 0.07, 1.0)
@export var sky_ground_color_night: Color = Color(0.02, 0.02, 0.05, 1.0)
@export var sky_energy_multiplier_day: float = 3.0
@export var sky_energy_multiplier_night: float = 0.5  # Subtle starlight
@export var sky_rayleigh_coefficient_day: float = 7.53
@export var sky_rayleigh_coefficient_night: float = 0.5  # Less atmospheric scattering at night
@export var sky_turbidity_day: float = 107.46
@export var sky_turbidity_night: float = 5.0  # Clear sky at night

# -----------------------
# Moon Settings
# -----------------------
@export_group("Moon")
@export var moon_enabled: bool = true
@export var moon_path: NodePath = "Moon"
@export var moon_size: float = 2.0
@export var moon_distance: float = 100.0
@export var moon_offset_hours: float = 12.0  # Moon is opposite to sun (12 hours offset)
@export var moon_color: Color = Color(0.9, 0.9, 0.95, 1.0)
@export var moon_brightness: float = 0.3

# -----------------------
# Stars Settings
# -----------------------
@export_group("Stars")
@export var stars_enabled: bool = true
@export var stars_path: NodePath = "Stars"
@export var stars_radius: float = 500.0
@export var stars_count: int = 500
@export var stars_brightness: float = 1.0

# -----------------------
# Time Definitions (in hours)
# -----------------------
const DAWN_START: float = 5.0
const DAWN_END: float = 7.0
const DAY_START: float = 7.0
const DAY_END: float = 18.0
const DUSK_START: float = 18.0
const DUSK_END: float = 20.0
const NIGHT_START: float = 20.0
const NIGHT_END: float = 5.0

# -----------------------
# Internal State
# -----------------------
var _directional_light: DirectionalLight3D
var _world_environment: WorldEnvironment
var _moon: MeshInstance3D
var _stars: MultiMeshInstance3D
var _current_time_hours: float = 8.0
var _time_speed: float = 1.0  # Multiplier for time speed

func _ready():
	# Get references to child nodes
	_directional_light = get_node_or_null(sun_light_path)
	if not _directional_light:
		push_error("DayNightCycle: DirectionalLight3D not found at path: " + str(sun_light_path))
	
	_world_environment = get_node_or_null(world_environment_path)
	if not _world_environment:
		push_error("DayNightCycle: WorldEnvironment not found at path: " + str(world_environment_path))
	
	# Create moon if enabled
	if moon_enabled:
		_create_moon()
	
	# Create stars if enabled
	if stars_enabled:
		_create_stars()
	
	# Initialize time
	_current_time_hours = start_time_hours
	
	# Calculate time speed (hours per second)
	_time_speed = 24.0 / (minutes_per_day * 60.0)
	
	# Initial update
	_update_lighting()

func _process(delta: float):
	if not enabled:
		return
	
	# Advance time
	_current_time_hours += _time_speed * delta
	
	# Wrap around 24-hour cycle
	if _current_time_hours >= 24.0:
		_current_time_hours = fmod(_current_time_hours, 24.0)
	elif _current_time_hours < 0.0:
		_current_time_hours = 24.0 + fmod(_current_time_hours, 24.0)
	
	# Update lighting and environment
	_update_lighting()

func _update_lighting():
	if not _directional_light or not _world_environment:
		return
	
	# Calculate sun rotation based on time
	# Sun rises in east (6 hours = sunrise)
	# Sun at zenith at noon (12 hours)
	# Sun sets in west (18 hours = sunset)
	# Convert time to angle: 0 hours = midnight (sun below), 12 hours = noon (sun above)
	var time_normalized: float = _current_time_hours / 24.0
	var sun_angle: float = time_normalized * TAU - PI / 2.0
	
	# Calculate sun elevation (how high in the sky)
	# sin(angle) gives us elevation: -1 (below horizon) to 1 (zenith)
	var sun_elevation: float = sin(sun_angle)
	
	# Check if sun is below horizon
	var sun_below_horizon: bool = sun_elevation < 0.0
	
	# Calculate sun direction vector
	# Sun moves in a circle: east (6h) -> zenith (12h) -> west (18h) -> below (0h)
	# For directional light, we want it to point toward the sun's position
	var sun_azimuth: float = cos(sun_angle)  # East-west: 1 (east) to -1 (west)
	
	# Calculate elevation angle (how high sun is)
	# When sun is at zenith (12h), elevation should be 90 degrees (pointing straight down)
	# When sun is at horizon (6h or 18h), elevation should be 0 degrees (pointing horizontally)
	# When sun is below horizon, we want to keep it pointing down
	var elevation_rad: float = -sun_angle  # Negative because we want to point down when sun is up
	
	# Calculate azimuth angle (east-west rotation) BEFORE clamping elevation
	# When sun is in east (6h), azimuth should be 0
	# When sun is in west (18h), azimuth should be 180
	# Use a stable calculation that doesn't cause jumps
	var azimuth_rad: float = atan2(sun_azimuth, max(abs(sun_elevation), 0.01))  # Avoid division by zero
	
	# When sun is below horizon, clamp elevation to prevent upward lighting
	if sun_below_horizon and disable_sun_below_horizon:
		# Keep elevation between -90 (straight down) and 0 (horizontal)
		elevation_rad = clamp(elevation_rad, -PI / 2.0, 0.0)
		
		# Smoothly reduce azimuth rotation to prevent sudden flips
		# Interpolate azimuth to neutral (0) as sun goes further below horizon
		var elevation_magnitude: float = abs(sun_elevation)
		var azimuth_fade_start: float = 0.05  # Start fading azimuth at 5% below horizon
		var azimuth_fade_end: float = 0.15    # Complete fade at 15% below horizon
		
		if elevation_magnitude > azimuth_fade_start:
			var azimuth_fade_t: float = clamp((elevation_magnitude - azimuth_fade_start) / (azimuth_fade_end - azimuth_fade_start), 0.0, 1.0)
			azimuth_fade_t = azimuth_fade_t * azimuth_fade_t * (3.0 - 2.0 * azimuth_fade_t)  # Smoothstep
			azimuth_rad = lerp(azimuth_rad, 0.0, azimuth_fade_t)  # Smoothly transition to neutral
	
	# Convert to degrees and set rotation
	# X rotation controls elevation (up-down), Y rotation controls azimuth (east-west)
	_directional_light.rotation_degrees = Vector3(
		rad_to_deg(elevation_rad),
		rad_to_deg(azimuth_rad),
		0.0
	)
	
	# Calculate time-of-day factors
	var time_factor: float = _get_time_factor()
	var is_day: bool = _current_time_hours >= DAY_START and _current_time_hours < DAY_END
	var is_dawn: bool = _current_time_hours >= DAWN_START and _current_time_hours < DAWN_END
	var is_dusk: bool = _current_time_hours >= DUSK_START and _current_time_hours < DUSK_END
	var is_night: bool = _current_time_hours >= NIGHT_START or _current_time_hours < DAWN_START
	
	# Interpolate light color based on time of day and sun elevation
	var light_color: Color
	
	# Use sun elevation to smooth color transitions, especially at dusk->night boundary
	if sun_elevation > 0.0:  # Sun above horizon
		if is_day:
			light_color = sun_color_day
		elif is_dawn:
			var t: float = (_current_time_hours - DAWN_START) / (DAWN_END - DAWN_START)
			light_color = sun_color_dawn.lerp(sun_color_day, t)
		elif is_dusk:
			var t: float = (_current_time_hours - DUSK_START) / (DUSK_END - DUSK_START)
			light_color = sun_color_day.lerp(sun_color_dusk, t)
		else:  # Shouldn't happen when sun is above horizon, but fallback
			light_color = sun_color_day
	else:  # Sun below horizon
		if is_dusk:
			# During dusk transition, smoothly blend to night color as sun sets
			var dusk_t: float = (_current_time_hours - DUSK_START) / (DUSK_END - DUSK_START)
			var elevation_factor: float = clamp(abs(sun_elevation) / 0.3, 0.0, 1.0)  # Fade based on elevation
			var dusk_color: Color = sun_color_day.lerp(sun_color_dusk, dusk_t)
			light_color = dusk_color.lerp(sun_color_night, elevation_factor)
		else:  # Night
			light_color = sun_color_night
	
	# Interpolate light intensity based on sun elevation for smooth transitions
	# Key: Intensity should ALWAYS decrease as sun goes below horizon, never increase
	var light_intensity: float
	
	# Calculate what the intensity should be based purely on sun elevation
	# This ensures smooth, monotonic decrease as sun sets
	if sun_elevation > 0.0:  # Sun above horizon
		# Map elevation (0 to 1) to intensity (night to day)
		# Use smooth curve for natural transition
		var elevation_normalized: float = clamp(sun_elevation, 0.0, 1.0)
		# Apply smoothstep for more natural curve
		var elevation_curve: float = elevation_normalized * elevation_normalized * (3.0 - 2.0 * elevation_normalized)
		
		# Interpolate between night and day intensity based on elevation
		# At horizon (elevation = 0), use night intensity
		# At zenith (elevation = 1), use day intensity
		light_intensity = lerp(sun_light_intensity_night, sun_light_intensity_day, elevation_curve)
		
		# Apply time-of-day modulation for dawn/dusk colors (but keep intensity smooth)
		if is_dawn or is_dusk:
			# Slight reduction during transitions for realism
			var transition_factor: float = 0.9  # 10% reduction during transitions
			light_intensity *= transition_factor
	else:  # Sun below horizon
		# CRITICAL: Intensity must ONLY decrease as sun goes further below horizon
		var elevation_magnitude: float = abs(sun_elevation)
		
		# Fade out completely over first 20% below horizon
		var fade_end: float = 0.2  # 20% below horizon
		
		if elevation_magnitude <= fade_end:
			# Smooth fade from night intensity at horizon to zero
			var fade_t: float = elevation_magnitude / fade_end
			# Use smoothstep for smoother curve
			fade_t = fade_t * fade_t * (3.0 - 2.0 * fade_t)  # Smoothstep function
			# Start from night intensity, fade to zero
			light_intensity = sun_light_intensity_night * (1.0 - fade_t)
		else:
			# Well below horizon - completely off
			light_intensity = 0.0
		
		# Force to 0 if well below horizon and disable flag is set
		if disable_sun_below_horizon and elevation_magnitude > 0.15:
			light_intensity = 0.0
	
	# Apply light properties
	_directional_light.light_color = light_color
	_directional_light.light_energy = light_intensity
	
	# Update moon position
	if moon_enabled and _moon:
		_update_moon()
	
	# Update stars visibility
	if stars_enabled and _stars:
		_update_stars(is_night, time_factor)
	
	# Update environment
	_update_environment(time_factor, is_day, is_night)

func _update_environment(time_factor: float, is_day: bool, is_night: bool):
	if not _world_environment or not _world_environment.environment:
		return
	
	var env: Environment = _world_environment.environment
	
	# Update ambient light
	var ambient_energy: float
	var ambient_color: Color
	if is_day:
		ambient_energy = ambient_light_day
		ambient_color = ambient_light_color_day
	elif is_night:
		ambient_energy = ambient_light_night
		ambient_color = ambient_light_color_night
	else:
		ambient_energy = lerp(ambient_light_night, ambient_light_day, time_factor)
		ambient_color = ambient_light_color_night.lerp(ambient_light_color_day, time_factor)
	
	env.ambient_light_energy = ambient_energy
	env.ambient_light_color = ambient_color
	
	# Update fog
	if env.fog_enabled:
		var fog_color: Color
		var fog_energy: float
		
		if is_day:
			fog_color = fog_color_day
			fog_energy = fog_energy_day
		elif is_night:
			fog_color = fog_color_night
			fog_energy = fog_energy_night
		else:
			fog_color = fog_color_night.lerp(fog_color_day, time_factor)
			fog_energy = lerp(fog_energy_night, fog_energy_day, time_factor)
		
		env.fog_light_color = fog_color
		env.fog_light_energy = fog_energy
	
	# Update sky material properties if using PhysicalSkyMaterial
	if env.sky and env.sky.sky_material is PhysicalSkyMaterial:
		var sky_material: PhysicalSkyMaterial = env.sky.sky_material as PhysicalSkyMaterial
		
		# Update ground color
		var ground_color: Color
		if is_day:
			ground_color = sky_ground_color_day
		elif is_night:
			ground_color = sky_ground_color_night
		else:
			ground_color = sky_ground_color_night.lerp(sky_ground_color_day, time_factor)
		sky_material.ground_color = ground_color
		
		# Update energy multiplier for night sky (starlight effect)
		var energy_multiplier: float
		if is_day:
			energy_multiplier = sky_energy_multiplier_day
		elif is_night:
			energy_multiplier = sky_energy_multiplier_night
		else:
			energy_multiplier = lerp(sky_energy_multiplier_night, sky_energy_multiplier_day, time_factor)
		sky_material.energy_multiplier = energy_multiplier
		
		# Update rayleigh coefficient (atmospheric scattering)
		var rayleigh_coefficient: float
		if is_day:
			rayleigh_coefficient = sky_rayleigh_coefficient_day
		elif is_night:
			rayleigh_coefficient = sky_rayleigh_coefficient_night
		else:
			rayleigh_coefficient = lerp(sky_rayleigh_coefficient_night, sky_rayleigh_coefficient_day, time_factor)
		sky_material.rayleigh_coefficient = rayleigh_coefficient
		
		# Update turbidity (sky clarity - lower = clearer)
		var turbidity: float
		if is_day:
			turbidity = sky_turbidity_day
		elif is_night:
			turbidity = sky_turbidity_night
		else:
			turbidity = lerp(sky_turbidity_night, sky_turbidity_day, time_factor)
		sky_material.turbidity = turbidity
		
		# Update rayleigh color for night (darker, more blue/purple)
		var rayleigh_color: Color
		if is_day:
			rayleigh_color = Color(0.0723563, 0.865472, 1, 1)  # Day sky blue
		elif is_night:
			rayleigh_color = Color(0.02, 0.05, 0.15, 1)  # Dark night blue
		else:
			rayleigh_color = Color(0.02, 0.05, 0.15, 1).lerp(Color(0.0723563, 0.865472, 1, 1), time_factor)
		sky_material.rayleigh_color = rayleigh_color
		
		# Note: PhysicalSkyMaterial doesn't support stars directly
		# Stars are handled via the moon and ambient lighting for now
		# For full star support, consider using ProceduralSkyMaterial or a custom sky shader

func _get_time_factor() -> float:
	# Returns 0.0 (night) to 1.0 (day) based on current time
	var hour: float = _current_time_hours
	
	if hour >= DAY_START and hour < DAY_END:
		return 1.0
	elif hour >= NIGHT_START or hour < DAWN_START:
		return 0.0
	elif hour >= DAWN_START and hour < DAY_START:
		# Dawn transition
		return (hour - DAWN_START) / (DAY_START - DAWN_START)
	else:  # Dusk
		return 1.0 - ((hour - DUSK_START) / (DUSK_END - DUSK_START))

## Get current time in hours (0-24)
func get_time_hours() -> float:
	return _current_time_hours

## Set time in hours (0-24)
func set_time_hours(hours: float):
	_current_time_hours = clamp(hours, 0.0, 24.0)
	_update_lighting()

## Get current time as formatted string (HH:MM)
func get_time_string() -> String:
	var hours: int = int(_current_time_hours)
	var minutes: int = int((_current_time_hours - hours) * 60.0)
	return "%02d:%02d" % [hours, minutes]

## Enable or disable the day/night cycle
func set_enabled(value: bool):
	enabled = value

func _create_moon():
	# Create moon mesh instance
	_moon = get_node_or_null(moon_path)
	if not _moon:
		_moon = MeshInstance3D.new()
		_moon.name = "Moon"
		
		# Create sphere mesh for moon
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = moon_size
		sphere_mesh.height = moon_size * 2.0
		sphere_mesh.radial_segments = 32
		sphere_mesh.rings = 16
		_moon.mesh = sphere_mesh
		
		# Create material for moon
		var moon_material = StandardMaterial3D.new()
		moon_material.albedo_color = moon_color
		moon_material.emission_enabled = true
		moon_material.emission = moon_color * moon_brightness
		moon_material.emission_energy_multiplier = 2.0
		moon_material.roughness = 0.8
		moon_material.metallic = 0.0
		_moon.material_override = moon_material
		
		# Add to scene
		add_child(_moon)
	
	# Set initial position
	_update_moon()

func _update_moon():
	if not _moon:
		return
	
	# Calculate moon position (opposite to sun)
	var moon_time_hours: float = fmod(_current_time_hours + moon_offset_hours, 24.0)
	var moon_time_normalized: float = moon_time_hours / 24.0
	var moon_angle: float = moon_time_normalized * TAU - PI / 2.0
	
	# Calculate moon elevation
	var moon_elevation: float = sin(moon_angle)
	
	# Only show moon when it's above horizon
	if moon_elevation > 0.0:
		_moon.visible = true
		
		# Calculate moon position in sky
		var moon_direction: Vector3 = Vector3(
			cos(moon_angle),
			sin(moon_angle),
			0.0
		).normalized()
		
		# Position moon at distance
		_moon.global_position = moon_direction * moon_distance
		
		# Make moon face the camera (billboard effect)
		_moon.look_at(Vector3.ZERO, Vector3.UP)
	else:
		_moon.visible = false

func _create_stars():
	# Create stars using MultiMeshInstance3D for performance
	_stars = get_node_or_null(stars_path)
	if not _stars:
		_stars = MultiMeshInstance3D.new()
		_stars.name = "Stars"
		
		# Create multimesh
		var multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.instance_count = stars_count
		multimesh.mesh = _create_star_mesh()
		
		_stars.multimesh = multimesh
		_stars.material_override = _create_star_material()
		add_child(_stars)
	
	# Generate random star positions on a sphere
	_generate_star_positions()

func _create_star_mesh() -> QuadMesh:
	# Create a small quad for each star
	var quad = QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)  # Small stars
	return quad

func _create_star_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.flags_unshaded = true
	material.albedo_color = Color.WHITE
	material.emission_enabled = true
	material.emission = Color.WHITE * stars_brightness
	material.emission_energy_multiplier = 3.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Always visible
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED  # Don't write to depth
	return material

func _generate_star_positions():
	if not _stars or not _stars.multimesh:
		return
	
	var multimesh = _stars.multimesh
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	for i in range(stars_count):
		# Generate random position on sphere surface
		var theta: float = rng.randf() * TAU  # Azimuth
		var phi: float = acos(2.0 * rng.randf() - 1.0)  # Elevation (uniform distribution)
		
		# Convert to cartesian coordinates
		var x: float = stars_radius * sin(phi) * cos(theta)
		var y: float = stars_radius * sin(phi) * sin(theta)
		var z: float = stars_radius * cos(phi)
		
		# Create transform
		var transform = Transform3D()
		transform.origin = Vector3(x, y, z)
		
		# Make star face center (billboard)
		transform = transform.looking_at(Vector3.ZERO, Vector3.UP)
		
		# Random scale for variety
		var scale: float = rng.randf_range(0.5, 1.5)
		transform = transform.scaled(Vector3(scale, scale, 1.0))
		
		multimesh.set_instance_transform(i, transform)
		
		# Random color (slight variation)
		var color_variation: float = rng.randf_range(0.8, 1.0)
		multimesh.set_instance_color(i, Color(color_variation, color_variation, color_variation, 1.0))

func _update_stars(is_night: bool, time_factor: float):
	if not _stars:
		return
	
	# Calculate star visibility alpha
	var star_alpha: float
	if is_night:
		star_alpha = 1.0
	else:
		# Fade stars during dawn/dusk
		star_alpha = 1.0 - time_factor
	
	# Update visibility and material alpha
	if star_alpha > 0.01:  # Small threshold to avoid flickering
		_stars.visible = true
		# Update material alpha if material exists
		if _stars.material_override and _stars.material_override is StandardMaterial3D:
			var material: StandardMaterial3D = _stars.material_override as StandardMaterial3D
			var base_color = material.albedo_color
			base_color.a = star_alpha
			material.albedo_color = base_color
			# Also adjust emission
			var emission_color = material.emission
			emission_color.a = star_alpha
			material.emission = emission_color
	else:
		_stars.visible = false
