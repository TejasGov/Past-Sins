extends Node3D

const CAMPUS := preload("res://scenes/levels/campus/PrisonCampusPrototype.tscn")
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
	var world := campus.get_node("WorldEnvironment") as WorldEnvironment
	_check(world.environment != null and world.environment.sky != null, "Cycle requires a valid duplicated environment and sky")
	var indoor := _campus_group(campus, "campus_indoor_lights")
	_check(indoor.size() == 13, "Expected one automatic light per 13 campus storeys, found %d" % indoor.size())
	_check(_all_lights_visible(indoor, false), "Indoor lights must be off at noon")
	var beams := campus.find_children("SearchlightBeam", "SpotLight3D", true, false)
	_check(beams.size() == 3, "Only three Web-budget watchtower beams should exist")
	_check(_all_lights_visible(beams, false), "Watchtower beams must be off at noon")
	var noon_energy := (campus.get_node("DirectionalLight3D") as DirectionalLight3D).light_energy

	cycle.set_time_hours(18.0)
	_check(cycle.get_current_phase() == CampusEnvironmentCycle.PHASE_EVENING, "18:00 must be EVENING")
	cycle.set_time_hours(21.0)
	_check(cycle.get_current_phase() == CampusEnvironmentCycle.PHASE_NIGHT, "21:00 must be NIGHT")
	_check(_all_lights_visible(indoor, true), "Indoor lights must switch on after dark")
	_check(_all_lights_visible(beams, true), "Designated watchtower beams must switch on after dark")
	var night_energy := (campus.get_node("DirectionalLight3D") as DirectionalLight3D).light_energy
	_check(night_energy < noon_energy * 0.2, "Night sun must be substantially darker than noon")

	cycle.set_time_hours(7.5)
	_check(cycle.get_current_phase() == CampusEnvironmentCycle.PHASE_MORNING, "07:30 must be MORNING")
	_check(_all_lights_visible(indoor, false), "Indoor lights must switch off after morning cutoff")
	cycle.set_time_hours(12.0)

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
	preview.global_position = Vector3(-48.0, 1.7, -51.5)
	cycle.call("_update_rain_shelter")
	_check(not rain.emitting, "Camera-local rain must stop beneath a building roof")
	_check(world.environment.fog_enabled, "Rainy weather must enable inexpensive gloomy distance fog")
	cycle.set_weather_mode(CampusEnvironmentCycle.WeatherMode.NORMAL)
	_check(not world.environment.fog_enabled and not rain.emitting, "Normal weather must clear rain and its fog")

	var hud := campus.get_node("HUD/HUDControl")
	var status := hud.get_node_or_null("EnvironmentStatus") as Label
	_check(status != null and status.text.contains("DAY") and status.text.contains("NORMAL"), "HUD must expose current day, time, phase and weather")
	var total_lights := campus.find_children("*", "Light3D", true, false).size()
	_check(total_lights == 18, "Cycle must remain at its 18-light unshadowed campus budget (found %d)" % total_lights)

	if _failures.is_empty():
		print("CAMPUS ENVIRONMENT CYCLE VALIDATION: PASS — four phases, automatic lights, localized rain, 25%/10% daily weather rules")
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


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
