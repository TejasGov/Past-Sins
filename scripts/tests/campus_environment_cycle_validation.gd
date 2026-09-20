extends Node3D

const CAMPUS := preload("res://scenes/levels/campus/PrisonCampusPrototype.tscn")
const PROFILES := preload("res://scripts/systems/interior_lighting_profiles.gd")
var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_validate")


func _validate() -> void:
	var campus := CAMPUS.instantiate() as PrisonCampusPrototype
	campus.gameplay_enabled = false
	var cycle := campus.get_node("EnvironmentCycle") as CampusEnvironmentCycle
	cycle.cycle_enabled = false
	cycle.roll_weather_on_start = false
	cycle.random_seed = 2718
	cycle.start_time_hours = 12.0
	add_child(campus)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame

	_check(cycle.get_current_phase() == CampusEnvironmentCycle.PHASE_DAY, "12:00 must be DAY")
	var world := campus.get_node("WorldEnvironment") as EnvironmentZoneManager
	_check(world.environment != null and world.environment.sky != null, "Cycle requires a valid duplicated environment and sky")
	var indoor := _campus_group(campus, "campus_indoor_lights")
	_check(indoor.size() == 13, "Expected one automatic light per 13 campus storeys, found %d" % indoor.size())
	_validate_fixture_schedule(campus, false)
	var cell_lamps := _campus_group(campus, "cell_lamps")
	_check(cell_lamps.size() == 69, "Every one of the 45 Cellhouse A and 24 Cellhouse B cells requires a reusable tube light")
	_check(_all_cell_lamps_lit(cell_lamps, false), "Cell tube diffusers must remain dull during daylight")
	var beams := campus.find_children("SearchlightBeam", "SpotLight3D", true, false)
	_check(beams.size() == 3, "Only three Web-budget watchtower beams should exist")
	_check(_all_lights_visible(beams, false), "Watchtower beams must be off at noon")
	var noon_energy := (campus.get_node("DirectionalLight3D") as DirectionalLight3D).light_energy

	cycle.set_time_hours(18.0)
	_check(cycle.get_current_phase() == CampusEnvironmentCycle.PHASE_EVENING, "18:00 must be EVENING")
	cycle.set_time_hours(21.0)
	_check(cycle.get_current_phase() == CampusEnvironmentCycle.PHASE_NIGHT, "21:00 must be NIGHT")
	_validate_fixture_schedule(campus, true)
	_check(_all_cell_lamps_lit(cell_lamps, true), "Every cell tube diffuser must emit its amber night glow")
	_check(_all_lights_visible(beams, true), "Designated watchtower beams must switch on after dark")
	var night_energy := (campus.get_node("DirectionalLight3D") as DirectionalLight3D).light_energy
	_check(night_energy < noon_energy * 0.2, "Night sun must be substantially darker than noon")

	cycle.set_time_hours(7.5)
	_check(cycle.get_current_phase() == CampusEnvironmentCycle.PHASE_MORNING, "07:30 must be MORNING")
	_validate_fixture_schedule(campus, false)
	cycle.set_time_hours(12.0)
	_validate_occupied_lighting(campus, world, cycle)

	cycle.set_weather_mode(CampusEnvironmentCycle.WeatherMode.NORMAL)
	var initial_day := cycle.day_number
	cycle.debug_begin_new_day(0.20)
	_check(cycle.weather_mode == CampusEnvironmentCycle.WeatherMode.RAINY, "20% roll after a normal day must rain at 25% chance")
	_check(is_equal_approx(cycle.get_daily_rain_chance(), 0.25), "First roll should use the normal-day 25% chance")
	cycle.debug_begin_new_day(0.15)
	_check(cycle.weather_mode == CampusEnvironmentCycle.WeatherMode.NORMAL, "15% roll after rain must stay normal at 10% chance")
	_check(is_equal_approx(cycle.get_daily_rain_chance(), 0.10), "Day after rain must use the 10% chance")
	cycle.debug_begin_new_day(0.20)
	_check(cycle.weather_mode == CampusEnvironmentCycle.WeatherMode.RAINY, "Rain chance must return to 25% after a normal day")
	_check(cycle.day_number == initial_day + 3, "Every daily weather roll must advance the day counter")
	var preview := campus.get_node("PreviewCamera") as Camera3D
	preview.global_position = Vector3(0.0, 1.7, 0.0)
	cycle.call("_update_rain_shelter")
	var rain := campus.get_node_or_null("LocalizedRain") as GPUParticles3D
	_check(rain != null and rain.amount == 650, "Rain must use one bounded lightweight particle volume")
	_check(rain.emitting, "Rain must emit in the open central yard")
	_check(world.environment == world.exterior and world.environment.fog_enabled and is_equal_approx(world.environment.fog_density, 0.028), "Rainy exterior must use its separate 0.028 fog resource")
	preview.global_position = Vector3(-48.0, 1.7, -51.5)
	cycle.call("_update_rain_shelter")
	_check(not rain.emitting, "Camera-local rain must stop beneath a building roof")
	_check(world.environment == world.interior and not world.environment.fog_enabled, "Sheltered interior must remain fog-free even in rain")
	cycle.set_weather_mode(CampusEnvironmentCycle.WeatherMode.NORMAL)
	_check(world.environment == world.interior and not world.environment.fog_enabled and not rain.emitting, "Normal weather must preserve clear indoor air and sheltered rain suppression")
	preview.global_position = Vector3(0.0, 1.7, 0.0)
	cycle.call("_update_rain_shelter")
	_check(world.environment == world.exterior and world.environment.fog_enabled and is_equal_approx(world.environment.fog_density, 0.015), "Leaving indoors must restore exterior normal fog at 0.015")

	var hud := campus.get_node("HUD/HUDControl")
	var status := hud.get_node_or_null("EnvironmentStatus") as Label
	_check(status != null and status.text.contains("DAY") and status.text.contains("NORMAL"), "HUD must expose current day, time, phase and weather")
	var total_lights := campus.find_children("*", "Light3D", true, false).size()
	_check(total_lights == 22, "Cycle requires 18 base lights plus four pooled cell lights (found %d)" % total_lights)

	if _failures.is_empty():
		print("CAMPUS ENVIRONMENT CYCLE VALIDATION: PASS — four phases, profile-aware fixture schedules, occupied-room light pooling, fog-free interiors, localized rain, 25%/10% daily weather rules")
	else:
		for message in _failures:
			push_error(message)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _campus_group(campus: Node, group: StringName) -> Array[Node]:
	var result: Array[Node] = []
	for node in get_tree().get_nodes_in_group(group):
		if campus.is_ancestor_of(node):
			result.append(node)
	return result


