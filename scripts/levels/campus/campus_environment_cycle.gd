extends Node
class_name CampusEnvironmentCycle

## Lightweight campus clock, sky, automatic facility lighting and two-state
## weather controller. One localized rain volume follows the active camera and
## pauses under a roof; it does not simulate rain across the whole 156x188m map.
signal display_changed(text: String)
signal phase_changed(phase: StringName)
signal weather_changed(weather: StringName)
signal new_day_started(day_number: int, weather: StringName)

enum WeatherMode { NORMAL, RAINY }

const PHASE_MORNING: StringName = &"MORNING"
const PHASE_DAY: StringName = &"DAY"
const PHASE_EVENING: StringName = &"EVENING"
const PHASE_NIGHT: StringName = &"NIGHT"
const WEATHER_NAMES := [&"NORMAL", &"RAINY"]

@export_group("Clock")
@export var cycle_enabled := true
@export_range(60.0, 3600.0, 1.0) var day_length_seconds := 720.0
@export_range(0.0, 23.99, 0.05) var start_time_hours := 7.0
@export_range(1, 999, 1) var start_day := 1
@export_range(0.02, 0.5, 0.01) var visual_update_interval := 0.1

@export_group("Automatic Lights")
@export_range(16.0, 23.5, 0.25) var lights_on_hour := 18.5
@export_range(3.0, 10.0, 0.25) var lights_off_hour := 7.0

@export_group("Weather")
@export_range(0.0, 1.0, 0.01) var normal_day_rain_chance := 0.25
@export_range(0.0, 1.0, 0.01) var after_rain_chance := 0.10
@export var roll_weather_on_start := true
@export var random_seed: int = 0
@export_range(100, 1200, 25) var rain_particle_count := 650

var time_hours := 7.0
var day_number := 1
var weather_mode: WeatherMode = WeatherMode.NORMAL
var previous_day_was_rainy := false

var _initialized := false
var _phase: StringName = PHASE_MORNING
var _lights_active := false
var _is_indoor_sheltered := false
var _update_accumulator := 0.0
var _shelter_accumulator := 0.0
var _rng := RandomNumberGenerator.new()
var _world_environment: WorldEnvironment
var _environment: Environment
var _sky_material: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _rain: GPUParticles3D


func _ready() -> void:
	add_to_group("campus_environment_cycle")
	time_hours = start_time_hours
	day_number = start_day
	if random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed
	call_deferred("_initialize")


func _initialize() -> void:
	var campus := get_parent()
	_world_environment = campus.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_sun = campus.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if _world_environment is EnvironmentZoneManager:
		_environment = (_world_environment as EnvironmentZoneManager).exterior
		_sky_material = _environment.sky.sky_material as ProceduralSkyMaterial
	elif _world_environment and _world_environment.environment:
		_environment = _world_environment.environment.duplicate(true) as Environment
		_world_environment.environment = _environment
		if _environment.sky:
			_environment.sky = _environment.sky.duplicate(true) as Sky
			if _environment.sky.sky_material is ProceduralSkyMaterial:
				_sky_material = _environment.sky.sky_material.duplicate(true) as ProceduralSkyMaterial
				_environment.sky.sky_material = _sky_material
	_build_rain_volume()
	_initialized = true
	if roll_weather_on_start:
		_roll_weather(_rng.randf())
	_apply_environment(true)


func _process(delta: float) -> void:
	if not _initialized:
		return
	if cycle_enabled:
		var hours_advanced := delta * 24.0 / maxf(day_length_seconds, 1.0)
		_advance_hours(hours_advanced)
	_update_accumulator += delta
	_shelter_accumulator += delta
	if _update_accumulator >= visual_update_interval:
		_update_accumulator = 0.0
		_apply_environment(false)
	if _shelter_accumulator >= 0.25:
		_shelter_accumulator = 0.0
		_update_rain_shelter()


func set_time_hours(value: float) -> void:
	time_hours = fposmod(value, 24.0)
	if _initialized:
		_apply_environment(true)


func set_weather_mode(mode: WeatherMode) -> void:
	var changed := weather_mode != mode
	weather_mode = mode
	if changed:
		weather_changed.emit(get_weather_name())
	if _initialized:
		_apply_environment(true)


func get_current_phase() -> StringName:
	return _phase_for_time(time_hours)


func get_weather_name() -> StringName:
	return WEATHER_NAMES[int(weather_mode)]


func get_display_text() -> String:
	var hour := floori(time_hours)
	var minute := floori((time_hours - float(hour)) * 60.0)
	return "DAY %02d  ·  %02d:%02d  ·  %s  ·  %s" % [day_number, hour, minute, _phase_for_time(time_hours), get_weather_name()]


func get_daily_rain_chance() -> float:
	return after_rain_chance if previous_day_was_rainy else normal_day_rain_chance


func is_dark() -> bool:
	return time_hours >= lights_on_hour or time_hours < lights_off_hour


func debug_begin_new_day(roll: float) -> void:
	# Explicit roll makes the probability transition testable without coupling
	# production weather to a fixed seed.
	_begin_new_day(clampf(roll, 0.0, 1.0))


func debug_advance_hours(hours: float) -> void:
	_advance_hours(maxf(0.0, hours))
	if _initialized:
		_apply_environment(true)


func _advance_hours(hours: float) -> void:
	time_hours += hours
	while time_hours >= 24.0:
		time_hours -= 24.0
		_begin_new_day(_rng.randf())


func _begin_new_day(roll: float) -> void:
	previous_day_was_rainy = weather_mode == WeatherMode.RAINY
	day_number += 1
	_roll_weather(roll)
	new_day_started.emit(day_number, get_weather_name())


func _roll_weather(roll: float) -> void:
	set_weather_mode(WeatherMode.RAINY if roll < get_daily_rain_chance() else WeatherMode.NORMAL)


func _phase_for_time(hour: float) -> StringName:
	if hour >= 5.0 and hour < 9.0:
		return PHASE_MORNING
	if hour >= 9.0 and hour < 17.0:
		return PHASE_DAY
	if hour >= 17.0 and hour < 20.0:
		return PHASE_EVENING
	return PHASE_NIGHT


func _apply_environment(force: bool) -> void:
	var next_phase := _phase_for_time(time_hours)
	if next_phase != _phase:
		_phase = next_phase
		phase_changed.emit(_phase)
	var should_light := is_dark()
	if force or should_light != _lights_active:
		_lights_active = should_light
		_apply_automatic_lights()

	var sample := _sky_sample(time_hours)
	var daylight := float(sample.daylight)
	var rain_factor := 1.0
	if weather_mode == WeatherMode.RAINY:
		rain_factor = 0.58
		sample.top = (sample.top as Color).lerp(Color("313a43"), 0.62)
		sample.horizon = (sample.horizon as Color).lerp(Color("56616a"), 0.68)
	if _sky_material:
		_sky_material.sky_top_color = sample.top
		_sky_material.sky_horizon_color = sample.horizon
		_sky_material.ground_bottom_color = (sample.top as Color).darkened(0.72)
		_sky_material.ground_horizon_color = (sample.horizon as Color).darkened(0.42)
		_sky_material.sky_energy_multiplier = lerpf(0.28, 1.0, daylight) * rain_factor
	if _environment:
		_environment.ambient_light_color = (sample.horizon as Color).lerp(Color("cad1d2"), 0.22)
		_environment.ambient_light_energy = lerpf(0.075, 0.20, daylight) * (0.72 if weather_mode == WeatherMode.RAINY else 1.0)
		_environment.ambient_light_sky_contribution = lerpf(0.12, 0.30, daylight)
		_environment.fog_enabled = true
		_environment.fog_light_color = Color(0.5, 0.52, 0.48, 1) if weather_mode == WeatherMode.NORMAL else Color("66727a")
		_environment.fog_light_energy = lerpf(0.075, 0.45, daylight)
		_environment.fog_sky_affect = 0.4
		_environment.fog_density = 0.015 if weather_mode == WeatherMode.NORMAL else 0.028
	if _world_environment is EnvironmentZoneManager:
		(_world_environment as EnvironmentZoneManager).set_time_state(_lights_active)
	if _sun:
		_sun.light_energy = lerpf(0.0, 1.0, daylight) * (0.48 if weather_mode == WeatherMode.RAINY else 1.0)
		_sun.light_color = _sun_color()
		_sun.shadow_enabled = true
		var daylight_progress := clampf((time_hours - 6.0) / 12.0, 0.0, 1.0)
		_sun.rotation_degrees = Vector3(lerpf(-8.0, -172.0, daylight_progress), -35.0 + time_hours * 4.0, 0.0)
	_update_rain_emission()
	_emit_display()