func _all_lights_visible(nodes: Array, expected: bool) -> bool:
	for node in nodes:
		if node is Light3D and (node as Light3D).visible != expected:
			return false
	return true


func _validate_fixture_schedule(campus: Node, night: bool) -> void:
	# Fixtures (emissive meshes) obey the room's schedule. Actual point lights
	# are separately pooled to the occupied room; inactive floors should not
	# allocate lighting just because their visible clinical fixtures stay on.
	var persistent := 0
	var scheduled := 0
	for fixture in _campus_group(campus, "campus_indoor_light_visuals"):
		var always_on := bool(fixture.get_meta("always_on", false))
		if always_on: persistent += 1
		else: scheduled += 1
		_check(fixture.visible == (night or always_on), "Fixture schedule mismatch: %s (night=%s, always_on=%s)" % [fixture.get_path(), night, always_on])
	_check(persistent > 0 and scheduled > 0, "Lighting must retain both fixed clinical/office fixtures and night-switched cellblock fixtures")


func _validate_occupied_lighting(campus: Node3D, world: EnvironmentZoneManager, cycle: CampusEnvironmentCycle) -> void:
	var camera := campus.get_node("PreviewCamera") as Camera3D
	var saved_transform := camera.global_transform
	var visited: Dictionary = {}
	for candidate in _campus_group(campus, "campus_planned_rooms"):
		var room := candidate as Node3D
		if not room.has_meta("lighting_anchor"): continue
		var data: Dictionary = room.get_meta("room_data")
		var profile_id := PROFILES.profile_id(String(data.get("lighting_type", data.type)))
		if visited.has(profile_id): continue
		visited[profile_id] = true
		camera.global_position = room.to_global(Vector3(0, 1.65, 0))
		for hour in [12.0, 21.0]:
			cycle.set_time_hours(hour)
			world.refresh_from_viewer()
			var source := room.get_parent().get_node_or_null("AutomaticInteriorLight") as OmniLight3D
			_check(source != null, "Every occupied blueprint floor must reuse its existing source")
			if source == null: continue
			var expected := (cycle.is_dark() or bool(PROFILES.get_profile(profile_id).always_on)) and String(data.type) != "cell"
			_check(source.visible == expected, "%s %s occupied light schedule mismatch" % [profile_id, hour])
			_check(source.global_position.is_equal_approx(room.to_global(room.get_meta("lighting_anchor"))), "%s source must stay attached to the occupied fixture" % profile_id)
			_check(not world.environment.fog_enabled, "%s must remain fog-free at %s" % [profile_id, hour])
	_check(visited.size() == 6, "Schedule validation must sample all six room profiles, found %s" % [visited.keys()])
	camera.global_transform = saved_transform
	cycle.set_time_hours(12.0)
	world.refresh_from_viewer()


func _all_cell_lamps_lit(nodes: Array, expected: bool) -> bool:
	for node in nodes:
		if not node.has_method("is_visually_lit") or bool(node.call("is_visually_lit")) != expected:
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