func _sky_sample(hour: float) -> Dictionary:
	var anchors := [
		{"hour": 0.0, "daylight": 0.015, "top": Color("050814"), "horizon": Color("111827")},
		{"hour": 5.0, "daylight": 0.06, "top": Color("151d31"), "horizon": Color("55453f")},
		{"hour": 8.0, "daylight": 0.72, "top": Color("6f91aa"), "horizon": Color("d2a17c")},
		{"hour": 12.0, "daylight": 1.0, "top": Color("5489b2"), "horizon": Color("a9bbc1")},
		{"hour": 17.0, "daylight": 0.76, "top": Color("58728d"), "horizon": Color("bd9274")},
		{"hour": 20.0, "daylight": 0.07, "top": Color("171b2d"), "horizon": Color("57423d")},
		{"hour": 24.0, "daylight": 0.015, "top": Color("050814"), "horizon": Color("111827")},
	]
	for index in range(anchors.size() - 1):
		var a: Dictionary = anchors[index]
		var b: Dictionary = anchors[index + 1]
		if hour <= float(b.hour):
			var weight := smoothstep(float(a.hour), float(b.hour), hour)
			return {
				"daylight": lerpf(float(a.daylight), float(b.daylight), weight),
				"top": (a.top as Color).lerp(b.top as Color, weight),
				"horizon": (a.horizon as Color).lerp(b.horizon as Color, weight),
			}
	return anchors.back()


func _sun_color() -> Color:
	if _phase == PHASE_MORNING:
		return Color("ffd6aa")
	if _phase == PHASE_EVENING:
		return Color("ffc18f")
	return Color("eef3f4")


func _apply_automatic_lights() -> void:
	var campus := get_parent()
	for node in get_tree().get_nodes_in_group("cell_lamps"):
		if campus.is_ancestor_of(node) and node.has_method("set_night_active"):
			node.call("set_night_active", _lights_active)
	for node in get_tree().get_nodes_in_group("campus_indoor_lights"):
		if campus.is_ancestor_of(node) and node is Light3D:
			(node as Light3D).visible = _lights_active or bool(node.get_meta("always_on", false))
	for node in get_tree().get_nodes_in_group("campus_indoor_light_visuals"):
		if campus.is_ancestor_of(node) and node is GeometryInstance3D:
			(node as GeometryInstance3D).visible = _lights_active or bool(node.get_meta("always_on", false))
	# Keep every tower's lens/beam readable at night. Their shadow maps are
	# disabled whenever the viewer is inside a building, where the exterior
	# beams cannot contribute visible shadows but would still submit passes.
	var indoors := _world_environment is EnvironmentZoneManager and (_world_environment as EnvironmentZoneManager).is_interior
	for node in get_tree().get_nodes_in_group("watchtowers"):
		if not campus.is_ancestor_of(node) or not node.has_method("set_searchlight_active"): continue
		node.call("set_searchlight_active", _lights_active)
		if node.has_method("set_searchlight_shadow_enabled"):
			node.call("set_searchlight_shadow_enabled", _lights_active and not indoors)


func _build_rain_volume() -> void:
	_rain = GPUParticles3D.new()
	_rain.name = "LocalizedRain"
	_rain.amount = rain_particle_count
	_rain.lifetime = 1.35
	_rain.randomness = 0.3
	_rain.visibility_aabb = AABB(Vector3(-15, -18, -15), Vector3(30, 22, 30))
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(13.0, 1.0, 13.0)
	process.direction = Vector3(0, -1, 0)
	process.spread = 3.0
	process.initial_velocity_min = 18.0
	process.initial_velocity_max = 25.0
	process.gravity = Vector3(0, -5.0, 0)
	_rain.process_material = process
	var streak := QuadMesh.new()
	streak.size = Vector2(0.025, 0.62)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.68, 0.76, 0.82, 0.48)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	streak.material = material
	_rain.draw_pass_1 = streak
	_rain.emitting = false
	get_parent().add_child(_rain)


func _update_rain_shelter() -> void:
	var target := get_tree().get_first_node_in_group("player") as Node3D
	if target == null:
		target = get_viewport().get_camera_3d()
	if target == null or get_viewport() == null or get_viewport().world_3d == null:
		return
	var dss := get_viewport().world_3d.direct_space_state
	if dss == null:
		return
	var query := PhysicsRayQueryParameters3D.create(target.global_position + Vector3.UP * 0.2, target.global_position + Vector3.UP * 24.0, 1)
	if target is CollisionObject3D:
		query.exclude = [(target as CollisionObject3D).get_rid()]
	var sheltered := not dss.intersect_ray(query).is_empty()
	var shelter_changed := sheltered != _is_indoor_sheltered
	_is_indoor_sheltered = sheltered
	if _world_environment is EnvironmentZoneManager:
		(_world_environment as EnvironmentZoneManager).refresh_from_viewer()
	if _rain:
		_rain.global_position = Vector3(target.global_position.x, target.global_position.y + 10.0, target.global_position.z)
		if weather_mode == WeatherMode.RAINY:
			_rain.emitting = not sheltered
	if shelter_changed:
		_apply_environment(false)


func _update_rain_emission() -> void:
	if _rain:
		_rain.visible = weather_mode == WeatherMode.RAINY
		if weather_mode != WeatherMode.RAINY:
			_rain.emitting = false


func _emit_display() -> void:
	display_changed.emit(get_display_text())
